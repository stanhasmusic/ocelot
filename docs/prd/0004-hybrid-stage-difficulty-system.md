# PRD: Hybrid stage difficulty system (scripted intro + procedural body)

## Problem Statement

Today's enemy spawning is a single random pull from a fixed pool, with only two real knobs per stage: boss HP and the score threshold that triggers the boss. Three concrete consequences:

1. **No onramp.** A non-gamer playtester found Level 1 too hard to learn because the moment they entered combat, the spawner had no notion of "go gentle first." Every stage starts cold, full intensity from second one.
2. **No real per-stage progression.** Stage 1, 2 and 3 of the same level are mechanically identical except for boss HP. The player feels they're surviving longer, not climbing.
3. **No teachable surface.** Adding a new enemy means dropping it into the random pool with no opportunity to introduce it in isolation. The player meets it mid-chaos.

The (B) side of the foundation goal — more enemy and boss variety — multiplies all three problems. Each new enemy needs a place to be *taught* and a place to be *escalated*.

## Solution

Adopt the hybrid difficulty model defined in ADR 0002. Each stage is structured as:

- A **stage intro** (~30–45 s) — a hand-authored timeline of spawns that introduces the stage's new enemy or pattern in isolation. On Level 1 Stage 1, the intro doubles as the game's tutorial: blue-tier-only, low density, gentle pacing.
- A **procedural body** — drawn from a weighted spawn table, governed by per-stage knobs (spawn interval, enemy weights, concurrency cap, projectile speed multiplier, minimum gap between aimed shots). The procedural body runs until the boss-score threshold is reached, at which point the existing boss spawn flow takes over unchanged.

Both halves are configured by a `StageConfig` resource saved per stage. Level scripts no longer hardcode spawn behaviour; they hand stage configs to the spawner.

Concretely this PRD builds the system (config resources, intro player, spawn director, spawner orchestrator changes) and applies it to **Level 1's three stages** with a hand-authored Stage 1 intro that is also the tutorial. Levels 2 and 3 receive default `StageConfig`s that approximate today's behaviour so nothing regresses; hand-authored intros for those stages are follow-up PRDs.

## User Stories

1. As a new player, I want the first 30 seconds of Level 1 to be gentle and clearly teach me how to play, so that I'm not killed before I understand the controls or the goal.
2. As a new player, I want each stage to begin by introducing one new enemy or pattern in isolation, so that I can learn it before it's mixed into chaos.
3. As a player, I want each stage of a level to feel mechanically different from the last, not just harder, so that progression is something I read in the gameplay and not just in the score.
4. As a player on Level 1 Stage 1, I want the only threats to be predictable straight-line shots, so that I can practice dodging without being punished for not moving.
5. As a player on later stages, I want the enemy mix and projectile speed to escalate clearly, so that "I'm getting closer to the boss" is something I feel.
6. As a developer, I want to author a stage by editing a single resource file (a `StageConfig`), so that adding or tuning a stage doesn't require touching code.
7. As a developer, I want the scripted intro authored as a list of `{time, scene, position}` events, so that I can build a stage's opening like a music sequencer rather than scripting it imperatively.
8. As a developer adding a new enemy, I want a designated stage intro to teach that enemy in isolation, so that the player meets it cleanly the first time.
9. As a developer, I want per-stage knobs for `enemy_weights`, `spawn_interval`, `max_concurrent_enemies`, `projectile_speed_mult` and `min_gap_between_aimed_shots`, so that I can shape difficulty along multiple axes without writing per-stage code.
10. As a developer, I want the procedural body's "minimum gap between aimed shots" knob, so that early stages can be tuned to never punish the new-player instinct of standing still.
11. As a developer, I want the boss spawn flow to remain unchanged so that the existing boss content keeps working, just receiving its trigger from the new system.
12. As a developer maintaining the project, I want intro player and spawn director to be testable in isolation as deep modules, so that when a test framework lands they can be covered without scene-tree gymnastics.
13. As a developer, I want today's behaviour preserved as the default on Levels 2 and 3, so that this PRD doesn't regress existing levels while the system is built out.
14. As a designer (future), I want the intro timeline format to support specifying spawn position by column index or by absolute coordinate, so that I can author intros that respect mobile-screen layout without recomputing pixel positions per level.
15. As a developer reviewing a PR, I want stage authoring to be inspectable from the resource file alone, so that "did this stage land its tuning" is a `.tres` diff rather than a code review.

## Implementation Decisions

### New resource types

**`StageConfig`** — a `Resource` subclass declaring everything a single stage needs:

