# VGA Image Stream with Ping-Pong FIFO Buffers

A hardware design for continuous VGA video output from an RGB24 pixel stream using ping-pong (double-buffered) FIFO line buffers. This design enables seamless streaming of video data to a VGA display with proper timing control and flow management.

---

## Overview

This project implements a complete VGA video streaming system that:
- Accepts a continuous RGB24 pixel stream as input
- Buffers video lines using two ping-pong FIFO buffers
- Generates VGA timing signals (HSYNC, VSYNC, DE)
- Supports both normal and horizontally-reversed (mirror) modes
- Provides status flags for underflow, overflow, and line mismatch detection

The design is synthesizable and can be used for FPGA-based video systems, image processing pipelines, or educational purposes.

---

## Architecture

### System Block Diagram

![Top-Level Architecture](Diagrams/vga_top_level.html)

**What this shows:** The complete VGA streaming system with input RGB stream, ping-pong FIFO buffers, VGA timing generator, and output. The `top_stream` module coordinates data flow between the stream source, FIFO buffering, and VGA output.

**Key Components:**
- **Input Stream**: Continuous RGB24 pixel data with `in_valid` and `in_ready` handshaking
- **Ping-Pong FIFO**: Two line buffers that alternate for reading and writing
- **VGA Timing Generator**: Produces proper HSYNC, VSYNC, and data enable (DE) signals
- **Output**: RGB24 pixel stream synchronized with VGA timing

### FIFO Buffer Detail

![FIFO Buffer Architecture](Diagrams/vga_fifo_detail.html)

**What this shows:** The internal structure of the ping-pong FIFO buffer system. Two line buffers (Buffer 0 and Buffer 1) alternate roles:
- One buffer receives data from the input stream (write mode)
- The other buffer supplies data to the VGA output (read mode)
- Control logic manages buffer switching at line boundaries
- Supports reverse mode for horizontal image flipping

**Key Features:**
- Write/read control with independent buffer selection
- Line-start bypass for continuous operation
- Reverse mode support for horizontal mirroring
- Status flags: `ready0`, `ready1`, `underflow`, `overflow`, `line_mismatch`

### Timing and Data Flow

![VGA Timing](Diagrams/vga_timing.html)

**What this shows:** VGA timing parameters and data flow through the system. Includes:
- VGA timing parameters (H_active, V_active, porches, sync pulses)
- Operation phases: Reset, Fill Buffers, Normal Operation, Line Transitions
- Buffer switching logic and control signals
- Data path from input stream through FIFOs to VGA output

**VGA Timing:**
- Resolution: 640×480 pixels (standard VGA)
- Refresh rate: 60 Hz (or configurable)
- Pixel clock: Derived from display requirements
- Horizontal: 640 active pixels + front porch + sync + back porch
- Vertical: 480 active lines + front porch + sync + back porch

---

## Features

- ✅ **Ping-Pong FIFO Buffering**: Two line buffers enable continuous streaming without frame drops
- ✅ **VGA Timing Generation**: Proper HSYNC, VSYNC, and data enable signals
- ✅ **Reverse Mode**: Horizontal mirroring of video output
- ✅ **Flow Control**: Ready/valid handshaking for input stream
- ✅ **Status Monitoring**: Underflow, overflow, and line mismatch detection
- ✅ **Configurable**: Adjustable buffer sizes, timing parameters, and video resolution

---

## Project Structure

```
VGA Image Stream with Ping-Pong FIFO buffers/
├── top_stream.v              # Top-level module coordinating FIFO and VGA
├── video_stream_fifo.v       # Ping-pong FIFO buffer implementation
├── vga.v                     # VGA timing generator
├── top_stream_tb.v           # Main testbench for full system
├── video_stream_fifo_tb.v    # FIFO-only testbench
├── tools/
│   ├── video_to_rgb.py       # Convert video to RGB24 format
│   ├── generate_demo_video.py # Generate test video
│   └── waves/                # GTKwave support files
│       ├── top_stream_tb_gtk.v
│       ├── video_stream_fifo_tb_gtk.v
│       └── wave_*.ps1        # PowerShell scripts for easy waveform viewing
├── media/
│   ├── input/                # Input video files
│   ├── frames/               # Output PPM frame captures
│   └── output/               # Processed video outputs
└── frames/
    └── video_frames.rgb      # Raw RGB24 frame data
```

---

## Prerequisites

### Software Requirements

