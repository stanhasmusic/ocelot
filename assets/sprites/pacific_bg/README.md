# pacific_bg — Level 1 background authoring

Working files for hand-authoring the Pacific Beachhead scrolling strips.
Pairs with `docs/design/level-build-guide.md` (read that first).

## Files

| File | What it is |
|------|------------|
| `stage1_greybox.png` | 540×3200 runnable placeholder (sea + 2 wreck blocks + sand sliver at top). **Currently wired into Stage 0** of `resources/level_backgrounds/level_pacific.tres`. Paint over it / replace it. |
| `stage1_template_REFERENCE.png` | Same canvas with annotations baked in: 128px grid, the parked-960 line (top), start/end zone labels, travel direction. **Reference only — never ships.** |
| `tiles/` | Curated, ready-to-drag tile set pulled from the atlases (base / coastline / decor / wrecks / structures / trees). All 128px unless noted. |

## Photopea workflow

1. Open `stage1_template_REFERENCE.png` → it becomes your **bottom reference layer**. Lock it.
2. New layer group above it; build the strip there (drag tiles from `tiles/`, define water/sand as
   Patterns and fill, hand-place only coastline edges + landmarks).
3. `View → Show → Grid` (128px, set in `Edit → Preferences → Guides & Grid`), `View → Snap → Grid`.
4. **Hide/delete the reference layer**, then `File → Export As → PNG` over `stage1_greybox.png`
   (or a new name + repoint the `.tres`).
5. Keep your layered `.psd`/Photopea source somewhere outside the runtime path as the editable master.

## Canvas math (this level)

- Strip is **540 wide**, height = `960 + seconds_of_motion × scroll_speed`.
- Stage 0 here is **3200 tall @ 75 px/s** → ~30 s of motion, then it **parks on the top 960px**.
- **Bottom of the image = seen first** (open ocean). **Top = end of journey / parked frame** (first sand).
- World content scrolls **downward** on screen as the player flies north up the strip.
- Stages 1 & 2 are still gradient placeholders. Clone this recipe: make `stage2_*.png` / `stage3_*.png`,
  drop them in, and repoint `stage_backgrounds[1]` / `[2]` in `level_pacific.tres` (same one-line swap
  that was done for Stage 0). Stage 3's strip needs the **Coastal Fortress on the horizon near the top**
  (the mandatory pre-boss telegraph).

> Note: the curated `tiles/` are convenience copies for authoring; the runtime atlases under
> `ground_tilesest/`, `shipz/`, `buildings/` remain the source of truth for in-game sprites.
