#!/usr/bin/env python3
"""Chroma-key green screen Miku illustrations to transparent PNGs."""
import numpy as np
from PIL import Image
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATES = ("idle", "blink", "happy", "sad", "sleep")

def key_image(path):
    img = Image.open(path).convert("RGB")
    a = np.asarray(img).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]

    # greenness = how much green dominates over the other channels
    greenness = g - np.maximum(r, b)

    # soft alpha ramp: 0 where strongly green, 255 where clearly not green
    T_LO, T_HI = 18.0, 70.0
    alpha = np.clip((T_HI - greenness) / (T_HI - T_LO), 0.0, 1.0)

    # hard-kill pure background pixels to avoid halos
    bg = (greenness > 110) & (g > 180)
    alpha[bg] = 0.0

    # despill: remove green fringe on edge pixels
    spill = greenness > 0
    g_fixed = np.minimum(g, np.maximum(r, b))
    g = np.where(spill, g_fixed * 0.35 + g * 0.65, g)  # soften despill

    out = np.dstack([r, g, b, alpha * 255.0]).astype(np.uint8)
    result = Image.fromarray(out, "RGBA")

    # trim to content bounding box + small margin
    bbox = result.getchannel("A").getbbox()
    if bbox:
        pad = 12
        l, t, rr, bb = bbox
        l, t = max(0, l - pad), max(0, t - pad)
        rr, bb = min(result.width, rr + pad), min(result.height, bb + pad)
        result = result.crop((l, t, rr, bb))
    return result

# build white-composite previews for visual inspection
def preview(names, out_path, assets, prefix):
    imgs = [Image.open(assets / f"{prefix}_{n}.png").convert("RGBA") for n in names]
    h = 560
    thumbs = []
    for im in imgs:
        w = round(im.width * h / im.height)
        thumbs.append(im.resize((w, h), Image.LANCZOS))
    gap = 24
    W = sum(t.width for t in thumbs) + gap * (len(thumbs) + 1)
    sheet = Image.new("RGB", (W, h + 2 * gap), (235, 235, 240))
    x = gap
    for t in thumbs:
        sheet.paste(t, (x, gap), t)
        x += t.width + gap
    sheet.save(out_path, "PNG")
    print("preview:", out_path.name, sheet.size)


def main(prefix="miku"):
    parser = argparse.ArgumentParser(description="Remove green backgrounds from five local PNGs.")
    parser.add_argument("--input-dir", type=Path, required=True,
                        help="Folder containing idle.png, blink.png, happy.png, sad.png and sleep.png")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "assets")
    parser.add_argument("--previews", action="store_true", help="Also generate optional preview sheets")
    args = parser.parse_args()
    missing = [f"{state}.png" for state in STATES if not (args.input_dir / f"{state}.png").is_file()]
    if missing:
        parser.error("Missing input files: " + ", ".join(missing))
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for state in STATES:
        out = key_image(args.input_dir / f"{state}.png")
        dst = args.output_dir / f"{prefix}_{state}.png"
        out.save(dst, "PNG")
        print(f"{dst.name}: {out.width}x{out.height}")
    if args.previews:
        preview(["idle", "happy", "sad"], args.output_dir / f"preview_{prefix}_a.png", args.output_dir, prefix)
        preview(["blink", "sleep"], args.output_dir / f"preview_{prefix}_b.png", args.output_dir, prefix)


if __name__ == "__main__":
    main()
