`timescale 1ns/1ps

// Simple GTKWave-enabled wrapper for top_stream_tb
module top_stream_tb_gtk;
  // Instantiate the original testbench with its defaults
  top_stream_tb tb();

  // Dump everything under this wrapper (captures the DUT and TB hierarchy)
  initial begin
    $dumpfile("waves_top_stream.vcd");
    $dumpvars(0, top_stream_tb_gtk);
  end
endmodule

