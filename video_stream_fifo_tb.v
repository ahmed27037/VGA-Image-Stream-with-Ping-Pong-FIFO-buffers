`timescale 1ns/1ps

module video_stream_fifo_tb;

    localparam integer H_ACTIVE    = 8;
    localparam integer PIXEL_WIDTH = 24;

    reg                    clk;
    reg                    rst_n;
    reg                    in_valid;
    reg  [PIXEL_WIDTH-1:0] in_data;
    reg                    write_active;
    reg                    write_line_start;
    reg                    write_line_end;
    reg                    consume;
    reg                    read_line_start;
    reg                    read_line_end;
    reg                    read_frame_start;
    reg                    reverse;
    wire                   out_valid;
    wire [PIXEL_WIDTH-1:0] out_data;
    wire                   underflow;
    wire                   overflow;
    wire                   line_mismatch;

    wire line_available;
    video_stream_fifo #(
        .H_ACTIVE    (H_ACTIVE),
        .PIXEL_WIDTH (PIXEL_WIDTH),
        .LINE_BUFFERS(2)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .in_valid         (in_valid),
        .in_data          (in_data),
        .write_active     (write_active),
        .write_line_start (write_line_start),
        .write_line_end   (write_line_end),
        .write_frame_start(read_frame_start),
        .consume          (consume),
        .read_line_start  (read_line_start),
        .read_line_end    (read_line_end),
        .read_frame_start (read_frame_start),
        .reverse          (reverse),
        .out_valid        (out_valid),
        .out_data         (out_data),
        .underflow        (underflow),
        .overflow         (overflow),
        .line_mismatch    (line_mismatch),
        .line_available   (line_available)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        integer i;
        reg [PIXEL_WIDTH-1:0] expected;

        rst_n            = 1'b0;
        in_valid         = 1'b0;
        in_data          = '0;
        write_active     = 1'b0;
        write_line_start = 1'b0;
        write_line_end   = 1'b0;
        consume          = 1'b0;
        read_line_start  = 1'b0;
        read_line_end    = 1'b0;
        read_frame_start = 1'b0;
        reverse          = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        @(posedge clk);
        in_valid         <= 1'b1;
        read_frame_start <= 1'b1;
        @(posedge clk);
        read_frame_start <= 1'b0;

        // forward line
        reverse <= 1'b0;
        for (i = 0; i < H_ACTIVE; i = i + 1) begin
            @(posedge clk);
            write_active    <= 1'b1;
            write_line_start<= (i == 0);
            write_line_end  <= (i == H_ACTIVE-1);
            in_data         <= {3{8'h10 + i[7:0]}};
            consume         <= 1'b1;
            read_line_start <= (i == 0);
            read_line_end   <= (i == H_ACTIVE-1);
            expected        <= {3{8'h10 + i[7:0]}};
            #1; // allow DUT to present data
            if (!out_valid || out_data !== expected) begin
                $display("ERROR: forward pixel %0d mismatch", i);
                $finish;
            end
        end
        @(posedge clk);
        write_active    <= 1'b0;
        write_line_start<= 1'b0;
        write_line_end  <= 1'b0;
        consume         <= 1'b0;
        read_line_start <= 1'b0;
        read_line_end   <= 1'b0;

        repeat (3) @(posedge clk);

        // reverse line
        reverse <= 1'b1;
        for (i = 0; i < H_ACTIVE; i = i + 1) begin
            @(posedge clk);
            write_active    <= 1'b1;
            write_line_start<= (i == 0);
            write_line_end  <= (i == H_ACTIVE-1);
            in_data         <= {3{8'h40 + i[7:0]}};
            consume         <= 1'b1;
            read_line_start <= (i == 0);
            read_line_end   <= (i == H_ACTIVE-1);
            expected        <= {3{8'h40 + (H_ACTIVE-1-i)[7:0]}};
            #1;
            if (!out_valid || out_data !== expected) begin
                $display("ERROR: reverse pixel %0d mismatch", i);
                $finish;
            end
        end
        @(posedge clk);
        write_active    <= 1'b0;
        write_line_start<= 1'b0;
        write_line_end  <= 1'b0;
        consume         <= 1'b0;
        read_line_start <= 1'b0;
        read_line_end   <= 1'b0;

        if (underflow || overflow || line_mismatch) begin
            $display("ERROR: flags set U=%0b O=%0b L=%0b", underflow, overflow, line_mismatch);
            $finish;
        end

        $display("video_stream_fifo_tb: PASS");
        $finish;
    end

endmodule
