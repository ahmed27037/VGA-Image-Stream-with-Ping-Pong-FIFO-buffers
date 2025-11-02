import numpy as np
from pathlib import Path
W,H=640,480
raw = Path('frames/video_frames.rgb').read_bytes()
frame = np.frombuffer(raw[:W*H*3],dtype=np.uint8).reshape(H,W,3)
print('raw first 5 pixels:', frame[0,:5])
with open('media/frames/stream_normal.ppm') as f:
    tokens=[]
    while len(tokens)<4:
        line=f.readline()
        if not line:
            break
        if line.startswith('#') or not line.strip():
            continue
        tokens.extend(line.split())
    width=int(tokens[1]); height=int(tokens[2]); maxval=int(tokens[3])
    numbers=[]
    for line in f:
        if line.startswith('#') or not line.strip():
            continue
        numbers.extend(line.split())
vals=[(int(numbers[i]), int(numbers[i+1]), int(numbers[i+2])) for i in range(0,len(numbers),3)]
ppm=np.array(vals,dtype=np.uint8).reshape(height,width,3)
print('ppm first 5 pixels:', ppm[0,:5])
print('diff first row:', np.abs(ppm[0]-frame[0]).sum())
print('diff total:', np.abs(ppm-frame).sum())