1. **Icarus Verilog** - HDL simulator
   - Windows: `choco install icarus-verilog`
   - macOS: `brew install icarus-verilog`
   - Linux: `sudo apt install iverilog` (Ubuntu/Debian)

2. **GTKwave** - Waveform viewer (optional, for debugging)
   - Windows: Download from http://gtkwave.sourceforge.net/
   - macOS: `brew install gtkwave`
   - Linux: `sudo apt install gtkwave`

3. **Python 3** - For video conversion tools
   - Required packages: `opencv-python`, `numpy`

4. **FFmpeg** (optional) - For video encoding/decoding
   - Windows: Download from https://ffmpeg.org/
   - macOS: `brew install ffmpeg`
   - Linux: `sudo apt install ffmpeg`

### Verify Installation

```powershell
iverilog -V
vvp -V
gtkwave --version
python --version
```

---

## Quick Start

### Step 1: Prepare Input Video

Convert a video file to raw RGB24 format:

```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
python tools/video_to_rgb.py --input media/input/first_video_short.mp4 --output frames/video_frames.rgb --width 640 --height 480 --fps 30
```

Or use your own video:
```powershell
python tools/video_to_rgb.py --input <your_video_path> --output frames/video_frames.rgb --width 640 --height 480 --fps 30
```

### Step 2: Run Simulation

**Normal Mode:**
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
iverilog -g2012 -o stream_tb top_stream_tb.v top_stream.v video_stream_fifo.v vga.v
vvp stream_tb
```

**Reverse Mode (horizontal flip):**
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
$ppm = '"media/frames/stream_reverse.ppm"'
iverilog -g2012 -P top_stream_tb.START_REVERSE=1 -P top_stream_tb.PPM_FILE=$ppm -o stream_tb_rev top_stream_tb.v top_stream.v video_stream_fifo.v vga.v
vvp stream_tb_rev
```

**Output:** Each run generates a PPM image file in `media/frames/` showing a captured frame from the stream.

### Step 3: View Output

View the captured frame:
```powershell
ffplay media/frames/stream_normal.ppm
```

Or encode the full RGB stream to video:
```powershell
ffmpeg -f rawvideo -pixel_format rgb24 -video_size 640x480 -framerate 30 -i frames/video_frames.rgb -c:v libx264 -pix_fmt yuv444p media/output/full_preview.mp4
```

---

## Simulation with Waveforms

### Option 1: Top Stream Testbench (Full System)

**Direct Command:**
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
iverilog -g2012 -o stream_tb_gtk tools\waves\top_stream_tb_gtk.v top_stream_tb.v top_stream.v video_stream_fifo.v vga.v
vvp stream_tb_gtk
gtkwave waves_top_stream.vcd
```

**One-Liner Script:**
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
powershell -ExecutionPolicy Bypass -File tools\waves\wave_top_stream_tb.ps1
```

### Option 2: FIFO Testbench (FIFO Only)

**Direct Command:**
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
iverilog -g2012 -o fifo_tb_gtk tools\waves\video_stream_fifo_tb_gtk.v video_stream_fifo_tb.v video_stream_fifo.v
vvp fifo_tb_gtk
gtkwave waves_fifo.vcd
```

**One-Liner Script:**
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
powershell -ExecutionPolicy Bypass -File tools\waves\wave_video_stream_fifo_tb.ps1
```

### Key Signals to View in GTKwave

**Buffer Control:**
- `write_buf_sel`, `read_buf_sel` - Which buffer is currently writing/reading
- `ready0`, `ready1` - Buffer ready flags (indicates buffer has data and can be read)
- Buffer switching happens at line boundaries

**Input Stream:**
- `in_valid`, `in_ready` - Handshaking signals for input data
- `in_data` - RGB24 pixel data (24 bits: R[23:16], G[15:8], B[7:0])

**Output Stream:**
- `out_valid`, `out_data` - Pixel data going to VGA
- Synchronized with VGA timing

**VGA Timing:**
- `de` (Data Enable) - Active during visible pixel region
- `hsync` - Horizontal synchronization pulse
- `vsync` - Vertical synchronization pulse
- `x`, `y` - Current pixel coordinates

**Status Flags:**
- `underflow` - Raised when output requests data but buffer is empty
- `overflow` - Raised when input data arrives but buffer is full
- `line_mismatch` - Indicates write/read buffer selection error

**What to Look For:**
1. Buffer switching: Watch `write_buf_sel` and `read_buf_sel` toggle at line boundaries
2. Data flow: Input pixels arrive, get buffered, then output synchronized to VGA timing
3. Timing alignment: `de` signal should align with valid pixel output
4. No errors: `underflow`, `overflow`, and `line_mismatch` should stay low during normal operation

