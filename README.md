# VGA Image Stream with Ping-Pong FIFO Buffers

Continuous VGA video output from an RGB24 pixel stream using double-buffered line FIFOs. One buffer receives input pixels while the other supplies output to the VGA display.

---

## Architecture

### Top-Level Architecture

```mermaid
flowchart TD
    CLK[pixel_clock]
    RST[rst_n]
    INVALID[in_valid]
    INDATA["in_data[23:0]<br/>RGB24"]
    REV[reverse]
    
    subgraph TOP ["top_stream Module"]
        subgraph WRITE ["Write Control"]
            PRIME["Priming FSM<br/>Buffer first line"]
            WACTIVE[write_active<br/>DE or priming]
            WSTART[write_line_start<br/>Line begin]
            WEND[write_line_end<br/>Line complete]
        end
        
        subgraph FIFO ["video_stream_fifo"]
            direction TB
            MEM0["mem0[639:0]<br/>Line Buffer 0<br/>24-bit x 640"]
            MEM1["mem1[639:0]<br/>Line Buffer 1<br/>24-bit x 640"]
            WSEL["w_sel<br/>Write buffer select"]
            RSEL["r_sel<br/>Read buffer select"]
            READY["ready0, ready1<br/>Buffer status flags"]
        end
        
        subgraph VGA ["VGA Timing Generator"]
            CNT["Pixel Counters<br/>x[9:0], y[9:0]"]
            SYNC["Sync Generator<br/>hsync, vsync, de"]
        end
        
        subgraph READ ["Read Control"]
            CONSUME["consume = de<br/>Read enable"]
            RSTART["read_line_start<br/>x == 0"]
            REND["read_line_end<br/>x == 639"]
            BYPASS["Line-start bypass<br/>First pixel"]
        end
        
        subgraph OUT_REG ["Output Pipeline"]
            OMUX["Output MUX<br/>start_data or step_data"]
            RGB["r[7:0], g[7:0], b[7:0]<br/>RGB outputs"]
        end
    end
    
    HSYNC[hsync]
    VSYNC[vsync]
    DE[de]
    UFLOW[underflow]
    OFLOW[overflow]
    LMIS[line_mismatch]
    
    CLK --> TOP
    RST --> TOP
    INVALID --> PRIME
    INDATA --> FIFO
    REV --> RSEL
    
    PRIME --> WACTIVE
    PRIME --> WSTART
    PRIME --> WEND
    
    WACTIVE --> MEM0
    WACTIVE --> MEM1
    WSEL --> MEM0
    WSEL --> MEM1
    
    READY -->|"line_available"| PRIME
    
    VGA --> CNT
    CNT --> SYNC
    CNT --> RSTART
    CNT --> REND
    SYNC --> CONSUME
    
    CONSUME --> RSTART
    CONSUME --> REND
    RSTART --> BYPASS
    RSEL --> MEM0
    RSEL --> MEM1
    
    MEM0 --> OMUX
    MEM1 --> OMUX
    BYPASS --> OMUX
    OMUX --> RGB
    
    SYNC --> HSYNC
    SYNC --> VSYNC
    SYNC --> DE
    FIFO --> UFLOW
    FIFO --> OFLOW
    FIFO --> LMIS
```

The system accepts an RGB24 stream with ready/valid handshaking, buffers lines in ping-pong FIFOs, and outputs synchronized to VGA timing.

### FIFO Buffer Detail (Ping-Pong Architecture)

