#!/usr/bin/env python3
"""Generate annotated background-authoring reference strips for Level 1 (Pacific Beachhead).

These are the *reference-only* templates (the kind shipped as `stage1_template_REFERENCE.png`):
a tall 540-wide strip painted with the stage's placeholder gradient, overlaid with a 128 px grid,
the parked-frame line, the travel-direction arrow, and the per-stage authoring notes. Drop one in
as the locked bottom layer in Photopea and build the real strip on top (see README.md).

They never ship in a build — they only guide hand-authoring. Re-run after changing a stage's size,
scroll speed, or gradient in `resources/level_backgrounds/level_pacific.tres` so the reference and
the placeholder stay in sync.

    python make_reference_template.py            # regenerates stage2 + stage3
    python make_reference_template.py 1 2 3      # also (re)generate stage1

Stage geometry / gradients below are mirrored from level_pacific.tres. Filenames are 1-indexed
(stage1/2/3); the .tres array is 0-indexed (SB_s0/s1/s2) — stageN file -> SB_s(N-1).
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
WIDTH = 540
GRID = 128          # px, matches the in-game tile size
PARK = 960          # the top 960 px park as the backdrop for late body + boss approach


# --- fonts -------------------------------------------------------------------
def _font(names, size):
    for n in names:
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            continue
    return ImageFont.load_default()


F_BIG = _font(["arialbd.ttf", "DejaVuSans-Bold.ttf"], 30)
F_MED = _font(["arialbd.ttf", "DejaVuSans-Bold.ttf"], 20)
F_SML = _font(["arial.ttf", "DejaVuSans.ttf"], 15)
F_TINY = _font(["arial.ttf", "DejaVuSans.ttf"], 13)


# --- gradient ----------------------------------------------------------------
def _lerp(a, b, t):
    return tuple(round((a[i] + (b[i] - a[i]) * t) * 255) for i in range(3))


def paint_gradient(img, stops):
    """stops: list of (offset0..1, (r,g,b) 0..1). offset 0 = TOP (matches fill_to=(0,1))."""
    h = img.height
    px = img.load()
    row = [(0, 0, 0)] * h
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(stops) - 1):
            o0, c0 = stops[i]
            o1, c1 = stops[i + 1]
            if o0 <= t <= o1:
                seg = (t - o0) / (o1 - o0) if o1 > o0 else 0.0
                row[y] = _lerp(c0, c1, seg)
                break
        else:
            row[y] = tuple(round(c * 255) for c in stops[-1][1])
    for y in range(h):
        c = row[y]
        for x in range(WIDTH):
            px[x, y] = c


# --- annotation helpers ------------------------------------------------------
def label(draw, xy, lines, anchor="lt", pad=8):
    """Draw a dark rounded plaque with one or more (text, font, fill) lines."""
    widths, heights = [], []
    for text, font, _ in lines:
        l, t, r, b = draw.textbbox((0, 0), text, font=font)
        widths.append(r - l)
        heights.append(b - t)
    bw = max(widths) + pad * 2
    bh = sum(heights) + pad * 2 + (len(lines) - 1) * 4
    x, y = xy
    if "r" in anchor:
        x -= bw
    if "b" in anchor:
        y -= bh
    draw.rounded_rectangle([x, y, x + bw, y + bh], radius=6, fill=(12, 16, 20, 235))
    cy = y + pad
    for (text, font, fill), th in zip(lines, heights):
        draw.text((x + pad, cy), text, font=font, fill=fill)
        cy += th + 4
    return x, y, bw, bh


def up_arrow(draw, x, top, bottom):
    draw.line([(x, bottom), (x, top)], fill=(150, 220, 255, 230), width=3)
    draw.polygon([(x, top - 14), (x - 9, top + 6), (x + 9, top + 6)], fill=(150, 220, 255, 230))


def dashed_box(draw, box, color, dash=14, gap=10, width=3):
    x0, y0, x1, y1 = box
    def seg(a, b, horiz):
        pos = a
        while pos < b:
            end = min(pos + dash, b)
            if horiz:
                draw.line([(pos, y0), (end, y0)], fill=color, width=width)
                draw.line([(pos, y1), (end, y1)], fill=color, width=width)
            else:
                draw.line([(x0, pos), (x0, end)], fill=color, width=width)
                draw.line([(x1, pos), (x1, end)], fill=color, width=width)
            pos += dash + gap
    seg(x0, x1, True)
    seg(y0, y1, False)


# --- per-stage definitions (mirror level_pacific.tres) -----------------------
STAGES = {
    1: dict(
        height=3200, speed=75,
        gradient=[(0.0, (0.18, 0.45, 0.52)), (0.15, (0.5, 0.62, 0.62)),
                  (0.5, (0.72, 0.66, 0.5)), (1.0, (0.5, 0.55, 0.42))],
        title="STAGE 1: OPEN OCEAN",
        mid=["keep it SPARSE - the FTUE onramp",
             "Warship mini-boss fights here, on water"],
        park_note="^ first SAND sliver appears up here",
        park_kind="(late body + pre-boss play over this frame)",
        bottom=["BOTTOM = START",
                "seen first at launch - open ocean; scatter a wreck or two"],
        landmark=None,
    ),
    2: dict(
        height=3200, speed=85,
        # SB_s1 / Gradient_s1 : top greenish -> tan sand -> teal surf -> deep water bottom
        gradient=[(0.0, (0.5, 0.55, 0.42)), (0.5, (0.72, 0.66, 0.5)),
                  (0.85, (0.5, 0.62, 0.62)), (1.0, (0.18, 0.45, 0.52))],
        title="STAGE 2: THE BEACHHEAD",
        mid=["full shoreline - sand, surf, bunkers, crates",
             "Coastal-gun mini-boss sits in the dunes"],
        park_note="^ full TREELINE / dune crest fills the parked frame",
        park_kind="(busier than St.1 - landmarks pace the speed)",
        bottom=["BOTTOM = START",
                "surf line meets first sand - carry the coast up from open water"],
        landmark=("COASTAL-GUN MINI-BOSS\nsits among the dunes here",
                  (255, 200, 90, 230), 0.42, 0.56),
    ),
    3: dict(
        height=3400, speed=95,
        # SB_s2 / Gradient_s2 : top grey -> tan sand -> blue surf bottom
        gradient=[(0.0, (0.4, 0.42, 0.4)), (0.2, (0.55, 0.52, 0.42)),
                  (0.6, (0.7, 0.64, 0.5)), (1.0, (0.45, 0.58, 0.6))],
        title="STAGE 3: THE FORTRESS SHORE",
        mid=["heavily fortified beach - bunkers, guns, craters",
             "densest stage; everything builds to the fortress"],
        park_note="^ COASTAL FORTRESS on the horizon - PRE-BOSS TELEGRAPH (mandatory)",
        park_kind="(then the BOSS ARENA texture takes over)",
        bottom=["BOTTOM = START",
                "fortified surf line - continue the beach straight up from St.2"],
        landmark=("FORTRESS SILHOUETTE\npark it in the top 960 so it\nslides into view before the boss bar",
                  (255, 120, 110, 235), 0.04, 0.20),
    ),
}


def build(stage_id):
    s = STAGES[stage_id]
    h = s["height"]
    img = Image.new("RGB", (WIDTH, h))
    paint_gradient(img, s["gradient"])
    img = img.convert("RGBA")
    draw = ImageDraw.Draw(img, "RGBA")

    # 128 px grid
    for x in range(0, WIDTH + 1, GRID):
        draw.line([(x, 0), (x, h)], fill=(210, 235, 245, 55), width=1)
    for y in range(0, h + 1, GRID):
        draw.line([(0, y), (WIDTH, y)], fill=(210, 235, 245, 55), width=1)

    # travel arrow (player flies NORTH up the strip; world scrolls DOWN on screen)
    up_arrow(draw, WIDTH - 60, top=PARK + 40, bottom=h - 120)

    # parked-frame divider + note (top 960 px parks)
    draw.line([(0, PARK), (WIDTH, PARK)], fill=(255, 214, 70, 235), width=3)
    label(draw, (8, PARK + 8), [(s["park_note"], F_SML, (255, 230, 120))])

    # top plaque
    label(draw, (8, 12), [
        ("TOP = END of journey", F_BIG, (255, 226, 150)),
        ("strip PARKS on this top 960px", F_MED, (235, 240, 245)),
        (s["park_kind"], F_TINY, (180, 195, 205)),
    ])

    # optional landmark hint box
    if s["landmark"]:
        text, color, oy0, oy1 = s["landmark"]
        box = (40, int(h * oy0), WIDTH - 40, int(h * oy1))
        dashed_box(draw, box, color)
        tx, ty = 56, int(h * oy0) + 10
        for ln in text.split("\n"):
            draw.text((tx, ty), ln, font=F_MED, fill=color)
            ty += 24

    # middle stage plaque
    midy = int(h * 0.60)
    lines = [(s["title"], F_BIG, (235, 245, 255))]
    lines += [(t, F_SML, (210, 225, 235)) for t in s["mid"]]
    _, _, _, mid_h = label(draw, (8, midy), lines)
    label(draw, (WIDTH - 8, midy + mid_h + 10), [
        ("NORTH up the strip ->", F_SML, (170, 220, 255)),
        ("(image scrolls DOWN on screen)", F_TINY, (150, 175, 190)),
    ], anchor="rt")

    # bottom plaque + dimensions
    label(draw, (8, h - 12), [
        (s["bottom"][0], F_BIG, (235, 245, 255)),
        (s["bottom"][1], F_SML, (210, 225, 235)),
    ], anchor="lb")
    label(draw, (WIDTH - 8, h - 12),
          [(f"540 x {h}   @ {s['speed']} px/s", F_TINY, (200, 215, 225))], anchor="rb")

    out = HERE / f"stage{stage_id}_template_REFERENCE.png"
    img.convert("RGB").save(out)
    print(f"wrote {out.name}  ({WIDTH}x{h}, {s['speed']} px/s)")


def build_seabase(stage_id):
    """The plain gradient strip — same colours as the template, no grid/text/annotations.
    A clean base layer to paint over (the counterpart to stage1_seabase.png)."""
    s = STAGES[stage_id]
    img = Image.new("RGB", (WIDTH, s["height"]))
    paint_gradient(img, s["gradient"])
    out = HERE / f"stage{stage_id}_seabase.png"
    img.save(out)
    print(f"wrote {out.name}  ({WIDTH}x{s['height']}, gradient only)")


# The boss arena is a STATIC 540x960 frame (not a scrolling strip): the Coastal
# Fortress backdrop that swaps in when the named boss spawns. Gradient mirrors
# Gradient_arena in level_pacific.tres: grey sky -> warm sand band -> dark stone.
ARENA = dict(
    width=540, height=960,
    gradient=[(0.0, (0.55, 0.6, 0.62)), (0.55, (0.6, 0.56, 0.46)), (1.0, (0.45, 0.42, 0.38))],
)


def build_arena_seabase():
    """Plain 540x960 boss-arena base — same colours as boss_arena_texture, no annotations."""
    img = Image.new("RGB", (ARENA["width"], ARENA["height"]))
    paint_gradient(img, ARENA["gradient"])
    out = HERE / "boss_arena_seabase.png"
    img.save(out)
    print(f"wrote {out.name}  ({ARENA['width']}x{ARENA['height']}, gradient only)")


if __name__ == "__main__":
    args = sys.argv[1:]
    seabase = "seabase" in args
    if "arena" in args:
        build_arena_seabase()
    ids = [int(a) for a in args if a.isdigit()]
    if ids or "arena" not in args:
        for i in (ids or [2, 3]):
            build_seabase(i) if seabase else build(i)
