## Parent

#1 — Tactical fixes: audio stacking, Stage 1 banner, stage indexing

## What to build

Normalise stage indexing in `Level01.gd` to 0-based, matching the convention already used by `EnemySpawner`. Stage numbers shown to the player remain 1-based; the conversion happens **only** at the display boundary (the `StageOverlay.show_stage` call site).

End-to-end behaviour: gameplay is unchanged — Stage 1 → boss → Stage 2 → boss → Stage 3 → boss → LEVEL CLEAR still happens in the same order. The fix is internal hygiene that removes a latent off-by-one bug.

Concretely:

- Rename `current_stage` → `stage_index` to make the index nature explicit.
- Initialise it to `0` (not `1`).
- Remove the `- 1` adjustment at the `enemy_spawner.reset_for_stage(...)` call — it now receives `stage_index` directly.
- The `show_stage` call receives `stage_index + 1` so the displayed banner is still "STAGE 1", "STAGE 2", "STAGE 3".
- `TOTAL_STAGES` stays as-is (it's a count, not an index); the comparison becomes `if stage_index + 1 < TOTAL_STAGES` (i.e. still more stages to come).

## Acceptance criteria

- [ ] `Level01.gd` uses a single 0-based `stage_index` variable; no field is 1-based
- [ ] `enemy_spawner.reset_for_stage(stage_index)` is called without any `- 1` adjustment
- [ ] `StageOverlay.show_stage(stage_index + 1)` is the only place that translates to 1-based for display
- [ ] Manual verification: play Level 1; banner shows STAGE 1 / 2 / 3 in order; correct boss spawns for each stage; LEVEL CLEAR fires after Stage 3 boss dies

## Blocked by

None — can start immediately.

## Notes

- This slice deliberately ships before slice D (Stage 1 banner) so that D inherits the normalised convention. Slice D is blocked by this one.
- No changes to `EnemySpawner` — its existing 0-based contract is the convention being adopted.
