# pacific_bg — Level 1 background authoring

Working files for hand-authoring the Pacific Beachhead scrolling strips.
Pairs with `docs/design/level-build-guide.md` (read that first).

## Files

| File | What it is |
|------|------------|
| `stage{1,2,3}_greybox.png` | Runnable hand-painted strips. **Wired into Stage 0 / 1 / 2** of `resources/level_backgrounds/level_pacific.tres`. Paint over them / replace them. |
| `stage{1,2,3}_seabase.png` | The plain gradient strip for each stage — same colours as the template, **no grid/text/annotations**. A clean base layer to paint over. |
| `boss_arena_seabase.png` | The plain **540×960** gradient base for the boss arena (Coastal Fortress backdrop) — same colours as `boss_arena_texture` in the `.tres`. A static frame, **not** a scrolling strip: it swaps in when the named boss spawns. Paint the fortress over this. |
| `stage{1,2,3}_template_REFERENCE.png` | Each stage's canvas with annotations baked in: 128px grid, the parked-960 line (top), start/end zone labels, travel direction, per-stage notes + landmark hints. **Reference only — never ships.** Sizes/speeds mirror `level_pacific.tres` (St1 540×3200 @75, St2 540×3200 @85, St3 540×3400 @95). |
| `make_reference_template.py` | Pillow generator for the `*_template_REFERENCE.png` **and** `*_seabase.png` (same gradient stops, mirrored from the `.tres`). Re-run after changing a stage's size/scroll/gradient. `python make_reference_template.py` rebuilds St2+St3 templates; add `seabase` for the plain strips; pass `1 2 3` to pick stages; add `arena` to (re)build `boss_arena_seabase.png`. |
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
- All three stages now scroll hand-painted greybox strips. To revise one, paint over its
  annotated reference template, export to the matching `stage*_greybox.png`, and the `.tres`
  picks it up (no repoint needed unless you change the filename). Stage 3's strip carries the
  **Coastal Fortress on the horizon near the top** (the mandatory pre-boss telegraph).

> Note: the curated `tiles/` are convenience copies for authoring; the runtime atlases under
> `ground_tilesest/`, `shipz/`, `buildings/` remain the source of truth for in-game sprites.
