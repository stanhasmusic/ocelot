#!/usr/bin/env python3
"""Claude's take on the Level 1 (Pacific Beachhead) background strips.

Alternate versions of stage{1,2,3}_greybox.png, composed programmatically:
gradient base mirrored from level_pacific.tres, procedural water/sand texture,
and the curated ../tiles placed per docs/design/level-build-guide.md.

Outputs stage{1,2,3}_greybox_claude.png next to this script. Never wired into
the .tres unless a human repoints it — the hand-painted strips stay canonical.

    python make_claude_take.py          # all three stages
    python make_claude_take.py 1 3      # pick stages
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

HERE = Path(__file__).resolve().parent
TILES = HERE.parent / "tiles"
WIDTH = 540
GRID = 128
PARK = 960

rng = random.Random(1943)  # deterministic — re-runs reproduce the same strips


# --- tile loading -------------------------------------------------------------
_cache: dict[str, Image.Image] = {}


def tile(name: str) -> Image.Image:
    """Load ../tiles/<group>/<name>.png as RGBA, cached."""
    if name not in _cache:
        matches = list(TILES.glob(f"*/{name}.png"))
        if not matches:
            raise FileNotFoundError(name)
        _cache[name] = Image.open(matches[0]).convert("RGBA")
    return _cache[name]


def place(canvas: Image.Image, name: str, x: int, y: int, *, rotate: float = 0,
          scale: float = 1.0, alpha: float = 1.0, darken: float = 1.0,
          flip: bool = False) -> None:
    """Composite a tile with optional rotate/scale/alpha/brightness tweaks.
    (x, y) is the top-left of the (post-transform) sprite."""
    img = tile(name)
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    if scale != 1.0:
        img = img.resize((max(1, round(img.width * scale)),
                          max(1, round(img.height * scale))), Image.LANCZOS)
    if rotate:
        img = img.rotate(rotate, expand=True, resample=Image.BICUBIC)
    if darken != 1.0:
        img = ImageEnhance.Brightness(img).enhance(darken)
    if alpha < 1.0:
        a = img.getchannel("A").point(lambda v: int(v * alpha))
        img.putalpha(a)
    canvas.alpha_composite(img, (x, y))


def blend(img: Image.Image, fn) -> None:
    """Run drawing ops against a transparent overlay, then alpha-composite it.

    Pillow gotcha: ImageDraw.Draw(rgba_img, "RGBA") does NOT blend — it writes
    raw RGBA values (translucent fills turn opaque after convert("RGB")). Only
    drawing onto a transparent layer + alpha_composite blends correctly."""
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fn(ImageDraw.Draw(ov))
    img.alpha_composite(ov)


# --- gradient + texture bases ---------------------------------------------------
def gradient_strip(height: int, stops) -> Image.Image:
    """Vertical gradient, offset 0 = top (mirrors GradientTexture2D fill_to=(0,1))."""
    offs = np.array([o for o, _ in stops])
    cols = np.array([c for _, c in stops])  # 0..1 rgb
    t = np.linspace(0, 1, height)
    chans = [np.interp(t, offs, cols[:, i]) for i in range(3)]
    row = (np.stack(chans, axis=1) * 255).astype(np.uint8)  # (h, 3)
    arr = np.repeat(row[:, None, :], WIDTH, axis=1)         # (h, w, 3)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def water_texture(img: Image.Image, y0: int, y1: int, *, strength: float = 9.0) -> None:
    """Subtle interleaved wave bands over [y0, y1) — low contrast on purpose
    (the guide: the background must never out-shout the gameplay)."""
    h = y1 - y0
    yy, xx = np.mgrid[0:h, 0:WIDTH].astype(np.float32)
    w = (np.sin(yy / 17.0 + np.sin(xx / 41.0) * 2.1)
         + 0.6 * np.sin(yy / 7.3 + xx / 90.0)
         + 0.4 * np.sin((xx + yy * 0.35) / 13.0))
    w = (w / 2.0 * strength).astype(np.int16)
    region = np.asarray(img.crop((0, y0, WIDTH, y1)), dtype=np.int16)
    region[..., :3] = np.clip(region[..., :3] + w[..., None], 0, 255)
    img.paste(Image.fromarray(region.astype(np.uint8), "RGBA"), (0, y0))


def grain(img: Image.Image, y0: int, y1: int, *, amp: int = 5, seed: int = 7) -> None:
    """Fine noise so flat fills don't band — kept under the bullet-legibility bar."""
    nrng = np.random.default_rng(seed)
    noise = nrng.integers(-amp, amp + 1, (y1 - y0, WIDTH, 1), dtype=np.int16)
    region = np.asarray(img.crop((0, y0, WIDTH, y1)), dtype=np.int16)
    region[..., :3] = np.clip(region[..., :3] + noise, 0, 255)
    img.paste(Image.fromarray(region.astype(np.uint8), "RGBA"), (0, y0))


