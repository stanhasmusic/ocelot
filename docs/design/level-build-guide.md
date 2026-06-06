# Level Build Guide — Backgrounds & Landmarks

> **Worked example: Level 1 — Pacific Beachhead.** This is the human-in-the-loop handbook for the
> biggest art commitment per level (ADR-0003): the hand-authored scrolling background and its
> landmarks. PRD-14 wires the level on **placeholder** strips so it's playable immediately; you swap
> in real art through the `.tres` with **no code changes**. The same recipe clones for Levels 2–4.

---

## 0. How the background actually works (read this first)

The runtime is `objects/ScrollingBackground.gd`. The mental model is dead simple:

- The screen is **540 × 960** (portrait).
- Each **stage** shows **one tall PNG strip** (`strip_texture`). It must be **540 px wide**; its
  **height is however long you want the journey to be.**
- On stage start the strip is positioned at the top and **scrolls upward** (the camera flies "north")
  at `scroll_speed` px/s, until the **bottom** of the strip reaches the bottom of the screen — then it
  **stops and parks.** It does **not** loop. The bottom 960 px of the strip is the "parked" backdrop
  the late procedural body and the pre-boss moment play over.
- When the **boss spawns**, the strip is hidden and the screen swaps to a **single static
  `boss_arena_texture`** (540 × 960). The boss fight happens over that arena image, **not** the strip.

What this means for you:

| Knob | Lives in | Controls |
|------|----------|----------|
| `strip_texture` (×3, one per stage) | `level_pacific.tres` → `stage_backgrounds[i]` | the scrolling journey art for that stage |
| `scroll_speed` (×3) | same | how fast the world flies past (px/s) |
| `boss_arena_texture` (×1) | `level_pacific.tres` (top level) | the static backdrop for the boss fight |

> ⚠️ **`parallax_layers` does nothing.** The field exists on `StageBackground` but the runtime never
> reads it. **Bake every landmark into the strip PNG itself** — that's the supported path (and the one
> we chose deliberately in the PRD).
>
> ✅ **The arena is reserved for the named boss** (PRD-14 decision: only the Coastal Fortress swaps to
> `boss_arena_texture`; the two **mini-bosses fight over the parked strip**, staying in the world). So
> **author the arena specifically as the Coastal Fortress backdrop** — it's the "we've arrived"
> set-piece frame, and it only ever shows for that one fight.

### Sizing the strip (the one bit of math)

The strip scrolls for `(height − 960) / scroll_speed` seconds, then parks. A stage intro is ~30–45 s
(CONTEXT: *Stage intro*), and you usually want to still be moving through most of it. So:

```
strip_height ≈ 960 + (seconds_of_motion × scroll_speed)
```

Example: 40 s of motion at `scroll_speed = 100` → `960 + 40×100 = 4960 px` tall. Round to ~5000.
Prefer a **slower scroll over a shorter strip** if you want a calmer onramp (L1 is the onramp — start
conservative, e.g. `scroll_speed = 70–90`).

---

## 1. How-to: building a strip, step by step

You're compositing **one flat PNG per stage** in an image editor (Photoshop / Krita / Aseprite /
GIMP), then dropping it into the `.tres`. "Placing tiles" = arranging the tile/decor sprites on the
canvas and exporting a single image — the engine just scrolls that image.

1. **New canvas, 540 px wide**, height from the formula above (e.g. 540 × 5000). Transparent or
   sea-colour base layer.
2. **Lay the terrain** bottom-to-top in the direction of travel. Remember the player flies *up* the
   strip, so the **bottom of the PNG is what they see first**, the **top is the end of the journey.**
   (For L1 that's: bottom = open ocean → top = the fortress shore.)
3. **Tile the water/beach** using the `ground_tilesest` pieces (see §2). The beach tiles are
   edge/corner/middle pieces meant to be assembled into a coastline — snap them on a grid.
4. **Place landmarks** (wrecks, bunkers, palms, craters) directly onto the canvas where you want them
   to scroll past. Put the **pre-boss landmark near the top of Stage 3's strip** (the Coastal Fortress
   on the horizon) so it slides into view as the boss threshold approaches — this is the ADR-0003
   "boss-coming" telegraph and it's mandatory.
5. **Export a single flat PNG.** Keep it lossless (PNG). Drop it in `assets/sprites/.../` (a
   `pacific_bg/` folder is fine).
