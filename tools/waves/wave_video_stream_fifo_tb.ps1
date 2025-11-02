Param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $root
try {
  & iverilog -g2012 -s video_stream_fifo_tb_gtk -o fifo_tb_gtk `
    tools/waves/video_stream_fifo_tb_gtk.v video_stream_fifo_tb.v video_stream_fifo.v
  & vvp fifo_tb_gtk
  if (Get-Command gtkwave -ErrorAction SilentlyContinue) {
    & gtkwave waves_fifo.vcd
  } else {
    Write-Warning "gtkwave not found in PATH. Open waves_fifo.vcd manually."
  }
} finally {
  Pop-Location
}
