## Parent

#8 — Hybrid stage difficulty system (scripted intro + procedural body)

## What to build

Replace Level 1's default `StageConfig`s (from slice #9) and its token intro timeline (from slice #10) with real, tuned content shaped for a non-gamer's first play. This is the design-validation slice — the moment the foundation actually delivers the audience promise.

End-to-end behaviour: a non-gamer who has never played the game can complete Level 1 Stage 1 with minimal coaching. They survive the opening because no aimed-tier enemies appear; they learn the controls because the intro paces enemies one at a time before mixing them; they feel a clear escalation from Stage 1 → 2 → 3 because the knobs and intros are tuned to telegraph it.

Concretely this slice delivers tuned content for all three Level 1 stages, per the tuning numbers in PRD #8:

- **L1S1 `StageConfig`**: blue-tier enemies only (today's `Truck` and `Ship`, configured for non-aimed straight-down shots); `max_concurrent_enemies = 3`; `spawn_interval_start = 2.0`, `spawn_interval_end = 1.4`; `min_gap_between_aimed_shots = 0`; `projectile_speed_mult = 0.85`; boss = existing Stage 1 boss with current HP.
- **L1S1 `StageIntroTimeline`** (replaces the token timeline from #10): hand-authored tutorial sequence ~40 seconds long. Single grunts at increasing rate, no aimed-tier enemies, ending with a small cluster the player can comfortably clear. The opening few seconds spawn nothing — the player has a quiet beat to read the screen and the HUD before threats appear.
- **L1S2 `StageConfig`**: mixed grunts plus `Tank` (aimed-tier); `max_concurrent_enemies = 5`; `spawn_interval` 1.6 → 1.0; `min_gap_between_aimed_shots = 1.0`; `projectile_speed_mult = 1.0`; boss = existing Stage 2 boss + HP.
- **L1S2 `StageIntroTimeline`**: ~25 second intro introducing `Tank` in isolation — three Tanks spawned in sequence, no grunts mixed in, so the player learns aimed-tier dodging cleanly before the body mixes everything.
- **L1S3 `StageConfig`**: full mix; `max_concurrent_enemies = 7`; `spawn_interval` 1.2 → 0.7; `min_gap_between_aimed_shots = 0.5`; `projectile_speed_mult = 1.15`; boss = `BossL3` (the fan-attack boss) + existing HP.
- **L1S3 `StageIntroTimeline`**: ~25 second intro introducing a pattern-tier enemy (`Bomber` or `RocketLauncher` — implementer picks whichever fits the existing scene roster) in isolation before the body begins.

Numbers from the PRD are starting points; expect a tuning pass after first play-through. The HITL gate exists to validate them by play.

## Acceptance criteria

- [ ] L1S1 `StageConfig` matches the numbers above and references its tutorial intro timeline
- [ ] L1S1 intro timeline is hand-authored (not procedurally generated), runs ~40 s, contains zero aimed-tier spawns
- [ ] L1S2 `StageConfig` matches the numbers above and references its Tank-introduction intro
- [ ] L1S2 intro spawns Tanks in sequence with no grunts mixed in
- [ ] L1S3 `StageConfig` matches the numbers above and references its pattern-tier introduction intro
- [ ] L1S3 intro introduces exactly one pattern-tier enemy type in isolation
- [ ] Levels 2 and 3 are not modified — they retain the default configs from #9
- [ ] HITL merge gate: Stan plays Level 1 end-to-end and confirms (1) the opening 30 seconds is survivable cold, (2) the Stage 1 → 2 → 3 escalation is felt, (3) ideally a non-gamer (the original playtester or another) plays Stage 1 and reaches the boss

## Blocked by

- #10 — Stage intro timeline system (StageIntroTimeline + StageIntroPlayer)

## Notes

- HITL is on the *merge*, not the implementation. The agent can author all six resource files (three configs, three intros) end-to-end; merging requires Stan's play-validation, ideally with a non-gamer in the room.
- If a tuning number is clearly wrong on first play (e.g. L1S1 still too hard), prefer adjusting the `StageConfig` and re-validating over expanding scope into a deeper rework — the foundation is shipping in #9/#10, and tuning iterates fast on `.tres` files.
- Today's `Truck` and `Ship` enemies need to be configured for non-aimed shots in L1S1 — if their current behaviour is already aimed (via `TurretBullet`), this slice either swaps them for a straight-shot variant or constrains their `enemy_weights` to exclude the aimed variants. Implementer chooses; document the choice in the PR description.
- This slice doesn't touch Levels 2 or 3 tuning. Those are separate follow-up PRDs the day you sit down to author each level's intros.
- Per [project memory — target audience](../../.claude/memory/project_ocelot_target_audience.md), the L1S1 validation against a non-gamer is the calibration anchor for "Ocelot's difficulty is right." Treat this slice as the proof.
