#!/usr/bin/env python3
"""
Convert a video file into a raw RGB stream suitable for pixel_gen_video.

Usage:
    python tools/video_to_rgb.py --input input.mp4 --output frames/video_frames.rgb --width 640 --height 480 --fps 30

Requires FFmpeg to be installed and available on PATH.
"""

import argparse
import os
import subprocess
import sys


def run_ffmpeg(args):
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        args.input,
        "-vf",
        f"scale={args.width}:{args.height},fps={args.fps}",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        args.output,
    ]
    try:
        subprocess.check_call(cmd)
    except FileNotFoundError:
        sys.stderr.write("Error: ffmpeg not found. Install FFmpeg and ensure it is on PATH.\n")
        sys.exit(1)
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(f"ffmpeg failed with exit code {exc.returncode}\n")
        sys.exit(exc.returncode)


def main():
    parser = argparse.ArgumentParser(description="Convert video into raw RGB frames.")
    parser.add_argument("--input", "-i", required=True, help="Input video file (any FFmpeg-supported format).")
    parser.add_argument("--output", "-o", default="frames/video_frames.rgb", help="Output raw RGB file path.")
    parser.add_argument("--width", type=int, default=640, help="Output width in pixels.")
    parser.add_argument("--height", type=int, default=480, help="Output height in pixels.")
    parser.add_argument("--fps", type=int, default=30, help="Output frames per second.")
    args = parser.parse_args()

    out_dir = os.path.dirname(os.path.abspath(args.output))
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir)

    run_ffmpeg(args)
    print(f"Created raw RGB stream at {args.output}")


if __name__ == "__main__":
    main()
