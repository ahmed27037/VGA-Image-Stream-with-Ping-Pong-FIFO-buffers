`timescale 1ns/1ps

module top_stream_tb_legacy #(
    parameter bit     START_REVERSE = 1'b0,
    parameter string  RAW_FILE      = "frames/video_frames.rgb",
    parameter string  PPM_FILE      = "media/frames/stream_normal.ppm"
);

    localparam integer H_ACTIVE     = 640;
    localparam integer V_ACTIVE     = 480;
    localparam integer PIXEL_WIDTH  = 24;
    localparam integer FRAME_PIXELS = H_ACTIVE * V_ACTIVE;
    localparam integer FRAME_BYTES  = FRAME_PIXELS * 3;

    reg                    pixel_clock;
    reg                    rst_n;
    reg                    reverse;

    reg                    in_valid;
    reg  [PIXEL_WIDTH-1:0] in_data;
    wire                   in_ready;

    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;
    wire       hsync;
    wire       vsync;
    wire       de;
    wire       underflow;
    wire       overflow;
    wire       line_mismatch;

    top_stream #(
        .H_ACTIVE(H_ACTIVE),
        .V_ACTIVE(V_ACTIVE),
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) dut (
        .pixel_clock(pixel_clock),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .in_ready(in_ready),
        .reverse(reverse),
        .r(r), .g(g), .b(b),
        .hsync(hsync), .vsync(vsync), .de(de),
        .underflow(underflow), .overflow(overflow), .line_mismatch(line_mismatch)
    );

    // 25 MHz pixel clock
    initial pixel_clock = 1'b0;
    always #20 pixel_clock = ~pixel_clock;

    reg [7:0] raw_bytes [0:FRAME_BYTES-1];
    integer   bytes_read;
    integer   ppm_fd;
    integer   raw_fd;
    integer   total_pixels;
    integer   total_bytes;
    reg [PIXEL_WIDTH-1:0] next_pixel;
    reg                   have_pixel;
    integer               byte_index;
    integer               pixel_count;

    initial begin
        in_valid    = 0;
        in_data     = 0;
        reverse     = START_REVERSE;
        rst_n       = 0;
        byte_index  = 0;
        pixel_count = 0;
        have_pixel  = 0;

        raw_fd = $fopen(RAW_FILE, "rb");
        if (raw_fd == 0) begin $display("ERROR: open %s", RAW_FILE); $finish; end
        bytes_read = $fread(raw_bytes, raw_fd);
        $fclose(raw_fd);
        total_pixels = bytes_read / 3;
        total_bytes  = total_pixels * 3;
        if (total_pixels >= FRAME_PIXELS) begin
            total_pixels = FRAME_PIXELS; total_bytes = FRAME_BYTES; end

        ppm_fd = $fopen(PPM_FILE, "w");
        if (ppm_fd == 0) begin $display("ERROR: open %s", PPM_FILE); $finish; end
        $fdisplay(ppm_fd, "P3");
        $fdisplay(ppm_fd, "%0d %0d", H_ACTIVE, V_ACTIVE);
        $fdisplay(ppm_fd, "255");

        if (total_bytes >= 3) begin
            next_pixel = {raw_bytes[0], raw_bytes[1], raw_bytes[2]};
            have_pixel = 1'b1;
            byte_index = 3;
        end

        repeat (10) @(posedge pixel_clock);
        rst_n = 1;
    end

    always @(posedge pixel_clock) begin
        if (!rst_n) begin
            in_valid   <= 1'b0;
            in_data    <= '0;
            byte_index <= 0;
            have_pixel <= 1'b0;
        end else begin
            // continuous stream, ignore in_ready per legacy contract
            if (have_pixel) begin
                in_valid <= 1'b1;
                in_data  <= next_pixel;
            end else begin
                in_valid <= 1'b0;
            end

            if ((byte_index + 2) < total_bytes) begin
                next_pixel <= {raw_bytes[byte_index], raw_bytes[byte_index+1], raw_bytes[byte_index+2]};
                have_pixel <= 1'b1;
                byte_index <= byte_index + 3;
            end else begin
                have_pixel <= 1'b0;
            end

            if (de) begin
                #1;
                $fdisplay(ppm_fd, "%0d %0d %0d", r, g, b);
                pixel_count <= pixel_count + 1;
                if (pixel_count + 1 == FRAME_PIXELS) begin
                    $fclose(ppm_fd);
                    $display("top_stream_tb_legacy: PASS (frame stored at %s)", PPM_FILE);
                    $finish;
                end
            end
        end
    end

endmodule

