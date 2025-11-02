`timescale 1ns/1ps

module top_stream #(
    parameter integer H_ACTIVE    = 640,
    parameter integer V_ACTIVE    = 480,
    parameter integer PIXEL_WIDTH = 24
)(
    input  wire                    pixel_clock,
    input  wire                    rst_n,

    // continuous video stream
    input  wire                    in_valid,
    input  wire [PIXEL_WIDTH-1:0]  in_data,

    input  wire                    reverse,

    // VGA outputs
    output reg  [7:0]              r,
    output reg  [7:0]              g,
    output reg  [7:0]              b,
    output wire                    hsync,
    output wire                    vsync,
    output wire                    de,

    // status flags
    output wire                    underflow,
    output wire                    overflow,
    output wire                    line_mismatch
);

    localparam integer H_FP   = 16;
    localparam integer H_SYNC = 96;
    localparam integer H_BP   = 48;
    localparam integer V_FP   = 10;
    localparam integer V_SYNC = 2;
    localparam integer V_BP   = 33;

    localparam integer H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam integer V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    localparam integer PRIME_CYCLES = H_ACTIVE;
    localparam integer PRIME_W      = (PRIME_CYCLES > 0) ? $clog2(PRIME_CYCLES + 1) : 1;

    // ------------------------------------------------------------------
    // Write-side control: prime one line, then lock to DE
    // ------------------------------------------------------------------
    // Detect DE edges (valid only once VGA released from reset)
    wire de_w = vga_rst_n ? de_raw : 1'b0;
    reg  de_q;
    always @(posedge pixel_clock or negedge rst_n) begin
        if (!rst_n) de_q <= 1'b0; else de_q <= de_w;
    end
    wire de_rise =  de_w & ~de_q;
    wire de_fall = ~de_w &  de_q;

    // Prime exactly one line from the continuous source so FIFO has data before VGA starts
    reg  priming;
    reg  [$clog2(H_ACTIVE)-1:0] p_x;
    always @(posedge pixel_clock or negedge rst_n) begin
        if (!rst_n) begin
            priming <= 1'b1;
            p_x     <= {($clog2(H_ACTIVE)){1'b0}};
        end else if (priming) begin
            if (in_valid) begin
                if (p_x == H_ACTIVE-1)
                    p_x <= {($clog2(H_ACTIVE)){1'b0}};
                else
                    p_x <= p_x + 1'b1;
            end
            // Once at least one line is buffered, switch to DE-locked writes
            if (fifo_line_ready) priming <= 1'b0;
        end
    end

    // Write strobes: during priming we use input counter; after that we lock to DE
    wire write_active       = priming ? in_valid                               : de_w;
    wire write_line_start   = priming ? (in_valid && (p_x == {($clog2(H_ACTIVE)){1'b0}})) : de_rise;
    wire write_line_end     = priming ? (in_valid && (p_x == H_ACTIVE-1))       : de_fall;
    wire write_frame_start  = (!priming) ? (de_rise && (y == {($clog2(V_ACTIVE)){1'b0}})) : 1'b0;

    // ------------------------------------------------------------------
    // VGA timing generator (held in reset until FIFO primed)
    // ------------------------------------------------------------------
    reg [PRIME_W-1:0] prime_ctr;
    reg               vga_rst_n;

    wire [$clog2(H_ACTIVE)-1:0] x;
    wire [$clog2(V_ACTIVE)-1:0] y;
    wire                        de_raw;
    wire                        hsync_raw;
    wire                        vsync_raw;

    VGA #(
        .H_active   (H_ACTIVE),
        .Back_Porch_H(H_BP),
        .Front_Porch_H(H_FP),
        .Hsync      (H_SYNC),
        .V_active   (V_ACTIVE),
        .Back_Porch_V(V_BP),
        .Front_Porch_V(V_FP),
        .Vsync      (V_SYNC)
    ) u_vga (
        .pixel_clock(pixel_clock),
        .rst_n      (vga_rst_n),
        .hsync      (hsync_raw),
        .vsync      (vsync_raw),
        .de         (de_raw),
        .x          (x),
        .y          (y)
    );

    // ------------------------------------------------------------------
    // FIFO: double line buffer with run-time reversal
    // ------------------------------------------------------------------
    wire consume          = vga_rst_n ? de_raw : 1'b0;
    wire display_line_start = consume && (x == {($clog2(H_ACTIVE)){1'b0}});
    wire display_line_end   = consume && (x == H_ACTIVE-1);
    wire display_frame_start= display_line_start && (y == {($clog2(V_ACTIVE)){1'b0}});

    wire [PIXEL_WIDTH-1:0] fifo_out_data;
    wire                   fifo_out_valid;
    wire                   fifo_line_ready;
    wire                   fifo_start_valid;
    wire [PIXEL_WIDTH-1:0] fifo_start_data;
    wire                   fifo_step_valid;
    wire [PIXEL_WIDTH-1:0] fifo_step_data;
    wire                   fifo_write_buf_sel;
    wire                   fifo_read_buf_sel;

    video_stream_fifo #(
        .H_ACTIVE   (H_ACTIVE),
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) u_fifo (
        .clk              (pixel_clock),
        .rst_n            (rst_n),
        .in_valid         (in_valid),
        .in_data          (in_data),
        .write_active     (write_active),
        .write_line_start (write_line_start),
        .write_line_end   (write_line_end),
        .write_frame_start(write_frame_start),
        .consume          (consume),
        .read_line_start  (display_line_start),
        .read_line_end    (display_line_end),
        .read_frame_start (display_frame_start),
        .reverse          (reverse),
        .out_valid        (fifo_out_valid),
        .out_data         (fifo_out_data),
        .start_valid      (fifo_start_valid),
        .start_data       (fifo_start_data),
        .step_valid       (fifo_step_valid),
        .step_data        (fifo_step_data),
        .read_col         (x),
        .write_buf_sel    (fifo_write_buf_sel),
        .read_buf_sel     (fifo_read_buf_sel),
        .underflow        (underflow),
        .overflow         (overflow),
        .line_mismatch    (line_mismatch),
        .line_available   (fifo_line_ready)
    );

    // Keep VGA in reset until the FIFO reports a line available (and we waited a priming delay)
    always @(posedge pixel_clock or negedge rst_n) begin
        if (!rst_n) begin
            prime_ctr <= PRIME_W'(PRIME_CYCLES);
            vga_rst_n <= 1'b0;
        end else if (!vga_rst_n) begin
            if (prime_ctr != {PRIME_W{1'b0}})
                prime_ctr <= prime_ctr - 1'b1;
            else if (fifo_line_ready)
                vga_rst_n <= 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // Output alignment (one-cycle pipeline with line-start bypass)
    // ------------------------------------------------------------------
    // Use start bypass for the first pixel; then index the buffer by current x
    wire display_de    = vga_rst_n ? de_raw : 1'b0;
    wire display_valid = display_de; // update every active pixel
    wire [PIXEL_WIDTH-1:0] display_pixel =
        display_line_start ? fifo_start_data : fifo_step_data;

    assign de    = display_de;
    assign hsync = vga_rst_n ? hsync_raw : 1'b1;
    assign vsync = vga_rst_n ? vsync_raw : 1'b1;

    always @(posedge pixel_clock or negedge rst_n) begin
        if (!rst_n) begin
            r <= 8'd0;
            g <= 8'd0;
            b <= 8'd0;
        end else if (display_de && display_valid) begin
            r <= display_pixel[23:16];
            g <= display_pixel[15:8];
            b <= display_pixel[7:0];
        end else if (!display_de) begin
            r <= 8'd0;
            g <= 8'd0;
            b <= 8'd0;
        end
    end

endmodule
