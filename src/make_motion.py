"""Build looping local-deformation frames from the existing transparent art.

No model download or runtime Python dependency. Frames retain the original art;
this is a 2D image rig, not a Cubism/Live2D model. Warp premultiplied pixels to
avoid green/black outlines and reserve transparent padding for moving hair.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'animation'
COUNT, COLS, HEIGHT, PAD = 48, 8, 448, 0.06
SKINS = {'standard': 'miku', 'chibi': 'miku_chibi', 'crayon': 'miku_crayon'}
STATES = ['idle', 'blink', 'happy', 'sad', 'sleep']


def warp(source, phase, skin, state):
    h, w = source.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    x = (xx / (w - 1) - PAD) / (1 - 2 * PAD) - 0.5
    y = (yy / (h - 1) - PAD) / (1 - 2 * PAD)
    quiet = 0.42 if state == 'sleep' else 1.0
    head_y, head_h, head_w = {
        'standard': (0.15, 0.17, 0.16),
        'chibi': (0.25, 0.29, 0.28),
        'crayon': (0.34, 0.29, 0.29),
    }[skin]
    head = np.exp(-((y - head_y) / head_h) ** 4 - (x / head_w) ** 4)
    outer = np.clip((np.abs(x) - head_w * 0.7) / 0.18, 0, 1)
    length = np.clip((y - head_y) / 0.55, 0, 1)
    # A continuous field keeps hair roots joined to the head and body.
    hair = outer * length
    dx = quiet * (0.004 * np.sin(phase) * (1 - y)
                  + head * 0.010 * np.sin(phase)
                  + hair * 0.026 * np.sin(phase + y * 3 + np.sign(x) * 0.8))
    dy = quiet * (-0.005 * np.sin(phase * 2) * (1 - y)
                  + head * 0.005 * np.cos(phase))
    if skin == 'crayon' and state != 'sleep':
        # Chewing nod: move the face locally, leaving feet and leek anchored.
        dy += head * 0.006 * (np.cos(phase * 3) - 0.3)
    sx = xx - dx * w * (1 - 2 * PAD)
    sy = yy - dy * h * (1 - 2 * PAD)
    x0, y0 = np.floor(sx).astype(int), np.floor(sy).astype(int)
    ax, ay = (sx - x0)[..., None], (sy - y0)[..., None]
    valid = (x0 >= 0) & (x0 + 1 < w) & (y0 >= 0) & (y0 + 1 < h)
    x0, y0 = np.clip(x0, 0, w - 2), np.clip(y0, 0, h - 2)
    result = ((source[y0, x0] * (1 - ax) + source[y0, x0 + 1] * ax) * (1 - ay)
              + (source[y0 + 1, x0] * (1 - ax) + source[y0 + 1, x0 + 1] * ax) * ay)
    result *= valid[..., None]
    alpha = result[..., 3:4]
    rgb = np.divide(result[..., :3], alpha, out=np.zeros_like(result[..., :3]), where=alpha > 0.001)
    return Image.fromarray(np.uint8(np.clip(np.concatenate([rgb, alpha], axis=2) * 255, 0, 255)))


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    signature = hashlib.sha256(Path(__file__).read_bytes())
    for prefix in SKINS.values():
        for state in STATES:
            signature.update((ROOT / 'assets' / f'{prefix}_{state}.png').read_bytes())
    digest = signature.hexdigest()
    stamp = OUT / 'manifest.json'
    if stamp.exists() and json.loads(stamp.read_text()).get('digest') == digest:
        if all((OUT / f'{s}_{st}.png').exists() for s in SKINS for st in STATES):
            print('Animation frames already up to date.'); return
    entries = {}
    for skin, prefix in SKINS.items():
        for state in STATES:
            im = Image.open(ROOT / 'assets' / f'{prefix}_{state}.png').convert('RGBA')
            inner_h = round(HEIGHT * (1 - 2 * PAD))
            inner_w = round(inner_h * im.width / im.height)
            width = round(inner_w / (1 - 2 * PAD))
            canvas = Image.new('RGBA', (width, HEIGHT))
            im = im.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
            canvas.paste(im, ((width - inner_w) // 2, (HEIGHT - inner_h) // 2))
            source = np.asarray(canvas).astype(np.float32) / 255
            source[..., :3] *= source[..., 3:4]
            atlas = Image.new('RGBA', (width * COLS, HEIGHT * (COUNT // COLS)))
            for frame in range(COUNT):
                result = warp(source, frame * 2 * np.pi / COUNT, skin, state)
                # Safety border must stay transparent, including moving hair.
                assert not np.asarray(result)[[0, -1], :, 3].any()
                assert not np.asarray(result)[:, [0, -1], 3].any()
                atlas.paste(result, ((frame % COLS) * width, (frame // COLS) * HEIGHT))
            key = f'{skin}_{state}'
            atlas.save(OUT / f'{key}.png')
            entries[key] = {'width': width, 'height': HEIGHT}
            print(f'{key}: {COUNT} frames', flush=True)
    stamp.write_text(json.dumps({'digest': digest, 'count': COUNT, 'columns': COLS,
                                'padding': PAD, 'seconds': 4, 'entries': entries}, indent=2))


if __name__ == '__main__':
    build()