---

## Module Descriptions

### `top_stream.v`
Top-level module that instantiates the FIFO buffer and VGA timing generator. Manages the overall data flow and coordinates between input stream and VGA output.

**Key Features:**
- Coordinates ping-pong buffer operation
- Handles reverse mode for horizontal mirroring
- Passes through VGA timing signals

### `video_stream_fifo.v`
Ping-pong FIFO buffer implementation. Two line buffers alternate between write and read modes.

**Key Features:**
- Dual-buffer architecture for continuous operation
- Line-based buffer switching
- Support for reverse read order (horizontal flip)
- Status flag generation

### `vga.v`
VGA timing generator that produces proper HSYNC, VSYNC, and data enable signals according to VGA standards.

**Key Features:**
- Configurable timing parameters
- Generates pixel coordinates (x, y)
- Produces data enable signal for active pixel region

---

## Testing

### Basic Functionality Test

Run the main testbench to verify the system works:
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
iverilog -g2012 -o stream_tb top_stream_tb.v top_stream.v video_stream_fifo.v vga.v
vvp stream_tb
```

**Expected Output:**
- Simulation completes without errors
- PPM frame file is generated in `media/frames/`
- Console output shows status flags (should all be 0 for successful run)

### FIFO-Only Test

Test just the FIFO buffer:
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
iverilog -g2012 -o fifo_tb video_stream_fifo_tb.v video_stream_fifo.v
vvp fifo_tb
```

### Reverse Mode Test

Test horizontal mirroring:
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"
$ppm = '"media/frames/stream_reverse.ppm"'
iverilog -g2012 -P top_stream_tb.START_REVERSE=1 -P top_stream_tb.PPM_FILE=$ppm -o stream_tb_rev top_stream_tb.v top_stream.v video_stream_fifo.v vga.v
vvp stream_tb_rev
```

Compare `stream_normal.ppm` and `stream_reverse.ppm` to see the horizontal flip.

---

## Troubleshooting

### Common Issues

**"No such file or directory"**
- Make sure you're in the correct directory: `VGA Image Stream with Ping-Pong FIFO buffers/`
- Check that input RGB file exists: `frames/video_frames.rgb`

**"gtkwave not found"**
- Install GTKwave and ensure it's in your PATH
- Or manually open the `.vcd` file: `gtkwave waves_top_stream.vcd`

**"Python script not found"**
- Ensure Python 3 is installed
- Install required packages: `pip install opencv-python numpy`

**Status flags showing errors**
- `underflow`: Input stream too slow - increase input data rate
- `overflow`: Input stream too fast - check FIFO buffer size
- `line_mismatch`: Buffer control logic error - check write/read buffer selection

**PPM file not generated**
- Check that the testbench completed successfully
- Verify output directory exists: `media/frames/`

**Video conversion issues**
- Ensure FFmpeg is installed for video operations
- Check input video format is supported
- Verify video dimensions match specified width/height

---

## Design Details

### Ping-Pong Buffer Operation

1. **Initialization**: Both buffers start empty
2. **First Line**: Buffer 0 receives data while VGA waits
3. **Buffer Switch**: When Buffer 0 has a complete line, switch read to Buffer 0 and write to Buffer 1
4. **Continuous Operation**: Buffers alternate roles each line
5. **Reverse Mode**: When enabled, read buffer addresses in reverse order

### VGA Timing

Standard 640×480 VGA timing:
- **Pixel Clock**: 25.175 MHz (typical)
- **Horizontal**: 800 pixels total (640 active + 160 blanking)
- **Vertical**: 525 lines total (480 active + 45 blanking)
- **Refresh Rate**: 60 Hz

### Data Flow

1. Input stream provides RGB24 pixels with `in_valid`/`in_ready` handshaking
2. FIFO buffers pixels line-by-line into alternating buffers
3. VGA timing generator requests pixels at correct timing
4. FIFO supplies pixels from the read buffer
5. Output pixels are synchronized with HSYNC/VSYNC/DE signals

---

## Future Enhancements

- Support for different video resolutions (800×600, 1024×768, etc.)
- Configurable FIFO buffer depth
- Additional video processing modes (vertical flip, rotation)
- AXI-Stream interface compatibility
- FPGA synthesis scripts and constraints

---

## License

[Specify your license here]

---

## Contributing

Contributions are welcome! Please ensure all simulations pass before submitting pull requests.