def tile_fill(canvas: Image.Image, name: str, y0: int, y1: int, *, alpha: float = 1.0) -> None:
    """Tile a 128px base texture across [y0, y1), grid-aligned."""
    t = tile(name)
    if alpha < 1.0:
        t = t.copy()
        a = t.getchannel("A").point(lambda v: int(v * alpha))
        t.putalpha(a)
    start = (y0 // GRID) * GRID
    for y in range(start, y1, GRID):
        for x in range(0, WIDTH, GRID):
            crop_bottom = min(GRID, y1 - y)
            crop_top = max(0, y0 - y)
            if crop_bottom <= crop_top:
                continue
            piece = t.crop((0, crop_top, GRID, crop_bottom))
            canvas.alpha_composite(piece, (x, y + crop_top))


# --- drawn details (each composites one blended overlay) ------------------------
def wake(img: Image.Image, x: int, y: int, length: int, width_px: int) -> None:
    """Foam wake trailing SOUTH (down the strip) behind a north-bound ship."""
    def fn(d):
        for i in range(length):
            t = i / length
            spread = 1 + t * width_px
            a = int(70 * (1 - t))
            d.line([(x - spread, y + i), (x + spread, y + i)], fill=(235, 245, 245, a))
    blend(img, fn)


def ripple(img: Image.Image, x: int, y: int, r: int, alpha: int = 13) -> None:
    # deliberately faint + cool: white rings would read as player-shot/projectile
    blend(img, lambda d: d.ellipse([x - r, y - r // 3, x + r, y + r // 3],
                                   outline=(190, 225, 230, alpha), width=2))


def foam_line(img: Image.Image, y: int, *, amp: float = 4, alpha: int = 60,
              x0: int = 0, x1: int = WIDTH) -> None:
    """A wavy white surf-foam streak across [x0, x1)."""
    pts = [(x, y + amp * math.sin(x / 23.0) + amp * 0.5 * math.sin(x / 7.0))
           for x in range(x0, x1 + 1, 4)]
    blend(img, lambda d: d.line(pts, fill=(240, 248, 248, alpha), width=3))


def crater(img: Image.Image, x: int, y: int, r: int) -> None:
    """Shell crater: dark bowl + raised pale rim, low contrast."""
    def fn(d):
        d.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=(0, 0, 0, 48))
        d.ellipse([x - r * 0.6, y - r * 0.5, x + r * 0.6, y + r * 0.5], fill=(0, 0, 0, 56))
        d.arc([x - r, y - r * 0.8, x + r, y + r * 0.8], 200, 340,
              fill=(255, 250, 235, 70), width=3)
    blend(img, fn)


def tracks(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    """Twin vehicle ruts pressed into the sand."""
    dx, dy = x1 - x0, y1 - y0
    n = max(1, int(math.hypot(dx, dy) // 6))

    def fn(d):
        for off in (-7, 7):
            nx, ny = -dy, dx
            norm = math.hypot(nx, ny) or 1
            ox, oy = nx / norm * off, ny / norm * off
            pts = []
            for i in range(n + 1):
                t = i / n
                wob = math.sin(t * 14) * 2
                pts.append((x0 + dx * t + ox + wob, y0 + dy * t + oy))
            d.line(pts, fill=(95, 82, 60, 60), width=4)
    blend(img, fn)


def tank_traps(img: Image.Image, y: int, count: int, *, seed: int) -> None:
    """A staggered row of dark X obstacles (hedgehogs) across the beach."""
    trng = random.Random(seed)

    def fn(d):
        for i in range(count):
            x = int((i + 0.5) * WIDTH / count + trng.uniform(-14, 14))
            yy = y + trng.randint(-10, 10)
            s = trng.randint(7, 10)
            for ang in (45, -45):
                a = math.radians(ang)
                dx, dy = math.cos(a) * s, math.sin(a) * s
                d.line([(x - dx, yy - dy), (x + dx, yy + dy)], fill=(40, 36, 30, 220), width=4)
                d.line([(x - dx, yy - dy), (x + dx, yy + dy)], fill=(80, 72, 58, 220), width=2)
    blend(img, fn)


def dunes(img: Image.Image, bands) -> None:
    """Broad, very soft light/dark sand undulations: (y, alpha) per band."""
    def fn(d):
        for dy, da in bands:
            d.ellipse([-160, dy, WIDTH + 160, dy + 130], fill=(255, 250, 235, da))
            d.ellipse([-160, dy + 110, WIDTH + 160, dy + 200], fill=(60, 50, 30, max(3, da // 2)))
    blend(img, fn)


def shoreline(canvas: Image.Image, shore_y: int, *, seed: int = 0) -> None:
    """The rocky surf edge: sand above shore_y, water below. The sand fill must
    STOP at shore_y — these tiles' transparent water side shows whatever is
    underneath. A straight beach_bm_* row: the tile set has no inner-corner
    pieces, so jogs read as seams; variants + foam + wrecks carry the variety
    (the hand-painted strips made the same call)."""
    srng = random.Random(seed)
    for x in range(0, WIDTH, GRID):
        place(canvas, f"beach_bm_0{srng.randint(1, 3)}", x, shore_y)


# --- stage bases (mirrored from level_pacific.tres placeholders) ---------------
G_S1 = [(0.0, (0.18, 0.45, 0.52)), (0.15, (0.5, 0.62, 0.62)),
        (0.5, (0.72, 0.66, 0.5)), (1.0, (0.5, 0.55, 0.42))]
G_OCEAN = [(0.0, (0.22, 0.47, 0.54)), (0.55, (0.18, 0.45, 0.52)),
           (1.0, (0.14, 0.38, 0.46))]  # stage 1: pure ocean, light horizon -> deep south


# ================================ STAGE 1 =====================================
def build_stage1() -> Image.Image:
    """The crossing: open ocean, the invasion fleet below, first sandbar at the top."""
    H = 3200
    img = gradient_strip(H, G_OCEAN)
    water_texture(img, 0, H)
    grain(img, 0, H, amp=3, seed=11)

    # -- the invasion fleet, sailing north with us (sparse: FTUE onramp) --------
    fleet = [
        # (tile, x, y, scale, darken)  lower 2/3 only — parked frame stays calm
        ("ship_small_body",  70, 2880, 0.9, 0.92),
        ("ship_small_body", 390, 2700, 0.85, 0.9),
        ("ship_medium_body", 210, 2400, 1.0, 0.95),
        ("ship_small_body", 450, 2150, 0.9, 0.9),
        ("ship_medium_body",  60, 1820, 0.95, 0.92),
        ("ship_small_body", 300, 1500, 0.85, 0.9),
    ]
    for name, x, y, sc, dk in fleet:
        t = tile(name)
        w = round(t.width * sc)
        h = round(t.height * sc)
        wake(img, x + w // 2, y + h - 6, length=int(h * 1.1), width_px=6)
        place(img, name, x, y, scale=sc, darken=dk, rotate=rng.uniform(-3, 3))

    # -- mid-strip set-piece: a ship that didn't make it ------------------------
    place(img, "ship_large_body_destroyed", 330, 1050, rotate=24, darken=0.62, alpha=0.85)
    for _ in range(7):
        ripple(img, rng.randint(330, 510), rng.randint(1080, 1400), rng.randint(14, 36))
    # scattered open-water ripples elsewhere, very quiet
    for _ in range(14):
        ripple(img, rng.randint(20, 520), rng.randint(200, 2900), rng.randint(10, 24), alpha=10)

    # -- parked frame: the first sliver of sand (top-right sandbar) -------------
    # a single row of beach tiles composited straight over the ocean: their sand
    # bleeds off the top edge (calm), their rocky face wraps the south + west
    place(img, "beach_bl", 2 * GRID, 0)        # corner: rock along bottom + left
    place(img, "beach_bm_01", 3 * GRID, 0)     # rock along bottom
    place(img, "beach_bm_02", 4 * GRID, 0)     # rock along bottom (clipped 28px col)
    foam_line(img, GRID + 20, alpha=42, x0=2 * GRID + 30)
    # palms on the bar so it reads "land!", not "weird yellow water"
    place(img, "tree_04", 420, 8, darken=0.96)
    place(img, "tree_05", 350, 52, scale=0.9, darken=0.9)
    place(img, "tree_06", 480, 30, scale=0.95)

    return img


# ================================ STAGE 2 =====================================
def build_stage2() -> Image.Image:
    """The beachhead: surf -> working beach -> treeline -> jungle parked frame."""
    H = 3200
    SHORE = 2050          # rocky edge: sand above, water below
    TREELINE = 700        # trees start; jungle above
    img = gradient_strip(H, G_S1[:1] + [(0.3, (0.5, 0.62, 0.62)), (1.0, (0.16, 0.42, 0.5))])
    water_texture(img, SHORE, H)
    grain(img, SHORE, H, amp=3, seed=22)

    # -- sand body ---------------------------------------------------------------
    tile_fill(img, "sand", 0, SHORE)
    grain(img, 0, SHORE, amp=4, seed=23)

    # -- jungle top --------------------------------------------------------------
    tile_fill(img, "grass", 0, TREELINE - GRID)
    # ragged grass/sand boundary: continue the grass texture downward by a
    # varying depth per 16px column so the cut isn't a ruler line
    gtile = tile("grass")
    for x in range(0, WIDTH, 16):
        depth = int(14 * math.sin(x / 37.0)) + rng.randint(4, 22)
        sx = x % GRID
        # fill's last partial row ends mid-tile; row 60 continues it seamlessly
        piece = gtile.crop((sx, 60, min(sx + 16, GRID), min(60 + max(depth, 1), GRID)))
        img.alpha_composite(piece, (x, TREELINE - GRID))
    grain(img, 0, TREELINE, amp=5, seed=24)

    # -- the surf line -------------------------------------------------------------
    shoreline(img, SHORE, seed=2)
    foam_line(img, SHORE + GRID + 26, alpha=64)
    foam_line(img, SHORE + GRID + 70, amp=6, alpha=40)

    # landing craft still coming in below the surf
    wake(img, 120 + 27, 2740 + 100, 110, 6)
    place(img, "ship_small_body", 120, 2740, darken=0.9, rotate=-4)
    wake(img, 395 + 27, 2950 + 100, 110, 6)
    place(img, "ship_small_body", 395, 2950, darken=0.88, rotate=5)
    # the one that beached, straddling the rocks
    place(img, "ship_medium_body_destroyed", 60, SHORE - 40, rotate=-18, darken=0.7)

    # -- the working beach ---------------------------------------------------------
    # dune shading first (underneath everything placed on the sand)
    dunes(img, ((1900, 14), (1620, 10), (1250, 12), (950, 10)))
    # supply dump: crate + barrel clusters with breathing room between landmarks
    cluster_a = [("crates_3", 340, 1760), ("crates_1", 412, 1742), ("barrels_1", 300, 1796)]
    cluster_b = [("crates_2", 90, 1380), ("crates_4", 150, 1420), ("barrels_2", 60, 1448)]
    cluster_c = [("crates_1", 420, 1060), ("barrels_1", 376, 1102)]
    for name, x, y in cluster_a + cluster_b + cluster_c:
        place(img, name, x, y)
    # vehicle ruts: from the bay landing up the beach toward the dump and treeline
    tracks(img, 300, SHORE - 8, 350, 1820)
    tracks(img, 330, 1750, 250, 900)
    tracks(img, 140, SHORE - 30, 110, 1460)

    # the dune bunker (Coastal-gun mini-boss foreshadow) — guide §2
    place(img, "bunker_1x1_bottom", 360, 1530, darken=0.95)
    place(img, "gun_medium_dual_green", 386, 1505)
    crater(img, 180, 1640, 26)
    crater(img, 470, 1900, 20)

    # -- treeline + jungle ----------------------------------------------------------
    treeline_rng = random.Random(7)
    for x in range(-10, WIDTH, 52):
        name = f"tree_0{treeline_rng.choice([1, 3, 4, 5, 6])}"
        y = TREELINE - 30 + treeline_rng.randint(-26, 26)
        place(img, name, x, y, scale=treeline_rng.uniform(0.85, 1.1),
              darken=treeline_rng.uniform(0.85, 1.0), flip=treeline_rng.random() < 0.5)
    # bushes drifting down onto the sand below the treeline
    for _ in range(10):
        x, y = treeline_rng.randint(0, 480), TREELINE + treeline_rng.randint(10, 150)
        place(img, treeline_rng.choice(["bush_1", "bush_big"]), x, y,
              scale=treeline_rng.uniform(0.5, 0.8), alpha=0.95)
    # jungle body: scattered canopies + grass tufts, denser than the treeline
    for _ in range(26):
        x, y = treeline_rng.randint(-20, 500), treeline_rng.randint(-20, TREELINE - 140)
        name = f"tree_0{treeline_rng.choice([1, 3, 4, 5, 6])}"
        place(img, name, x, y, scale=treeline_rng.uniform(0.9, 1.25),
              darken=treeline_rng.uniform(0.8, 0.95), flip=treeline_rng.random() < 0.5)
    for _ in range(12):
        x, y = treeline_rng.randint(0, 412), treeline_rng.randint(0, TREELINE - 160)
        place(img, treeline_rng.choice(["grass_01", "grass_02"]), x, y, alpha=0.85)

    return img


# ================================ STAGE 3 =====================================
def build_stage3() -> Image.Image:
    """The fortress shore: fortified surf -> bunker lines -> walled fortress parked."""
    H = 3400
    SHORE = 2860
    img = gradient_strip(H, [(0.0, (0.45, 0.46, 0.44)), (0.2, (0.62, 0.57, 0.46)),
                             (0.75, (0.7, 0.64, 0.5)), (1.0, (0.45, 0.58, 0.6))])
    water_texture(img, SHORE, H)
    grain(img, SHORE, H, amp=3, seed=31)
    tile_fill(img, "sand", 0, SHORE, alpha=0.92)  # let the grey gradient cool the top
    grain(img, 0, SHORE, amp=4, seed=32)

    # -- fortified surf ---------------------------------------------------------
    shoreline(img, SHORE, seed=3)
    foam_line(img, SHORE + GRID + 20, alpha=60)
    foam_line(img, SHORE + GRID + 62, amp=6, alpha=40)
    # debris of the first wave in the water
    place(img, "ship_small_body_destroyed", 320, SHORE + 190, rotate=38, darken=0.55, alpha=0.8)
    place(img, "ship_small_body_destroyed", 100, SHORE + 320, rotate=-115, darken=0.5, alpha=0.7)

    # -- beach obstacles --------------------------------------------------------
    tank_traps(img, SHORE - 60, 7, seed=41)
    tank_traps(img, SHORE - 150, 6, seed=42)
    for cx, cy, r in ((90, 2700, 30), (430, 2620, 24), (260, 2540, 34),
                      (150, 2380, 22), (480, 2300, 28)):
        crater(img, cx, cy, r)

    # -- first bunker line ------------------------------------------------------
    place(img, "bunker_1x1_bottom", 60, 2150, darken=0.92)
    place(img, "bunker_1x1_bottom", 390, 2110, darken=0.95)
    place(img, "gun_medium_dual_green", 86, 2125)
    place(img, "gun_medium_dual_green", 416, 2085)
    tracks(img, 270, SHORE - 20, 240, 2200)
    crater(img, 250, 2060, 26)
    crater(img, 330, 1900, 30)

    # -- second line: heavier ------------------------------------------------------
    place(img, "bunker_2x1_bottom", 190, 1700, darken=0.9)
    place(img, "gun_medium_dual_green", 230, 1672)
    place(img, "gun_medium_dual_green", 290, 1672)
    place(img, "bunker_1x1_bottom", 30, 1560, darken=0.88)
    place(img, "bunker_1x1_bottom", 440, 1530, darken=0.9)
    tank_traps(img, 1850, 6, seed=43)
    crater(img, 120, 1420, 24)
    crater(img, 420, 1380, 28)
    # sparse hard-bitten vegetation
    for x, y, s in ((20, 1980, 0.8), (490, 1760, 0.7), (60, 1300, 0.75), (460, 1180, 0.8)):
        place(img, "bush_1", int(x), int(y), scale=s, darken=0.8)

    # -- approach road to the fortress gate ----------------------------------------
    blend(img, lambda d: d.polygon([(240, 1500), (300, 1500), (320, 700), (220, 700)],
                                   fill=(118, 104, 80, 90)))
    tracks(img, 265, 1480, 268, 720)

    # -- THE FORTRESS (parked frame, top 960) — the mandatory pre-boss telegraph ----
    apron = (30, 120, WIDTH - 30, 780)

    def fortress_walls(d):
        # stone apron the compound sits on (opaque)
        d.rounded_rectangle(apron, radius=26, fill=(112, 108, 100, 255))
        # perimeter wall: thick, double-lined, unmistakable
        d.rounded_rectangle(apron, radius=26, outline=(58, 54, 48, 255), width=14)
        d.rounded_rectangle([apron[0] + 18, apron[1] + 18, apron[2] - 18, apron[3] - 18],
                            radius=18, outline=(150, 144, 132, 200), width=4)
        # gate: south wall break aligned with the approach road
        d.rectangle([232, apron[3] - 16, 308, apron[3] + 16], fill=(118, 104, 80, 255))
        d.rectangle([224, apron[3] - 18, 232, apron[3] + 10], fill=(40, 38, 34, 255))
        d.rectangle([308, apron[3] - 18, 316, apron[3] + 10], fill=(40, 38, 34, 255))
        # corner watch posts
        for cx, cy in ((70, 170), (430, 170)):
            d.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=(86, 82, 74, 255),
                      outline=(52, 48, 42, 255), width=5)
            d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(120, 114, 104, 255))
    blend(img, fortress_walls)
    grain(img, 140, 770, amp=6, seed=33)

    # the keep + flanking guns (same family the boss is built from)
    place(img, "bunkers_big", 172, 300)
    place(img, "gun_big_tripple", 88, 340, scale=1.6)
    place(img, "gun_big_tripple", 400, 340, scale=1.6)
    place(img, "bunker_1x1_bottom", 70, 560, darken=0.92)
    place(img, "bunker_1x1_bottom", 378, 560, darken=0.92)
    place(img, "gun_medium_dual_green", 96, 535)
    place(img, "gun_medium_dual_green", 404, 535)
    # scorched ground outside the walls; a couple of survivor palms
    crater(img, 110, 880, 26)
    crater(img, 440, 850, 30)
    place(img, "tree_04", 16, 820, scale=0.9, darken=0.8)
    place(img, "tree_05", 486, 800, scale=0.85, darken=0.78)
    # calm top edge: nothing within the top 120 px but the cool gradient

    return img


BUILDERS = {1: build_stage1, 2: build_stage2, 3: build_stage3}

if __name__ == "__main__":
    ids = [int(a) for a in sys.argv[1:] if a.isdigit()] or [1, 2, 3]
    for i in ids:
        strip = BUILDERS[i]()
        out = HERE / f"stage{i}_greybox_claude.png"
        strip.convert("RGB").save(out)
        print(f"wrote {out.name}  ({strip.width}x{strip.height})")
