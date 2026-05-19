## Parent

#8 — Hybrid stage difficulty system (scripted intro + procedural body)

## What to build

Add the scripted-intro layer on top of the config-driven spawner from slice #9. Build the timeline resources and the player node, integrate the player into the spawner's stage handoff, and prove it end-to-end with a token two-event timeline on Level 1 Stage 1.

End-to-end behaviour: when a stage's `StageConfig.intro_timeline` is non-null, the spawner plays the intro before starting the procedural body. The intro deterministically spawns the timeline's events at their declared times. When the intro ends (last event + a small tail pad), the procedural body begins as normal. When `intro_timeline` is null, the spawner behaves exactly as in slice #9.

Concretely this slice delivers:

- A new `StageIntroEvent` `Resource` type with `time: float`, `scene: PackedScene`, `spawn_position: Vector2`.
- A new `StageIntroTimeline` `Resource` type holding `Array[StageIntroEvent]`. The resource is pure data; no methods beyond standard serialization.
- A new `StageIntroPlayer` node with the public surface from PRD #8: `play(timeline, stage_root)`, `cancel()`, `signal intro_finished`. Clock advances via `_process(delta)`; pause-aware (uses scene-tree pause); tail pad of ~0.5 s after the last event.
- `EnemySpawner` updated: on stage start, if the current `StageConfig.intro_timeline` is non-null, instantiate (or reuse) a `StageIntroPlayer`, call `play`, await `intro_finished`, then start the `SpawnDirector`. If null, start `SpawnDirector` immediately (slice #9 behaviour).
- A token `StageIntroTimeline` `.tres` authored for Level 1 Stage 1: exactly two events (e.g. spawn a `Truck` at t=2.0 in the centre column, spawn another `Truck` at t=4.0). Wired into `Level01.gd`'s stage 0 `StageConfig`. This is *demo content only* — real tutorial content lands in slice C.

## Acceptance criteria

- [ ] `StageIntroEvent` resource type exists with `time`, `scene`, `spawn_position` fields
- [ ] `StageIntroTimeline` resource type exists holding `Array[StageIntroEvent]`
- [ ] `StageIntroPlayer` node exists with `play`, `cancel`, `intro_finished` as the only public surface
- [ ] `StageIntroPlayer` pauses when the scene tree pauses (existing PauseMenu must still work mid-intro)
- [ ] `EnemySpawner` plays the intro before procedural body when `intro_timeline` is non-null, and skips straight to procedural body when null
- [ ] Level 1 Stage 1's `StageConfig` references a `StageIntroTimeline` with two events; playing Level 1 from start produces those two scripted spawns at the right times before procedural spawning begins
- [ ] Levels 2 and 3 (whose `intro_timeline` remains null) play identically to slice #9 — no regression
- [ ] Stage 1 banner from #6 still fires before the intro begins (banner → intro → procedural body)

## Blocked by

- #9 — Config-driven spawner: StageConfig + SpawnDirector (behaviour preserved)

## Notes

- The token L1S1 intro is not tutorial-shaped; it exists only to demonstrate the system works end-to-end. The real noob-friendly intro lands in slice C and replaces this token.
- `StageIntroPlayer` is designed as a deep module so that when a test framework lands (issue #2) it can be driven with a fake clock and have its emitted spawns observed without rendering. Do not let the integration into `EnemySpawner` leak timing concerns back into the player.