```mermaid
flowchart TD
    START([Reset / Initialization])
    
    subgraph INIT ["System Initialize"]
        RESET["Set Initial State:<br/>ready0 = 0, ready1 = 0<br/>w_sel = 0, r_sel = 0<br/>writing = 0, reading = 0"]
    end
    
    subgraph PHASE_A ["Phase A: Buf0 Write / Buf1 Read"]
        subgraph W0 ["Buffer 0 Write Operation"]
            W0_S["write_line_start<br/>w_sel = 0<br/>writing = 1"]
            W0_P["Write Loop:<br/>if in_valid and write_active<br/>mem0 w_index = in_data<br/>w_index: 0 to 639"]
            W0_E["write_line_end<br/>ready0 = 1<br/>writing = 0"]
            
            W0_S --> W0_P
            W0_P --> W0_E
        end
        
        subgraph R1 ["Buffer 1 Read Operation"]
            R1_S["read_line_start<br/>r_sel = 1<br/>reading = 1"]
            R1_P["Read Loop:<br/>if consume<br/>out_data = mem1 read_col<br/>or reverse: mem1 639-col"]
            R1_E["read_line_end<br/>ready1 = 0<br/>reading = 0"]
            
            R1_S --> R1_P
            R1_P --> R1_E
        end
        
        W0 --> R1
    end
    
    SWAP_CHECK1{"Line Complete<br/>Swap Buffers?"}
    
    subgraph PHASE_B ["Phase B: Buf1 Write / Buf0 Read"]
        subgraph W1 ["Buffer 1 Write Operation"]
            W1_S["write_line_start<br/>w_sel = 1<br/>writing = 1"]
            W1_P["Write Loop:<br/>if in_valid and write_active<br/>mem1 w_index = in_data<br/>w_index: 0 to 639"]
            W1_E["write_line_end<br/>ready1 = 1<br/>writing = 0"]
            
            W1_S --> W1_P
            W1_P --> W1_E
        end
        
        subgraph R0 ["Buffer 0 Read Operation"]
            R0_S["read_line_start<br/>r_sel = 0<br/>reading = 1"]
            R0_P["Read Loop:<br/>if consume<br/>out_data = mem0 read_col<br/>or reverse: mem0 639-col"]
            R0_E["read_line_end<br/>ready0 = 0<br/>reading = 0"]
            
            R0_S --> R0_P
            R0_P --> R0_E
        end
        
        W1 --> R0
    end
    
    SWAP_CHECK2{"Line Complete<br/>Swap Buffers?"}
    
    subgraph ERRORS ["Error Conditions"]
        ERR_O["overflow<br/>No free buffer on write_line_start"]
        ERR_U["underflow<br/>No ready buffer on read_line_start"]
        ERR_L["line_mismatch<br/>Wrong line length"]
        
        ERR_O --> ERR_U
        ERR_U --> ERR_L
    end
    
    START --> INIT
    INIT --> PHASE_A
    PHASE_A --> SWAP_CHECK1
    SWAP_CHECK1 -->|Swap to Phase B| PHASE_B
    PHASE_B --> SWAP_CHECK2
    SWAP_CHECK2 -->|Swap to Phase A| PHASE_A
    
    PHASE_A -.error conditions.-> ERRORS
    PHASE_B -.error conditions.-> ERRORS
```

Two line buffers alternate roles each line. While buffer 0 reads out to VGA, buffer 1 fills from the input stream, then they swap.

### VGA Timing Diagram

#### Horizontal Timing - 800 pixels per line

```mermaid
flowchart LR
    subgraph H ["HORIZONTAL SCAN LINE"]
        H0["Pixels 0-639<br/><b>ACTIVE VIDEO</b><br/>hsync = 1<br/>de = 1 if y active"]
        H1["Pixels 640-655<br/><b>FRONT PORCH</b><br/>hsync = 1<br/>de = 0"]
        H2["Pixels 656-751<br/><b>HSYNC PULSE</b><br/>hsync = 0<br/>de = 0"]
        H3["Pixels 752-799<br/><b>BACK PORCH</b><br/>hsync = 1<br/>de = 0"]
        
        H0 --> H1
        H1 --> H2
        H2 --> H3
        H3 -->|Reset to 0<br/>Increment y| H0
    end
```

#### Vertical Timing - 525 lines per frame

```mermaid
flowchart LR
    subgraph V ["VERTICAL FRAME"]
        V0["Lines 0-479<br/><b>ACTIVE VIDEO</b><br/>vsync = 1<br/>de = 1 if x active"]
        V1["Lines 480-489<br/><b>FRONT PORCH</b><br/>vsync = 1<br/>de = 0"]
        V2["Lines 490-491<br/><b>VSYNC PULSE</b><br/>vsync = 0<br/>de = 0"]
        V3["Lines 492-524<br/><b>BACK PORCH</b><br/>vsync = 1<br/>de = 0"]
        
        V0 --> V1
        V1 --> V2
        V2 --> V3
        V3 -->|Reset to 0<br/>New Frame| V0
    end
```

#### Output Signal Summary