6. **Wire it in** `resources/level_backgrounds/level_pacific.tres`: set
   `stage_backgrounds[i].strip_texture` to your PNG and `scroll_speed` to taste. Set the top-level
   `boss_arena_texture` to your 540 × 960 arena image. (I'll have created this `.tres` with placeholders
   already — you're swapping textures, not building the resource.)
7. **Run the level, feel it, adjust** `scroll_speed` and re-export the strip as needed. No code, no my
   involvement.

Import note: Godot auto-imports new PNGs (creates the `.import` sidecar) when the editor next has
focus. For these big backdrops, in the Import dock consider **Filter On** (smooth scaling) and
**Mipmaps Off**; leave compression default.

---

## 2. Asset recommendations & placement ideas (Pacific Beachhead)

All paths under `assets/sprites/`. These are the pieces that read as "1943 Pacific island assault."

### Terrain — the coastline
- **Beach tileset:** `ground_tilesest/images/beach_*` (and `beach2_*`) — corner/edge/middle pieces
  (`_bl`, `_bm_01..05`, `_br`, `_lm`, `_rm`, diagonals) plus `_grass` variants for where sand meets
  jungle. Assemble these into the shoreline.
- **Base sheets:** `ground_tilesest/ground.png` and `ground_tilesest/images/decor.png` are the atlases
  if you'd rather pull from the sheet.
- **Open water:** for the bottom (Stage 1) you mostly want **sea** — a tiling blue/teal water fill
  with a few ripples. The `shipz/` folder has `water_ripple_*` frames you can scatter as foam.

### Landmarks & decor
- **Beach clutter:** `ground_tilesest/images/decor/` — `barrels_*`, `crates_1..4`, `bush_*`,
  `grass_*`, `dirt_*`, `road_*`. Great for dressing the beachhead so it feels occupied.
- **Bunkers & coastal guns:** `buildings/bunkers/` — the same family the **Coastal Fortress** boss is
  built from (`bunkers_big`, `gun_big_tripple`, `gun_medium_dual_*`, round bunkers with
  `_top`/`_destroyed` variants). Sprinkle a few **intact bunkers as landmarks** on the beach in Stage
  2–3 so the fortress feels like the culmination of a fortified coast, not a surprise.
- **Wrecks:** the `shipz/` ship bodies (`ship_large_body`, `ship_medium_body`, `ship_small_body`)
  make excellent **beached/sunken wrecks** — desaturate/tilt one half-submerged in the surf for
  instant Pacific-assault mood.
- **Vegetation:** `trees/tree_01..10` for palms/scrub along the treeline at the top of the beach.
- **Houses/structures:** `buildings/houses/` for a ruined village inland if you want Stage 3 to push
  past the beach.

### Per-stage journey (matches the Q7 difficulty ramp)
- **Stage 1 — Open ocean → first sand.** Mostly sea; a wrecked ship or two; the **first sliver of
  beach appears near the top.** Calm, readable — this is the FTUE onramp; don't crowd it. (The Warship
  mini-boss fights here, on water.)
- **Stage 2 — The beachhead.** Full shoreline: sand, surf line, scattered bunkers, barrels/crates,
  the treeline. Busier. (The Coastal-gun mini-boss sits among the dunes — foreshadows the fortress.)
- **Stage 3 — The fortress shore.** Heavily fortified beach leading to the **Coastal Fortress on the
  horizon near the top of the strip** (the pre-boss telegraph). Then the boss arena takes over.

---

## 3. Tips

- **The background must never out-shout the gameplay.** Enemy fire is blue/orange/(purple) and the
  player shot is white/pale-gold (CONTEXT threat palette). Keep the strip **lower-contrast and
  cooler/muted** so bullets pop. Avoid bright orange/blue hotspots in the art that could read as
  projectiles. Beware busy high-frequency texture under the player's typical flight band (lower third).
- **Sand vs. orange-aimed fire.** Pacific sand trends warm/orange — exactly the *aimed-tier* hue.
  Push the sand toward pale/desaturated tan, not saturated orange, so orange tracers stay legible.
- **Pace landmarks, don't carpet them.** A landmark every few seconds gives a sense of speed and
  progress (ADR-0003's whole point). Empty stretches between them are good — they're where the
  procedural body breathes.
- **The pre-boss landmark is load-bearing.** It's the only "boss incoming" cue the noob audience gets
  before the bar appears. Make the fortress unmistakable and give it a few seconds on screen before
  the threshold trips. (If it parks off-screen because the strip is too tall, shorten the strip or
  raise `scroll_speed`.)
- **Bottom-of-strip is where you live.** Because scrolling parks on the bottom 960 px, the late body
  and the boss-approach happen over that region — make it a satisfying "we've arrived" frame, not a
  random tile seam.
- **Boss arena = the Coastal Fortress, full stop.** Only the named boss swaps to it (mini-bosses fight
  over the parked strip), so paint it as the **fortress set-piece backdrop** — the dramatic "we've
  arrived at the objective" frame. It's the payoff the pre-boss landmark was promising.
- **Match strip seams to scroll, not to stages.** Each stage is its own strip and resets to the top on
  stage start, so you don't need strips to tile into each other — but do make each strip's **top and
  bottom edges visually calm** so the reset/park isn't jarring.
- **Iterate cheap.** Greybox first: flat sea + a few coloured blocks for landmarks, get `scroll_speed`
  feeling right, *then* paint. The wiring won't change underneath you.
- **Keep PNGs reasonable.** A 540 × 5000 strip is fine; if you go huge (10k+), watch texture memory on
  mobile. Three ~5k strips + one arena is a comfortable budget.
