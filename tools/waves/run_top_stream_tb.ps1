Param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $root
try {
  & iverilog -g2012 -o stream_tb top_stream_tb.v top_stream.v video_stream_fifo.v vga.v
  & vvp stream_tb
  Write-Host "Done. PPM at media/frames/stream_normal.ppm (or as set by PPM_FILE)."
} finally {
  Pop-Location
}

