Param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $root
try {
  & iverilog -g2012 -o fifo_tb video_stream_fifo_tb.v video_stream_fifo.v
  & vvp fifo_tb
} finally {
  Pop-Location
}

