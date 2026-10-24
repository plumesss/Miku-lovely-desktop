#!/usr/bin/env python3
from PIL import Image, ImageDraw
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description="Build a macOS icon from a local illustration.")
parser.add_argument("--input", type=Path, default=ROOT / "assets" / "miku_idle.png")
parser.add_argument("--output-dir", type=Path, default=ROOT / "src")
parser.add_argument("--preview", type=Path, help="Optional preview PNG output")
args = parser.parse_args()
if not args.input.is_file():
    parser.error("Input illustration is missing; supply --input or follow docs/ASSETS.md")
src = Image.open(args.input).convert("RGBA")
W, H = src.size

# crop head region (slightly left-of-center face) then square it
l, t = int(0.18 * W), int(0.0)
r, b = int(0.80 * W), int(0.44 * H)
head = src.crop((l, t, r, b))
cw, ch = head.size
side = min(cw, ch)
head = head.crop(((cw - side) // 2, 0, (cw + side) // 2, side))
head = head.resize((1024, 1024), Image.LANCZOS)

# teal gradient rounded-square background
bg = Image.new("RGBA", (1024, 1024))
grad = Image.new("RGBA", (1024, 1024))
px = grad.load()
top, bot = (96, 227, 235), (18, 90, 140)
for y in range(1024):
    k = y / 1023
    c = tuple(round(top[i] + (bot[i] - top[i]) * k) for i in range(3)) + (255,)
    for x in range(1024):
        px[x, y] = c
mask = Image.new("L", (1024, 1024), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, 1023, 1023], radius=220, fill=255)
bg.paste(grad, (0, 0), mask)

# paste head with slight shadow
shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
ImageDraw.Draw(shadow).ellipse([132, 700, 892, 1000], fill=(0, 40, 60, 90))
shadow = shadow.filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(40))
bg.alpha_composite(shadow)
bg.alpha_composite(head)

# macOS-style squircle margin
canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
canvas.alpha_composite(bg)

iconset = args.output_dir / "AppIcon.iconset"
iconset.mkdir(parents=True, exist_ok=True)
for s in [16, 32, 128, 256, 512]:
    canvas.resize((s, s), Image.LANCZOS).save(f"{iconset}/icon_{s}x{s}.png")
    canvas.resize((s * 2, s * 2), Image.LANCZOS).save(f"{iconset}/icon_{s}x{s}@2x.png")
subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o",
                str(args.output_dir / "AppIcon.icns")], check=True)
if args.preview:
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    canvas.resize((256, 256), Image.LANCZOS).save(args.preview)
print("icon done")