- `intro_timeline: StageIntroTimeline` — may be `null` for stages with no scripted opening (procedural starts immediately)
- `enemy_weights: Dictionary` — keys are `PackedScene`, values are floats (weights for weighted random selection); empty dictionary means "do not spawn anything procedurally"
- `spawn_interval_start: float` — seconds between procedural spawns at stage-start
- `spawn_interval_end: float` — seconds between procedural spawns at boss-threshold (linear interpolation between start and end based on stage progress)
- `max_concurrent_enemies: int` — hard cap on living enemies before further spawns are deferred
- `min_gap_between_aimed_shots: float` — minimum seconds between two aimed-tier projectile fires across all enemies in this stage; zero means no gating
- `projectile_speed_mult: float` — multiplier applied to enemy projectile speeds for this stage (default 1.0)
- `boss_scene: PackedScene` — the stage's boss (replaces the spawner's `boss_scenes` array element)
- `boss_hp: int` — the stage boss's HP (replaces `stage_boss_hp` array element)
- `boss_score_threshold: int` — score within this stage at which the boss spawns

**`StageIntroTimeline`** — a `Resource` subclass holding an `Array[StageIntroEvent]`. Events are sorted by `time` ascending. The resource is pure data — it has no methods beyond standard resource serialization.

**`StageIntroEvent`** — a `Resource` subclass with three fields:

- `time: float` — seconds from intro start at which to spawn
- `scene: PackedScene` — what to instantiate
- `spawn_position: Vector2` — where to spawn it (absolute viewport coordinates; column-index convenience is left for a follow-up if hand-authoring proves painful)

### New nodes

**`StageIntroPlayer`** — consumes a `StageIntroTimeline` and an external "stage root" node into which spawns are added. Public surface:

- `play(timeline: StageIntroTimeline, stage_root: Node) -> void` — starts the intro
- `signal intro_finished` — emitted when the last event has fired and `tail_pad_seconds` (a small constant, ~0.5 s) has elapsed, signaling the procedural body to begin
- internal clock advances via `_process(delta)`; pausing the scene tree pauses the intro
- `cancel() -> void` — stops the intro early (used if level is exited mid-intro)

This module is deep: a single `play` call, a single signal, all timing logic encapsulated. Testable by injecting a fake clock and observing emitted spawn calls (when tests exist).

**`SpawnDirector`** — runs the procedural body given a `StageConfig` and a stage-root parent. Public surface:

- `start(config: StageConfig, stage_root: Node) -> void`
- `stop() -> void`
- `signal boss_threshold_reached` — emitted when the in-stage score crosses `config.boss_score_threshold`; spawner handles the actual boss spawn so the director stays decoupled from boss logic

Internally: a timer whose interval lerps between `spawn_interval_start` and `spawn_interval_end` based on stage progress; weighted random over `enemy_weights`; a check against `max_concurrent_enemies` (counts members of group `Enemies`) that defers (does not drop) a spawn when at cap; a global timestamp of the last aimed-tier shot used to gate aimed-tier enemies via `min_gap_between_aimed_shots`. The director needs to know an enemy's tier — for this PRD, infer from scene path or group membership (cheap heuristic); if it gets fragile, we add a `tier` annotation in a follow-up.

This module is deep: one `start` call, one signal out, all spawn-selection policy encapsulated.

### Refactor of existing modules

**`EnemySpawner`** becomes a thin orchestrator. Per stage it: (1) loads the `StageConfig` for the current stage index, (2) plays the `StageIntroPlayer` with the config's timeline if non-null, (3) on `intro_finished` (or immediately if no timeline) starts the `SpawnDirector`, (4) on `boss_threshold_reached` stops the director and spawns `config.boss_scene` with `config.boss_hp`. The existing `boss_scenes` array, `stage_boss_hp` array, `stage_start_intervals` array and `boss_score_threshold` field are removed — all per-stage data moves into the per-stage `StageConfig`.

**`Level01.gd`** holds an `Array[StageConfig]` (one entry per stage) exported in the Inspector. On stage transition it hands `stages[stage_index]` to the spawner. The 0-indexed convention from issue #5 is the source of truth.

### Level 1 stage configs authored by this PRD

- **Stage 1** — tutorial intro: a sequence of single grunts (`Truck` or `Ship` in straight-down trajectories) at increasing rates over ~40 s, no aimed-tier enemies, no power-up bait, ending with a small cluster the player can comfortably clear. Procedural body: blue-tier enemies only (`Truck`, `Ship` configured for non-aimed shots), `max_concurrent_enemies = 3`, `spawn_interval_start = 2.0`, `spawn_interval_end = 1.4`, `min_gap_between_aimed_shots = 0` (irrelevant since no aimed enemies), `projectile_speed_mult = 0.85`. Boss: the existing Stage 1 boss with current HP.
- **Stage 2** — short intro that introduces `Tank` (aimed-tier, orange) in isolation: three Tanks spawned in sequence over ~25 s. Procedural body: mixed grunts plus Tanks, `max_concurrent_enemies = 5`, `spawn_interval` 1.6 → 1.0, `min_gap_between_aimed_shots = 1.0` (no two aimed shots can leave a barrel within 1 s of each other across the whole stage — keeps it readable), `projectile_speed_mult = 1.0`. Boss: existing Stage 2 boss + HP.
- **Stage 3** — short intro that introduces a pattern-tier enemy (currently `Bomber`'s spread or `RocketLauncher`'s homing — implementer picks whichever fits the existing scene roster). Procedural body: full mix, `max_concurrent_enemies = 7`, `spawn_interval` 1.2 → 0.7, `min_gap_between_aimed_shots = 0.5`, `projectile_speed_mult = 1.15`. Boss: `BossL3` (the fan-attack boss) + existing HP.

