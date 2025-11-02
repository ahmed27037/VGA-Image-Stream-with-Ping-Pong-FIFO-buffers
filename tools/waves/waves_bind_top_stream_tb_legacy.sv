// Adds VCD dumping to top_stream_tb_legacy without editing the bench
module waves_bind_top_stream_tb_legacy;
  initial begin
    $dumpfile("waves_top_stream_legacy.vcd");
    $dumpvars(0, top_stream_tb_legacy);
  end
endmodule
bind top_stream_tb_legacy waves_bind_top_stream_tb_legacy wb_top_stream_tb_legacy();

