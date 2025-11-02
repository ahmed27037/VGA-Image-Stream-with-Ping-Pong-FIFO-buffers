`timescale 1ns/1ps

// Continuous-source line FIFO for video streaming
// - Always-accepts input (no back-pressure)
// - Buffers whole lines (H_ACTIVE pixels)
// - Provides first pixel on the same cycle as read_line_start (line-start bypass)
// - Supports per-line reverse on read side
// - Asserts underflow when a line is requested but none is available
// - Asserts overflow when a new line starts while no free buffer is available
// - Asserts line_mismatch if a line ends with an unexpected length
module video_stream_fifo #(
    parameter integer H_ACTIVE     = 640,
    parameter integer PIXEL_WIDTH  = 24,
    parameter integer LINE_BUFFERS = 2
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Write side (continuous source)
    input  wire                    in_valid,
    input  wire [PIXEL_WIDTH-1:0]  in_data,
    input  wire                    write_active,      // high only during active pixels in a line
    input  wire                    write_line_start,  // high for first active pixel of a line
    input  wire                    write_line_end,    // high for last active pixel of a line
    input  wire                    write_frame_start, // optional (informational)

    // Read side (display consumer)
    input  wire                    consume,           // high when the display consumes a pixel (e.g., de)
    input  wire                    read_line_start,   // asserted on first pixel of a line
    input  wire                    read_line_end,     // asserted on last pixel of a line
    input  wire                    read_frame_start,  // optional (informational)
    input  wire                    reverse,           // reverse this line on read

    // Output
    output reg                     out_valid,
    output reg  [PIXEL_WIDTH-1:0]  out_data,
    // Immediate line-start bypass (visible same cycle as read_line_start)
    output wire                    start_valid,
    output wire [PIXEL_WIDTH-1:0]  start_data,
    // Immediate step output for non-start cycles (visible same cycle)
    output wire                    step_valid,
    output wire [PIXEL_WIDTH-1:0]  step_data,
    // Column address from display (0..H_ACTIVE-1)
    input  wire [$clog2(H_ACTIVE)-1:0] read_col,

    // Debug/monitoring
    output wire                    write_buf_sel,
    output wire                    read_buf_sel,
    output wire                    read_sel,

    // Status/flow
    output reg                     underflow,
    output reg                     overflow,
    output reg                     line_mismatch,
    output wire                    line_available
);

    // Two line buffers (ping-pong)
    reg [PIXEL_WIDTH-1:0] mem0 [0:H_ACTIVE-1];
    reg [PIXEL_WIDTH-1:0] mem1 [0:H_ACTIVE-1];

    reg                    ready0, ready1;           // line present and unread
    reg                    w_sel;                    // which buffer we are writing into (0 or 1)
    reg                    writing;                  // currently writing a line
    reg [$clog2(H_ACTIVE):0] w_index;                // write index (allow one extra bit for safety)

    reg                    r_sel;                    // which buffer we are reading from
    reg                    reading;                  // currently reading a line
    reg [$clog2(H_ACTIVE):0] r_index;                // read index
    reg                    r_reverse;                // latched reverse flag for this line

    // Helper wires
    wire any_ready = ready0 | ready1;
    assign line_available = any_ready;
    assign write_buf_sel  = w_sel;
    assign read_buf_sel   = r_sel;
    assign read_sel       = ~w_sel; // debug: opposite of writer buffer

    // Restore simple chooser used previously: prefer w_sel if free, else the other
    function automatic bit choose_free_buf;
        input bit prefer_alt; // unused, placeholder
        begin
            if (w_sel == 1'b0) begin
                if (!ready0) choose_free_buf = 1'b0; else choose_free_buf = 1'b1;
            end else begin
                if (!ready1) choose_free_buf = 1'b1; else choose_free_buf = 1'b0;
            end
        end
    endfunction

    // Write side
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready0        <= 1'b0;
            ready1        <= 1'b0;
            w_sel         <= 1'b0;
            writing       <= 1'b0;
            w_index       <= '0;
            overflow      <= 1'b0;
            line_mismatch <= 1'b0;
        end else begin
            // Start of a new line
            if (write_line_start) begin
                reg next_w_sel;
                next_w_sel = choose_free_buf(1'b0);
                // overflow if chosen buffer is not free
                if ((next_w_sel == 1'b0 && ready0) || (next_w_sel == 1'b1 && ready1)) begin
                    overflow <= 1'b1;
                end
                w_sel   <= next_w_sel;
                writing <= 1'b1;
                // commit first pixel immediately at index 0 when present
                if (in_valid && write_active) begin
                    if (next_w_sel == 1'b0) mem0[0] <= in_data; else mem1[0] <= in_data;
                    w_index <= (H_ACTIVE > 1) ? 1 : 0;
                end else begin
                    w_index <= '0;
                end
            end else if (writing) begin
                if (in_valid && write_active) begin
                    if (w_sel == 1'b0) mem0[w_index] <= in_data; else mem1[w_index] <= in_data;
                    if (w_index != H_ACTIVE-1) begin
                        w_index <= w_index + 1'b1;
                    end
                end

                // End of line: explicit or by reaching last index while active
                if (write_line_end || (in_valid && write_active && (w_index == H_ACTIVE-1))) begin
                    // Check expected length when explicit end is used
                    if (write_line_end && (w_index != H_ACTIVE-1)) begin
                        line_mismatch <= 1'b1;
                    end
                    // Mark buffer ready
                    if (w_sel == 1'b0) ready0 <= 1'b1; else ready1 <= 1'b1;
                    writing <= 1'b0;
                end
            end
        end
    end

    // Combinational line-start bypass for first pixel
    wire select_buf0 = ready0;
    wire select_buf1 = (~ready0) & ready1;
    wire have_line   = ready0 | ready1;
    wire use_buf0    = select_buf0; // prefer buf0 when both are ready
    assign start_valid = read_line_start && consume && have_line;
    assign start_data  = start_valid
                       ? (use_buf0 ? (reverse ? mem0[H_ACTIVE-1] : mem0[0])
                                   : (reverse ? mem1[H_ACTIVE-1] : mem1[0]))
                       : {PIXEL_WIDTH{1'b0}};

    // Non-start cycle immediate output addressed by current display column
    assign step_valid = reading && consume;
    wire [$clog2(H_ACTIVE)-1:0] col_fwd = read_col;
    wire [$clog2(H_ACTIVE)-1:0] col_rev = H_ACTIVE[$clog2(H_ACTIVE)-1:0] - 1'b1 - read_col;
    assign step_data  = step_valid ? (
                          (r_sel==1'b0)
                            ? (reverse ? mem0[col_rev] : mem0[col_fwd])
                            : (reverse ? mem1[col_rev] : mem1[col_fwd])
                        ) : {PIXEL_WIDTH{1'b0}};

    // Read side
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_sel     <= 1'b0;
            reading   <= 1'b0;
            r_index   <= '0;
            r_reverse <= 1'b0;
            out_valid <= 1'b0;
            out_data  <= {PIXEL_WIDTH{1'b0}};
            underflow <= 1'b0;
        end else begin
            // Default
            out_valid <= 1'b0;

            if (read_line_start) begin
                // Choose a ready buffer (use a temporary to avoid NB assignment ordering issues)
                reg next_sel;
                next_sel = 1'b0;
                if (ready0) begin
                    next_sel = 1'b0;
                end else if (ready1) begin
                    next_sel = 1'b1;
                end else begin
                    underflow <= 1'b1;
                    reading   <= 1'b0;
                end

                if (ready0 || ready1) begin
                    r_sel     <= next_sel;
                    reading   <= 1'b1;
                    r_reverse <= reverse;
                    // After driving the very first pixel via start_data,
                    // pre-seed r_index to the second pixel for forward,
                    // or the second-from-end for reverse.
                    if (reverse) begin
                        r_index <= (H_ACTIVE > 1) ? (H_ACTIVE-2) : 0;
                    end else begin
                        r_index <= (H_ACTIVE > 1) ? 1 : 0;
                    end
                    // Registered outputs still update; immediate path exposed via start_valid/start_data
                    if (consume) begin
                        out_valid <= 1'b1;
                        out_data  <= (next_sel == 1'b0)
                                   ? (reverse ? mem0[H_ACTIVE-1] : mem0[0])
                                   : (reverse ? mem1[H_ACTIVE-1] : mem1[0]);
                    end
                end
            end else if (reading && consume) begin
                // Subsequent pixels
                out_valid <= 1'b1;
                if (r_sel == 1'b0) begin
                    out_data <= mem0[r_index];
                end else begin
                    out_data <= mem1[r_index];
                end

                // Advance index
                if (r_reverse) begin
                    if (r_index != 0) r_index <= r_index - 1'b1;
                end else begin
                    if (r_index != H_ACTIVE-1) r_index <= r_index + 1'b1;
                end
            end

            // End-of-line handling: when consumer asserts end, release buffer
            if (read_line_end && reading) begin
                reading <= 1'b0;
                if (r_sel == 1'b0) ready0 <= 1'b0; else ready1 <= 1'b0;
            end
        end
    end

endmodule
