# PRD-04 — Stage engine hardening

> **Published as [issue #29](https://github.com/stanhasmusic/ocelot/issues/29)** (`ready-for-agent`) — the tracker is canonical.
> Phase 2 slice. Implements [[0002-hybrid-stage-difficulty]] — except **the engine already exists**.
> This PRD is the *hardening* pass: pay back the test debt named in
> [[0004-defer-test-framework-until-first-testable-module]], remove the fragile aimed-shot
> classifier, and surface the tuning knobs that today are implicit.
>
> **Grounding note:** the hybrid scripted-intro + procedural-body spawner from ADR-0002 is built and
> running: `objects/SpawnDirector.gd` (weighted random pick, concurrency cap, score-driven spawn-rate
> ramp, aimed-shot gap, boss threshold), `scripts/StageConfig.gd` (the `.tres` knob set),
> `objects/StageIntroPlayer.gd` (clock-driven intro timeline), `scripts/StageIntroTimeline.gd` +
> `StageIntroEvent.gd` (the authored events), `objects/EnemySpawner.gd` (intro→body→boss wiring), and
> `scripts/LevelBase.gd` (stage→stage flow + level-clear). **It works.** What it lacks is the test
> coverage ADR-0004 explicitly promised when this code landed, and it carries one fragile shortcut.

## Problem Statement

As the developer, the stage engine is the spine of every level, but it has **zero automated tests** —
the exact situation ADR-0004 said we'd fix the moment `SpawnDirector`/`StageConfig` landed, and we
didn't. So every time I tune a spawn table or touch the director, I'm trusting a 60-second
playthrough to catch regressions in weighted selection, the concurrency cap, the aimed-shot gap, and
the boss-threshold trigger — logic that's deterministic and *should* be asserted, not eyeballed.
Worse, the director decides whether a shot is "aimed" by **string-matching the enemy's filename**
(`"Tank"`/`"Ship"` in the scene path), which silently breaks the moment an aimed enemy isn't named
`Tank` or `Ship` — and PRD-05 is about to add exactly those.

## Solution

Stand up tests for the stage engine's pure decision logic so spawn-table and director changes are
caught automatically, and replace the filename-based aimed-shot classifier with the explicit
**threat-tier** data PRD-02 puts on projectiles (the engine asks "does this enemy fire AIMED?" via
data, not via its filename). While in here, expose the handful of currently-implicit knobs as
`StageConfig` fields so pacing is fully tunable from the `.tres` without code edits.

## User Stories

1. As the developer, I want the weighted enemy selection asserted in tests, so a bad weight array can't silently skew a stage's enemy mix.
2. As the developer, I want the concurrency cap asserted, so "max N enemies on screen" can't regress into a swarm.
3. As the developer, I want the score-driven spawn-rate ramp asserted (start interval → end interval as stage score climbs), so pacing changes are intentional, not accidental.
4. As the developer, I want the aimed-shot minimum-gap rule asserted, so the anti-frustration spacing between aimed enemies holds.
5. As the developer, I want the boss-score-threshold trigger asserted to fire exactly once, so a stage can't spawn two bosses or none.
6. As the developer, I want the intro timeline's clock-driven event firing asserted (events fire in time order, at/after their timestamp, exactly once each, with the tail-pad finish), so authored intros stay deterministic.
7. As the developer, I want the director to classify "aimed" from the enemy's declared threat tier, not from its filename, so renaming or adding aimed enemies can't break the spacing rule.
8. As the developer, I want the currently-hard-coded knobs (spawn-width offset, boss spawn position, intro tail-pad) exposed as data where they affect feel, so I can tune them without editing code.
9. As the developer, I want the tests to run against the *real* `StageConfig`/`StageIntroTimeline` resource shapes, so they catch breakage in the data contract too.
10. As the developer, I want the hardening to be behaviour-preserving by default, so landing it doesn't change how existing levels play (only how confidently I can change them).
11. As the developer, I want the spawn/intro logic separated from timers and the scene tree where it isn't already, so the decisions are testable without instantiating a level.
12. As a player, I want stage pacing to remain exactly as it feels today unless I deliberately retune it, so this engineering pass is invisible to me.

## Implementation Decisions

- **This is a test + de-fragilise pass, not a redesign.** The director/intro/spawner architecture
  stays. The deliverables are coverage, the classifier swap, and knob exposure.
- **Extract the director's pure decisions** so they're testable without a running `Timer` or scene:
  - **weighted pick** — given `(scenes, weights, rng)` → index. Already essentially pure inside
    `_pick_weighted`; lift it to a function that takes an injectable RNG/roll so a test can assert
    exact selection for a given roll.
  - **spawn-interval ramp** — given `(interval_start, interval_end, stage_score, boss_threshold)` →
    current interval. Pure `lerpf` clamp; lift and test the boundaries (0 score, ≥ threshold, mid).
  - **aimed-gap decision** — given `(now, last_aimed_time, min_gap, candidate_is_aimed)` → allow /
    substitute-non-aimed. Pure; test the gap window.
  - **boss-threshold** — given `(stage_score, threshold, already_triggered)` → should-fire-once.
- **Replace the filename classifier.** Today `_is_aimed_scene` matches `"Tank"`/`"Ship"` in the
  resource path. Re-point it at the **threat tier** PRD-02 introduces: an enemy is "aimed" if it
  fires AIMED-tier projectiles. The cleanest contract is a small declared property on the enemy
  scene (e.g. an exported `primary_threat_tier`) the director can read without instantiating combat;
  the decision is *data-driven classification*, not string-sniffing. (Depends on PRD-02 landing the
  tier concept.)
- **Extract the intro player's schedule logic.** `StageIntroPlayer` already sorts events and fires
  them by an accumulating clock; lift the "which events are due at elapsed `t`" decision into a pure
  function `due_events(sorted_events, prev_elapsed, now_elapsed) -> slice` so firing order/edge
  timing is unit-testable without `_process`.
- **Expose implicit knobs on `StageConfig`** where they touch feel: `spawn_width_offset` (today a
  `const` in the director), `boss_spawn_position` (today hard-coded `Vector2(270, -100)` in
  `EnemySpawner`), and the intro `tail_pad_seconds` (today a `const`). Defaults equal today's values
  so nothing changes unless retuned.
- **Behaviour parity is the acceptance bar:** existing `level01`/`levelocean` stage configs must
  play identically after the refactor.

## Testing Decisions

- A good test asserts **external behaviour, not implementation**: inject a known RNG roll and assert
  *which* scene index the weighted pick returns; feed a stage score and assert the *interval*; feed
  elapsed times and assert *which* intro events fire. No inspection of private timers.
- **Director tests:** weighted pick honours weights (degenerate all-equal, skewed, zero-total
  fallback to uniform); concurrency cap blocks spawns at/above the cap and resumes below it;
  interval ramp hits `start` at 0 score, `end` at ≥ threshold, monotonic between; aimed-gap
  substitutes a non-aimed pick inside the gap window and allows aimed outside it; boss-threshold
  fires exactly once and not again after triggered.
- **Intro-player tests:** events fire in time order; an event fires at/after its timestamp and
  exactly once; a long frame that spans several events fires all of them in order; empty timeline
  finishes after the tail pad; the finish signal fires once.
- **Classifier test:** an enemy declaring AIMED tier is treated as aimed; one declaring STRAIGHT is
  not — regardless of its scene filename (the regression PRD-05 would otherwise trip).
- **Prior art:** the GUT harness + `test/` layout stood up in PRD-01 (issue #26) and extended in
  PRD-02/03. **This finally pays back the specific tests ADR-0004 named** ("`SpawnDirector`'s
  weighted random selection, concurrency cap and aimed-shot gap, plus `StageIntroPlayer`'s
  clock-driven event firing"). Update ADR-0004's outstanding-debt note when this lands.

## Out of Scope

- **The boss fight itself** (weak-points, phases) → **PRD-12**. This PRD keeps the existing boss
  *trigger + placeholder spawn*; it doesn't build boss behaviour.
- **New enemy archetypes / threat-tier-correct fire** → **PRD-05**. This PRD *consumes* the tier
  data PRD-02 adds; it doesn't author enemies.
- **Authoring real stage intros / spawn tables for shipping levels** → **PRD-14**. This PRD tests the
  *engine*, not specific level content.
- **Changing how any current stage plays** — strictly behaviour-preserving except for deliberately
  exposed-and-retuned knobs.

## Further Notes

- ADR-0004's trigger was **issue #9** (`SpawnDirector`/`StageConfig`); that code merged without the
  promised tests, so this debt is overdue. ADR-0004 already records (2026-05-26) that GUT is being
  stood up in PRD-01 and that "the `SpawnDirector` / `StageIntroPlayer` tests this ADR originally
  called for are still owed" — **this PRD is where that debt is paid.**
- Sequence after **PRD-02** (which introduces the threat-tier concept the classifier swap depends on).
  The test-only portions can land independently of PRD-02 if needed.
- **Done =** the stage engine's weighted pick, concurrency cap, interval ramp, aimed-gap, and
  boss-threshold all have passing GUT tests; the intro player's scheduling has passing tests; the
  aimed classifier reads declared threat tier instead of the filename; the implicit feel knobs are on
  `StageConfig`; existing levels play identically; and ADR-0004's outstanding-test note is closed out.
