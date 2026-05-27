# PRD-02 — Threats & Survival

> **Published as [issue #27](https://github.com/stanhasmusic/ocelot/issues/27)** (`ready-for-agent`) — the tracker is canonical.
> Phase 1 tracer-bullet slice (second half). Implements the threat-tier projectile model
> ([[0001-projectile-colour-by-threat-tier]]) and the checkpoint half of the campaign model
> ([[0005-persistent-campaign-with-hangar-metagame]]). Canonical design lives in `CONTEXT.md`
> and `docs/adr/`.
>
> **Grounding note:** the *survival* half of this slice already exists — plane-as-HP (`d0→d4`
> sprite swap), lives, respawn-in-place, and a combo/score multiplier are all implemented in
> `actors/Player.gd` and `scripts/GameManager.gd`. The genuinely missing pieces are (a) a
> **threat-tier projectile system** (today enemy bullets are undifferentiated and colour is keyed
> to the *firing enemy*, not its *behaviour*) and (b) **checkpoints** (today death just consumes a
> life and respawns in place; zero lives → GameOver). This PRD closes those two gaps.

## Problem Statement

As a player, I can't read incoming fire. Every enemy bullet looks roughly the same regardless of
whether it's a dumb straight shot I can ignore by holding a lane, an aimed shot that's tracking me
right now, or a dense pattern I have to thread. So I get hit by things I should have been able to
dodge, and the difficulty feels random instead of fair. And when I do die, a level is long enough
that losing all my progress back to the start is punishing in a way that makes me not want to retry.

## Solution

Colour *is* the warning. Every enemy projectile is coloured by its **behaviour**, not by which
enemy fired it: **blue = straight** (fixed heading, ignore it by not standing in the lane),
**orange = aimed** (fired at where you are — keep moving), **purple = pattern** (spread / homing /
bursts — read and thread). The same three colours mean the same three things everywhere in the
game, so a new player learns the language once.

And dying mid-level drops you back to the **last checkpoint** in the current stage rather than to
the start of the level, so a long level stays worth retrying. Losing a life still costs the plane's
weapon level and resets you to a safe spot, but progress through the stage is preserved at
checkpoint granularity. Running out of lives ends the run.

## User Stories

1. As a player, I want straight-flying enemy shots to be one consistent colour, so I learn at a glance that "blue = it won't follow me."
2. As a player, I want aimed shots that are tracking my position to be a distinct warning colour, so I know to keep moving.
3. As a player, I want dense pattern/spread/homing fire to be a third distinct colour, so I know this one needs threading, not just side-stepping.
4. As a player, I want the colour-to-behaviour mapping to be identical across every enemy and every level, so the visual language is learnable once and never lies.
5. As a player, I want a projectile's colour to match how it *actually* moves, so the warning is never wrong (an aimed shot is never blue).
6. As a new player, I want the threat colours to be distinguishable at a glance on a small mobile screen and against busy backgrounds, so readability survives the noise.
7. As a player, I want my plane to visibly degrade as it takes hits (`d0`→`d4`), so I always know how close I am to losing the plane. *(Exists — must remain intact.)*
8. As a player, I want a cushion of lives so a single mistake doesn't end the whole run. *(Exists — must remain intact.)*
9. As a player, when I lose the plane, I want to respawn at a safe position with brief invincibility, so I'm not instantly re-killed. *(Exists — must remain intact.)*
10. As a player, when I lose the plane mid-stage, I want to resume from the last checkpoint I passed rather than the start of the level, so a long level is worth retrying.
11. As a player, I want to clearly know when I've banked a checkpoint, so I understand what I'll keep if I die.
12. As a player, I want running out of lives to end the run cleanly (GameOver), so the stakes are real. *(Exists — must remain intact.)*
13. As the developer, I want each projectile to declare its threat tier as data, so colour and tier can never drift out of sync.
14. As the developer, I want the tier→colour mapping defined in exactly one place, so re-skinning or colour-blind options are a one-line change.
15. As the developer, I want checkpoint state isolated from scene/node specifics, so I can unit-test "where do I resume" deterministically.
16. As the developer, I want the checkpoint system to hook the existing stage→stage flow in `LevelBase` rather than replace it, so this slice stays low-risk.
17. As the developer, I want enemy fire to keep using the existing per-enemy `_on_shoot_timer_timeout` behaviours, so this PRD changes how shots *look and are classified*, not how enemies aim.

## Implementation Decisions

- **Threat tier is data on the projectile, not the enemy.** Introduce a small shared concept — a
  `threat_tier` value (`STRAIGHT`, `AIMED`, `PATTERN`) carried by every enemy projectile — plus a
  single mapping module that turns a tier into its canonical colour. The current zoo of bullet
  scripts (`EnemyBullet`, `TankBullet`, `ShipBullet`, `TurretBullet`, `RocketBullet`) keeps its
  movement code; what changes is that each declares its tier, and a shared helper applies the
  tier colour (modulate or sprite-variant) on spawn.
  - **`ThreatTier` palette module** — the single source of truth. A pure mapping
    `tier_to_color(tier) -> Color` (and the inverse/labels for a future colour-blind option).
    Lives in one file; nothing else hard-codes a threat colour. This is the deep, testable module.
  - Tier assignment from current behaviour: straight downward fire (`EnemyBullet`) → **STRAIGHT**;
    turret/aimed fire that points at the player at fire time (`TankBullet`/`ShipBullet`/
    `TurretBullet` as fired by Tank/Ship/RocketLauncher/Fighter/Helicopter/EliteEscort) → **AIMED**;
    spread and homing (`Bomber`/`AceFighter`/`Interceptor` spreads, `RocketBullet` homing) →
    **PATTERN**.
- **Colour application is centralised** so "what does AIMED look like" is answered once. Whether the
  art is a recolour (`modulate`) of a shared bullet sprite or three distinct sprites is an
  integration detail; the *decision* is that the projectile asks `ThreatTier` for its colour rather
  than embedding it.
- **Checkpoints hook the existing stage flow, not a rewrite.** `LevelBase` already drives
  `intro → procedural body → boss → next stage`. Add a **`CheckpointState`** concept that records
  the furthest safe resume point (at minimum: current stage index + a "stage-start vs post-intro"
  marker; finer in-stage checkpoints are optional and knob-gated). On player death with lives
  remaining, respawn logic consults `CheckpointState` for the resume point.
  - **`CheckpointState` module** — pure logic: `record(stage_index, marker)` and
    `resume_point() -> {stage_index, marker}`, monotonic (never moves a player *backward*).
    Deterministic and node-free → the second testable module in this slice.
- **Respawn keeps its current behaviour within a stage** (safe position + invincibility + weapon
  reset on life loss). The checkpoint only governs *which stage / phase* you re-enter when you'd
  otherwise have lost stage progress.
- **No change** to the plane-as-HP sprite swap, lives counting, combo multiplier, or GameOver flow —
  those exist and are correct. This PRD adds classification + checkpointing around them.
- **Enemy aiming behaviour is untouched.** Tank/Ship/etc. keep tracking and firing exactly as they
  do; they simply spawn tier-tagged projectiles.

## Testing Decisions

- A good test asserts **external behaviour, not implementation**: feed a tier, assert the colour;
  feed a sequence of checkpoint records, assert the resume point. No peeking at private fields.
- **`ThreatTier` tests:** every tier maps to a distinct colour; the mapping is total (no tier
  returns a null/!default colour); STRAIGHT/AIMED/PATTERN colours are mutually distinct.
- **`CheckpointState` tests:** fresh state resumes at stage 0 / start; recording a later stage
  advances the resume point; recording an *earlier* stage never moves the resume point backward
  (monotonic); recording the same point twice is idempotent.
- **Prior art:** the `PlayerMovement`/`AutoFireClock` GUT tests stood up in PRD-01 (issue #26) are
  the precedent — same `test/` layout and GUT config. This PRD adds two more pure-module test files
  in that established shape; it does **not** re-stand-up the harness.

## Out of Scope

- **Armor / damage-type layer** (heavy targets resisting gun fire) → **PRD-10**.
- **Colour-blind / accessibility palette toggle** — the `ThreatTier` module is *designed* to make
  this a one-place change, but the settings UI + alternate palette are **not** built here.
- **Authoring the actual bullet art** (recolour vs three sprites) is an integration choice for the
  implementer; this PRD fixes the *system*, not the final pixels. Flagged like the player-shot
  colour gap in PRD-01.
- **Fine-grained in-stage checkpoints** beyond stage/phase granularity — knob-gated and optional;
  default is stage-boundary checkpoints.
- **Save-to-disk of checkpoints across app restarts** → that's campaign persistence, **PRD-07**.
  This slice's checkpoint is in-memory for the current run.
- Boss-specific fire patterns and weak-points → **PRD-12**.

## Further Notes

- The current `SpawnDirector` classifies "aimed" by **string-matching `"Tank"`/`"Ship"` in the
  scene path** — fragile and now redundant with an explicit `threat_tier`. Re-pointing the aimed-gap
  logic at the projectile's declared tier is desirable but lives in **PRD-04** (stage-engine
  hardening); this PRD just makes the tier data *exist* so PRD-04 can consume it.
- Today every projectile deals exactly 1 damage and despawns off-screen via a visibility notifier —
  keep both behaviours; tiers are about *readability*, not (yet) damage values.
- **Done =** every enemy shot is coloured by behaviour (blue straight / orange aimed / purple
  pattern) consistently across enemies; the mapping lives in one module; dying mid-level resumes you
  at the last stage checkpoint instead of the level start; lives/HP/GameOver behave exactly as
  before; and `ThreatTier` + `CheckpointState` unit tests pass under GUT.