Numbers are starting points; expect a tuning pass after first play-through.

### Levels 2 and 3 — non-regressing defaults

A default `StageConfig` per stage that approximates today's behaviour: today's enemy pool as `enemy_weights` (equal weights), today's `stage_start_intervals` values mapped onto `spawn_interval_start`, `spawn_interval_end = spawn_interval_start * 0.7`, `max_concurrent_enemies = 6`, `min_gap_between_aimed_shots = 0`, `projectile_speed_mult = 1.0`, `intro_timeline = null`. Existing bosses and HP go into the corresponding fields. Result: Levels 2 and 3 play indistinguishably from today; they're now driven through the new system, ready for per-stage tuning in follow-up PRDs.

## Testing Decisions

- **No automated tests in this PRD.** Issue #2 is open — the project has no test framework. The deep modules (`StageIntroPlayer`, `SpawnDirector`) are built with testable interfaces precisely so they become low-friction to cover when a framework lands.
- **What a good test would look like** when #2 resolves:
  - `StageIntroPlayer`: build a timeline with three events at t=0, 1, 2 seconds; drive the player's clock manually; assert the spawns appear in the stage root at the expected times and `intro_finished` fires after the last event plus the tail pad.
  - `SpawnDirector`: build a `StageConfig` with a known weight dictionary; run with a deterministic RNG seed; assert spawn-class distribution converges to weights over N spawns; assert no more than `max_concurrent_enemies` are added when the group is artificially full; assert `min_gap_between_aimed_shots` is honoured.
  - Both tests pass without rendering, without scenes loading enemies' textures — only requires Godot's resource and scene-tree subsystem.
- **Manual verification checklist** for the implementing agent:
  - Level 1 Stage 1 opens with the tutorial intro (no enemies fire at the player for the first ~30 s); player can survive without prior knowledge.
  - Stage 1 → boss → Stage 2 intro → Stage 2 boss → Stage 3 intro → Stage 3 boss → LEVEL CLEAR proceeds without errors.
  - Levels 2 and 3 play recognisably the same as before (no enemy missing, no obvious tempo change).
  - The Stage 1 banner from issue #6 still appears (banner is independent of the intro system; intro begins after the banner finishes).
- No prior-art tests exist in the codebase to copy from.

## Out of Scope

- Hand-authored stage intros for Levels 2 and 3 (default `StageConfig`s only — intros are follow-up PRDs).
- `LevelBase.tscn` scene inheritance refactor — separate PRD; the orchestration this PRD adds will move into `LevelBase` later, but for now lives on `Level01.gd`.
- Spawn patterns (waves, columns, geometric formations) in the procedural body — out of scope; today's "random from pool" feel is preserved, just with knobs.
- A column-index convenience for `StageIntroEvent.spawn_position` — defer until hand-authoring an intro proves the absolute-coordinate format painful.
- A `tier` annotation on projectile or enemy scripts to feed `SpawnDirector.min_gap_between_aimed_shots` — for this PRD, infer tier from scene path or group membership; promote to an explicit annotation if the heuristic gets fragile.
- Difficulty selection (Easy/Normal/Hard) at the level-select level — `StageConfig` is the substrate that would make this trivial later, but no UI in this PRD.
- Power-up drop rate tuning per stage — currently hardcoded in `Enemy.gd`; a knob on `StageConfig` is a natural future addition but out of scope here.
- Audio cues tied to intro phases (e.g. "tutorial music" vs "combat music") — separate audio-design PRD.

## Further Notes

- Anchored in [ADR 0002](../adr/0002-hybrid-stage-difficulty.md).
- Glossary terms used (from `CONTEXT.md`): **level**, **stage**, **stage intro**, **procedural body**, **encounter**, **threat tier**, **aimed tier**.
- Anchored to audience constraint: [project memory — target audience](../../.claude/memory/project_ocelot_target_audience.md). Level 1 Stage 1 tuning numbers exist to land for a non-gamer.
- Depends on issue #5 (stage indexing normalisation) being merged first; the new orchestration uses 0-indexed `stage_index` throughout. If #5 is not yet merged when this PRD's work begins, the implementer should rebase after #5 lands rather than reintroducing the 1-vs-0 mismatch.
- Implementation order suggested for the agent: (1) author `StageIntroEvent`, `StageIntroTimeline`, `StageConfig` resources; (2) author `StageIntroPlayer` standalone with a manual test scene; (3) author `SpawnDirector` standalone; (4) refactor `EnemySpawner` to orchestrate the new pieces; (5) author Level 1 stage configs and intro timelines; (6) author non-regressing defaults for Levels 2 and 3; (7) playtest end-to-end. Each step is verifiable before the next.
