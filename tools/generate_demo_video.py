import struct
import os

W, H = 640, 480
FRAMES = 60
out_path = os.path.join('frames', 'video_frames.rgb')
os.makedirs('frames', exist_ok=True)
with open(out_path, 'wb') as f:
    for frame in range(FRAMES):
        for y in range(H):
            for x in range(W):
                r = (x + frame*4) % 256
                g = (y*2 + frame*2) % 256
                b = (x ^ y ^ (frame*3)) & 0xFF
                f.write(struct.pack('BBB', r, g, b))
print(f"Wrote {FRAMES} frames to {out_path}")
