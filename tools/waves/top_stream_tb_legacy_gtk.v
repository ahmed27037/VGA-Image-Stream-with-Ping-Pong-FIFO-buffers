`timescale 1ns/1ps

// Simple GTKWave-enabled wrapper for top_stream_tb_legacy
module top_stream_tb_legacy_gtk;
  top_stream_tb_legacy tb();
  initial begin
    $dumpfile("waves_top_stream_legacy.vcd");
    $dumpvars(0, top_stream_tb_legacy_gtk);
  end
endmodule

