Param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $root
try {
  & iverilog -g2012 -s top_stream_tb_gtk -o stream_tb_gtk `
    tools/waves/top_stream_tb_gtk.v top_stream_tb.v top_stream.v video_stream_fifo.v vga.v
  & vvp stream_tb_gtk
  if (Get-Command gtkwave -ErrorAction SilentlyContinue) {
    & gtkwave waves_top_stream.vcd
  } else {
    Write-Warning "gtkwave not found in PATH. Open waves_top_stream.vcd manually."
  }
} finally {
  Pop-Location
}
