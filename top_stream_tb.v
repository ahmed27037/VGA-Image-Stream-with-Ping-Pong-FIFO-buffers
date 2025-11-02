`timescale 1ns/1ps

module top_stream_tb #(
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
        .reverse(reverse),
        .r(r),
        .g(g),
        .b(b),
        .hsync(hsync),
        .vsync(vsync),
        .de(de),
        .underflow(underflow),
        .overflow(overflow),
        .line_mismatch(line_mismatch)
    );

    // 25 MHz pixel clock (40 ns period)
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
    integer               streamed_pixels;
    integer               pixel_count;
    reg                   stream_done;
    integer               expected_idx;
    reg [PIXEL_WIDTH-1:0] expected_pixel;
    integer               mismatch_count = 0;
    integer               first_mismatch = -1;
    // After initial priming, only send pixels while DE is high
    reg                   gated_mode = 1'b0; // 0 = prime freely, 1 = gate by DE

    initial begin
        in_valid        = 0;
        in_data         = 0;
        reverse         = START_REVERSE;
        rst_n           = 0;
        byte_index      = 0;
        streamed_pixels = 0;
        pixel_count     = 0;
        stream_done     = 0;
        have_pixel      = 0;

        raw_fd = $fopen(RAW_FILE, "rb");
        if (raw_fd == 0) begin
            $display("ERROR: failed to open %s", RAW_FILE);
            $finish;
        end

        bytes_read = $fread(raw_bytes, raw_fd);
        $fclose(raw_fd);

        total_pixels = bytes_read / 3;
        total_bytes  = total_pixels * 3;
        if (total_pixels < FRAME_PIXELS) begin
            $display("WARNING: raw stream shorter than one VGA frame (%0d pixels, expected %0d)", total_pixels, FRAME_PIXELS);
        end else begin
            total_pixels = FRAME_PIXELS;
            total_bytes  = FRAME_BYTES;
        end

        ppm_fd = $fopen(PPM_FILE, "w");
        if (ppm_fd == 0) begin
            $display("ERROR: failed to open %s", PPM_FILE);
            $finish;
        end
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

    function automatic [PIXEL_WIDTH-1:0] raw_pixel_at(input integer idx);
        integer base;
        begin
            base = idx * 3;
            raw_pixel_at = {raw_bytes[base + 0], raw_bytes[base + 1], raw_bytes[base + 2]};
        end
    endfunction

    always @(posedge pixel_clock) begin
        if (!rst_n) begin
            in_valid        <= 1'b0;
            in_data         <= {PIXEL_WIDTH{1'b0}};
            byte_index      <= 0;
            streamed_pixels <= 0;
            pixel_count     <= 0;
            stream_done     <= 1'b0;
            have_pixel      <= 1'b0;
        end else begin
            begin : stream_logic
                reg send_now;
                reg source_enable;

                // enter gated mode after first visible pixel (first time DE is high)
                if (!gated_mode && de) gated_mode <= 1'b1;

                source_enable = gated_mode ? de : 1'b1;

                send_now = 1'b0;
                if (!stream_done && have_pixel && source_enable) begin
                    send_now        = 1'b1;
                    in_valid        <= 1'b1;
                    in_data         <= next_pixel;
                    streamed_pixels <= streamed_pixels + 1;
                    if ((streamed_pixels + 1) >= total_pixels)
                        stream_done <= 1'b1;
                end else begin
                    in_valid <= 1'b0;
                end

                if (!stream_done && (send_now || !have_pixel) && (byte_index + 2) < total_bytes) begin
                    next_pixel <= {raw_bytes[byte_index], raw_bytes[byte_index+1], raw_bytes[byte_index+2]};
                    have_pixel <= 1'b1;
                    byte_index <= byte_index + 3;
                end else if (send_now) begin
                    have_pixel <= 1'b0;
                end
            end

            if (de) begin
                #1;
                expected_idx = (pixel_count / H_ACTIVE) * H_ACTIVE;
                expected_idx = reverse
                               ? expected_idx + (H_ACTIVE - 1 - (pixel_count % H_ACTIVE))
                               : expected_idx + (pixel_count % H_ACTIVE);
                if (expected_idx < total_pixels) begin
                    expected_pixel = raw_pixel_at(expected_idx);
                    if ({r, g, b} !== expected_pixel) begin
                        mismatch_count = mismatch_count + 1;
                        if (first_mismatch < 0) first_mismatch = pixel_count;
                        if (pixel_count < 64) begin
                            $display("MISMATCH idx=%0d line=%0d col=%0d exp=%0d,%0d,%0d got=%0d,%0d,%0d",
                                     pixel_count,
                                     pixel_count / H_ACTIVE,
                                     pixel_count % H_ACTIVE,
                                     expected_pixel[23:16], expected_pixel[15:8], expected_pixel[7:0],
                                     r, g, b);
                        end
                    end
                end
                $fdisplay(ppm_fd, "%0d %0d %0d", r, g, b);
                pixel_count <= pixel_count + 1;
                if (pixel_count + 1 == FRAME_PIXELS) begin
                    $fclose(ppm_fd);
                    $display("NOTE: status flags after stream U=%0b O=%0b L=%0b", underflow, overflow, line_mismatch);
                    if (mismatch_count == 0) begin
                        $display("top_stream_tb: PASS (frame stored at %s)", PPM_FILE);
                    end else begin
                        $display("top_stream_tb: DONE with %0d mismatches (first at idx %0d). Frame: %s",
                                 mismatch_count, first_mismatch, PPM_FILE);
                    end
                    $finish;
                end
            end
        end
    end

endmodule
