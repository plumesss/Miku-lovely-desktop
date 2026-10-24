#!/usr/bin/env python3
"""Sync only image resources; never copy private audio into Windows assets."""
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / 'windows-app' / 'assets'
DEST.mkdir(parents=True, exist_ok=True)
for skin, prefix in [('standard', 'miku'), ('chibi', 'miku_chibi'), ('crayon', 'miku_crayon')]:
    for state in ['idle', 'blink', 'happy', 'sad', 'sleep']:
        shutil.copyfile(ROOT / 'assets' / f'{prefix}_{state}.png', DEST / f'{skin}_{state}.png')
for folder in ['animation', 'mouths']:
    (DEST / folder).mkdir(exist_ok=True)
    for source in (ROOT / 'assets' / folder).iterdir():
        if source.suffix in ['.png', '.json']:
            shutil.copyfile(source, DEST / folder / source.name)
# Derive the icon from the same prepared artwork, not an unrelated old icon.
icon = Image.open(ROOT / 'assets' / 'miku_idle.png').convert('RGBA')
icon.thumbnail((256, 256))
canvas = Image.new('RGBA', (256, 256))
canvas.alpha_composite(icon, ((256-icon.width)//2, (256-icon.height)//2))
canvas.save(ROOT / 'windows-app' / 'app.ico', sizes=[(n,n) for n in [16,32,48,64,128,256]])
print('Windows artwork prepared; no audio copied.')
