#!/usr/bin/env python3
"""One-off: labeled contact sheet of every curated tile in ../tiles, so the
composition script's author (me) can see orientation/appearance before placing."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
TILES = HERE.parent / "tiles"

try:
    FONT = ImageFont.truetype("arial.ttf", 13)
except OSError:
    FONT = ImageFont.load_default()

entries = []  # (label, PIL image)
for sub in sorted(TILES.iterdir()):
    if not sub.is_dir():
        continue
    for p in sorted(sub.glob("*.png")):
        img = Image.open(p).convert("RGBA")
        entries.append((f"{sub.name}/{p.stem} {img.width}x{img.height}", img))

CELL_W, LABEL_H, PAD = 180, 18, 8
MAX_TILE = 160  # downscale anything bigger to fit the cell
COLS = 5
rows = (len(entries) + COLS - 1) // COLS
CELL_H = MAX_TILE + LABEL_H + PAD * 2

sheet = Image.new("RGBA", (COLS * CELL_W, rows * CELL_H), (40, 60, 70, 255))
draw = ImageDraw.Draw(sheet)
for i, (name, img) in enumerate(entries):
    cx = (i % COLS) * CELL_W
    cy = (i // COLS) * CELL_H
    t = img.copy()
    if max(t.size) > MAX_TILE:
        t.thumbnail((MAX_TILE, MAX_TILE))
    sheet.alpha_composite(t, (cx + (CELL_W - t.width) // 2, cy + PAD))
    draw.text((cx + 4, cy + CELL_H - LABEL_H), name, font=FONT, fill=(255, 255, 200, 255))

out = HERE / "contact_sheet.png"
sheet.convert("RGB").save(out)
print(f"wrote {out} ({sheet.width}x{sheet.height}, {len(entries)} tiles)")
