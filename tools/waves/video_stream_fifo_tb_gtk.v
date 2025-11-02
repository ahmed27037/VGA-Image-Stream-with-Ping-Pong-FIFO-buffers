`timescale 1ns/1ps

// Simple GTKWave-enabled wrapper for video_stream_fifo_tb
module video_stream_fifo_tb_gtk;
  video_stream_fifo_tb tb();
  initial begin
    $dumpfile("waves_fifo.vcd");
    $dumpvars(0, video_stream_fifo_tb_gtk);
  end
endmodule