```mermaid
flowchart TD
    X["Pixel Counter X<br/>0 to 799"]
    Y["Line Counter Y<br/>0 to 524"]
    
    HSYNC["<b>HSYNC OUTPUT</b><br/>hsync = 0 when X in 656-751<br/>hsync = 1 otherwise"]
    VSYNC["<b>VSYNC OUTPUT</b><br/>vsync = 0 when Y in 490-491<br/>vsync = 1 otherwise"]
    DE["<b>DATA ENABLE OUTPUT</b><br/>de = 1 when X in 0-639 AND Y in 0-479<br/>de = 0 otherwise"]
    RGB["<b>RGB OUTPUT</b><br/>RGB = pixel_data when de = 1<br/>RGB = 0 black when de = 0"]
    
    X --> HSYNC
    Y --> VSYNC
    X --> DE
    Y --> DE
    DE --> RGB
```

Standard VGA timing with HSYNC, VSYNC, and data enable signals. The design supports 640×480 @ 60Hz by default.

---

## Structure

```
VGA Image Stream with Ping-Pong FIFO buffers/
├── top_stream.v              # Top module (FIFO + VGA)
├── video_stream_fifo.v       # Ping-pong FIFO
├── vga.v                     # VGA timing generator
├── top_stream_tb.v           # Main testbench
├── video_stream_fifo_tb.v    # FIFO testbench
├── tools/
│   ├── video_to_rgb.py       # Convert video to RGB24
│   └── waves/*.ps1           # Waveform viewing scripts
├── media/
│   ├── input/                # Input videos
│   └── frames/               # Output frames (PPM)
└── frames/
    └── video_frames.rgb      # Raw RGB24 data for testbench
```

---

## Quick Start

Prerequisites:
```
choco install icarus-verilog  # Windows
pip install opencv-python numpy
```

Convert video to RGB24:
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"; python tools/video_to_rgb.py --input media/input/first_video_short.mp4 --output frames/video_frames.rgb --width 640 --height 480 --fps 30
```

Run simulation:
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"; iverilog -g2012 -o stream_tb top_stream_tb.v top_stream.v video_stream_fifo.v vga.v; vvp stream_tb
```

Output: A captured frame saved to `media/frames/stream_normal.ppm`

View it:
```powershell
ffplay media/frames/stream_normal.ppm
```

---

## Features

**Ping-pong buffering:** Two line buffers enable continuous streaming without drops.

**Reverse mode:** Horizontal mirroring for flipped output.

**Status flags:** 
- `underflow` - Read from empty buffer
- `overflow` - Write to full buffer  
- `line_mismatch` - Buffer selection error

**VGA timing:** Proper HSYNC/VSYNC/DE generation for 640×480 @ 60Hz.

---

## Modules

**`top_stream.v`** - Coordinates FIFO and VGA timing.

**`video_stream_fifo.v`** - Dual line buffers with alternating read/write. Supports reverse read order for horizontal flip.

**`vga.v`** - Generates VGA timing signals and pixel coordinates.

---

## Waveforms

View with GTKwave:
```powershell
cd "VGA Image Stream with Ping-Pong FIFO buffers"; powershell -ExecutionPolicy Bypass -File tools\waves\wave_top_stream_tb.ps1
```

Key signals:
- `write_buf_sel`, `read_buf_sel` - Active buffer
- `ready0`, `ready1` - Buffer ready flags
- `in_valid`, `in_ready` - Input handshaking
- `out_valid`, `out_data` - Output to VGA
- `de`, `hsync`, `vsync` - VGA timing
- `x`, `y` - Pixel coordinates

Watch buffer switching at line boundaries and data flow from input through FIFOs to VGA output.

---

## Operation

1. Input stream provides RGB24 pixels with `in_valid`/`in_ready` handshaking
2. FIFO writes to one buffer while reading from the other
3. Buffers swap at line boundaries
4. VGA timing generator controls pixel output timing
5. Output pixels sync with HSYNC/VSYNC/DE signals

Reverse mode reads buffer addresses backward for horizontal flip.

---

## Troubleshooting

**No input file:** Run `video_to_rgb.py` to create `frames/video_frames.rgb`

**Status flags high:** Check timing - underflow means input too slow, overflow means too fast.

**No PPM output:** Verify `media/frames/` directory exists.

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



---

## Contributing

Contributions are welcome! Please ensure all simulations pass before submitting pull requests.
