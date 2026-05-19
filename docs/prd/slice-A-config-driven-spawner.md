## Parent

#8 — Hybrid stage difficulty system (scripted intro + procedural body)

## What to build

Replace `EnemySpawner`'s hardcoded per-stage data with a config-driven path that produces *exactly today's gameplay* on every level. This is the tracer bullet for the new system: every layer (resource → director → spawner refactor → level wiring) is touched end-to-end, but the visible behaviour does not change. No scripted intros and no tuning changes land here — only the substrate.

End-to-end behaviour: a player loads any level, plays through all three stages, fights the existing bosses, sees LEVEL CLEAR. Everything feels identical to before. Internally, every spawn flowed through `SpawnDirector` reading a `StageConfig`.

Concretely this slice delivers:

- A new `StageConfig` `Resource` type with the fields specified in the PRD (`enemy_weights`, `spawn_interval_start`, `spawn_interval_end`, `max_concurrent_enemies`, `min_gap_between_aimed_shots`, `projectile_speed_mult`, `boss_scene`, `boss_hp`, `boss_score_threshold`; `intro_timeline` field exists and is always `null` in this slice).
- A new `SpawnDirector` node with the public surface from the PRD (`start(config, stage_root)`, `stop()`, `signal boss_threshold_reached`). It implements weighted random selection, the concurrent-enemy cap (deferring rather than dropping), and the aimed-shot gating (tier inference from scene path or group membership; promote to explicit annotation only if the heuristic proves fragile).
- `EnemySpawner` refactored to be the thin orchestrator from the PRD: per stage it reads the current `StageConfig`, runs `SpawnDirector`, and on `boss_threshold_reached` spawns the config's boss with the config's HP. The old `boss_scenes`, `stage_boss_hp`, `stage_start_intervals` and `boss_score_threshold` exports are removed.
- Nine default `StageConfig` `.tres` files authored: three per level for Levels 1, 2 and 3, with values chosen to reproduce today's behaviour (today's enemy pool as equal `enemy_weights`, today's `stage_start_intervals` as `spawn_interval_start`, `spawn_interval_end = spawn_interval_start * 0.7`, `max_concurrent_enemies = 6`, `min_gap_between_aimed_shots = 0`, `projectile_speed_mult = 1.0`, existing bosses and HP in the boss fields).
- `Level01.gd` (and equivalent for Levels 2, 3 — author inline scripts as needed since only Level01.gd exists today) holds an `Array[StageConfig]` exported in the Inspector and hands `stages[stage_index]` to the spawner on each stage transition.

## Acceptance criteria

- [ ] `StageConfig` resource type exists with all fields from the PRD; `intro_timeline` field present but always `null` in this slice
- [ ] `SpawnDirector` node exists with `start`, `stop`, and `boss_threshold_reached` signal as the only public surface
- [ ] `SpawnDirector` honours `max_concurrent_enemies` by deferring (not dropping) spawns
- [ ] `SpawnDirector` honours `min_gap_between_aimed_shots` across all enemies in the stage
- [ ] `EnemySpawner` has no per-stage data of its own; all per-stage data lives in `StageConfig`
- [ ] Each of Level 1, 2 and 3 has three `StageConfig` `.tres` files wired into its level script
- [ ] Playing each level produces gameplay indistinguishable from the previous behaviour (enemy mix, spawn cadence, boss timing, HP)
- [ ] Boss spawn flow is unchanged — same bosses, same HP, same score-triggered handoff

## Blocked by

- #5 — Normalise Level 1 stage indexing to 0-based internally

## Notes

- Tier inference for `min_gap_between_aimed_shots` can use scene-path matching (e.g. anything whose script extends `TurretBullet` or whose scene name contains "Tank"/"Ship") or group membership. If this heuristic gets fragile while authoring, add an explicit `tier` annotation on the projectile script — note that we deferred this in PRD #8 but the door is open.
- Default `StageConfig`s are *non-regressing approximations*, not "the right tuning." Slice C handles the actual Level 1 tuning. Levels 2 and 3 keep their default `.tres` configs until their own tuning PRDs land.
- This slice does not touch `StageOverlay` or the stage-banner flow — issues #5 and #6 own that surface.
