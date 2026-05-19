## Parent

#1 — Tactical fixes: audio stacking, Stage 1 banner, stage indexing

## What to build

Show the "STAGE 1" banner when Level 1 is loaded, matching the existing behaviour for Stage 2 and Stage 3 transitions. Currently the `StageOverlay` only fires when a boss dies (advancing to the next stage) or at LEVEL CLEAR — so Stage 1 silently begins with no announcement.

End-to-end behaviour: when the player enters Level 1, the screen dims and "STAGE 1" fades in with the same timing as the existing Stage 2 / Stage 3 transitions. No enemies spawn while the banner is up. Once the banner fades out, gameplay begins normally.

Implementation shape:

- In `Level01.gd._ready`, after music starts and signals connect, call `stage_overlay.show_stage(stage_index + 1)` (uses 0-based internal indexing from slice C).
- Gate the spawner so it does not produce enemies during the banner. Options: hold the spawner's internal timer paused for the banner duration (~2.5 s, matching the existing overlay tween), or delay attaching the spawner to the scene until after the banner. Pick whichever is least invasive — investigate `EnemySpawner` to confirm.
- The await/delay must use the existing overlay tween's total duration as the source of truth so future overlay timing changes don't desync.

## Acceptance criteria

- [ ] Loading Level 1 immediately displays the "STAGE 1" banner with the same fade-in / hold / fade-out timing used for Stage 2 and Stage 3
- [ ] No enemies spawn while the Stage 1 banner is visible
- [ ] Music starts at level load (banner does not delay the music cue)
- [ ] Stage 2 and Stage 3 transitions still work exactly as before — no regression
- [ ] Manual verification: play through Level 1 from start to LEVEL CLEAR; banner appears for all three stages in sequence

## Blocked by

- #5 — Normalise Level 1 stage indexing to 0-based internally

## Notes

- Blocked by #5 because both touch `Level01.gd`'s stage-tracking field. Landing this first would force #5 to rework the banner call.
- If the simplest spawner-gating approach turns out to be intrusive, fall back to: temporarily disable `EnemySpawner._process` for the banner duration via `set_process(false)` / `set_process(true)`. Avoid restructuring the spawner for this slice.
