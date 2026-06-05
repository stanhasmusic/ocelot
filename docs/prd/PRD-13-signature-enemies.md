# PRD-13 — Signature enemies: the Kamikaze wing

> **To be published as [issue #35](https://github.com/stanhasmusic/ocelot/issues/35)** (`ready-for-agent`) — the tracker is canonical.
> The first **signature enemy** (`CONTEXT.md` → *Signature enemy*): a hand-built, level-specific
> set-piece layered on the archetype backbone for identity. This PRD builds **only the Pacific
> Beachhead's Kamikaze wing** — the one signature [[PRD-14]] (Level 1) consumes — and establishes the
> **reusable pattern** every later signature follows. The **Train** (Countryside) and **flak-tower
> gauntlet** (City) are deliberately deferred to their own level PRDs, where each is built *and* wired
> *and* felt in one slice (see Further Notes).
>
> System-vs-content split, same as PRD-09 (gadget system) → PRD-14 (content) and PRD-12 (boss system)
> → PRD-14 (named bosses): this PRD ships the wing as a **DevConsole-spawnable unit**; PRD-14 authors
> the actual Pacific Stage-1 intro that introduces it.

## Problem Statement

The campaign's identity comes from per-level **signature enemies** — the moments that make a biome
*itself* rather than a reskinned spawn table. None exist yet, and there is no established pattern for
building one: the archetype kit (PRD-05), `FirePattern`, and the `StageIntroTimeline` system all exist
as ingredients, but nothing demonstrates how you compose them into a hand-built set-piece. **PRD-14
(Level 1) is blocked on this**: the Pacific Beachhead's scripted intro needs its Kamikaze wing to
exist before the level can be assembled, and PRD-14 should not also be inventing the "how to build a
signature" pattern from scratch.

The Kamikaze wing specifically: Level 1's air cast threatens entirely with *bullets*. There is no
enemy that threatens with **position** — that forces the player to clear a *lane* rather than dodge a
*projectile*. That second dodge-verb is exactly the clean teaching contrast the L1 intro wants
(ADR-0013, invisible onboarding), and nothing in the cast delivers it.

## Solution

Build the **Kamikaze wing**: a coordinated formation of suicide planes whose identity is *"the body is
the weapon."* They **do not fire**. They enter in formation from off the top, hold briefly, then
**commit suicide dives one at a time** down straight lines locked to the player's position at the
instant of commit — telegraphed, dodgeable, learnable. The threat is spatial, not projectile; the
dodge verb is "get out of the lane," distinct from everything else in Level 1.

The wing is **one self-managing coordinator scene** that owns its member planes — it spawns them,
holds the formation, sequences the staggered commits, and self-frees when the last member is gone. It
drops into a stage as a **single `StageIntroEvent`** (`{time, scene, spawn_position}`), the
`spawn_position` becoming the wing's entry anchor. This *is* the reusable signature pattern: **a
signature enemy is a bespoke composite scene (coordinator + members) built from existing
archetype / `FirePattern` / `Enemy` pieces, introduced via one intro-timeline event.** No
`SignatureEnemy` base class — at N=1 that is premature abstraction; the pattern is a documented
convention, and a base is extracted only if the Train/flak later prove shared code.

The member plane is a lightweight script on the existing `Enemy` base (HP, hit-flash, explosion,
coin-drop, off-screen despawn all inherited); it adds only the dive behaviour. The wing is a **plain
pack of enemies, not a boss** — no health bar, no boss-music event, no progression gate.

This PRD ships the wing as a **DevConsole-spawnable unit** plus one throwaway demo `StageIntroEvent`
that proves it drops correctly through the real intro-timeline contract; PRD-14 replaces the demo with
authored Pacific content.

## User Stories

1. As a player, I want a wave of suicide planes that dive at me without shooting, so Level 1 has a
   threat I dodge by *moving out of the way* rather than by reading bullets.
2. As a player, I want each plane to **telegraph** before it commits, so I can read which one is coming
   and sidestep it — the encounter is learnable, not a surprise.
3. As a player, I want the wing to commit its dives **one at a time** (not all at once), so the
   pressure has a readable rhythm instead of an unsurvivable wall.
4. As a player, I want to be able to **shoot a plane down during its telegraph**, so I can choose to
   neutralise the threat aggressively instead of only dodging.
5. As a player, I want a plane that has **committed** its dive to be unstoppable by gunfire, so the
   telegraph is a genuine "kill it now or commit to dodging" decision.
6. As a player, I want my **bomb** to clear even committed kamikazes, so the panic button still answers
   a dive I misjudged.
7. As a player, I want killing a kamikaze to pay **coins**, so clearing the wing under pressure is
   rewarded — while a plane that completes its dive and leaves pays nothing.
8. As the developer, I want the wing built as **one coordinator scene** dropped via a single
   `StageIntroEvent`, so PRD-14 introduces it with one timeline entry and the formation is actually
   coordinated, not faked by hand-placing planes.
9. As the developer, I want every feel value (formation shape/count/spacing, hold time, stagger gap,
   telegraph length, dive speed, member HP, coin value) exposed as **`.tres` knobs**, so I tune the
   encounter without touching code.
10. As the developer, I want the formation-layout and commit-schedule **math extracted as pure,
    unit-tested helpers** (ADR-0004), so the choreography is verifiable without rendering.
11. As the developer, I want the wing **DevConsole-spawnable** and proven through one demo intro-timeline
    event, so I can feel-test it and confirm the integration contract before PRD-14 has a level.
12. As the developer, I want a **documented signature pattern** the Train and flak gauntlet will follow,
    so later signatures don't each reinvent the structure.

## Implementation Decisions

- **`KamikazeWing` coordinator scene** (`actors/KamikazeWing.tscn` + script). On `_ready` it computes
  member offsets from the formation knobs, instances N members at the anchor (its own
  `global_position`, i.e. the event's `spawn_position`), and drives the formation hold → staggered
  commit sequence. It **self-frees** once its last member is dead-or-despawned, and emits a
  `wing_cleared` signal on the way out (no listener required this PRD).
- **Member plane** (`actors/Kamikaze.gd` + scene) extends `Enemy.gd`. Inherits HP / `_flash_hit` /
  explosion / coin-drop / off-screen despawn. Overrides movement; sets `projectile_scene = null` (**it
  never fires**). Joins the **`"Enemies"` group** so the bomb AoE reaches it (like every other target).
  Lifecycle: `ENTER` (slide into formation slot) → `HOLD` → `TELEGRAPH` (bank/tilt + brighten) →
  `COMMIT` (lock a straight line via `FirePattern.aimed_direction(self, player)` at the commit instant,
  accelerate down it) → off-bottom despawn. **One dive per plane, no looping.**
- **Invuln-on-commit, bomb-exempt.** A committed member sets `is_committed = true`, which **guards
  `_on_area_entered`** (player bullets pass through a committed plane). `take_damage` is left
  **unguarded**, so the bomb — which calls `take_damage(~100)` directly on the `"Enemies"` group —
  still vaporises committed planes. Contact with the player stays live throughout (`_on_body_entered`
  deals the standard 1 damage and the plane dies on impact).
- **Staggered commits only** — the wing commits left-to-right down the formation with a tunable gap; no
  "all at once" mode (kept simple; a commit-mode knob is a trivial later add if a higher-tier level
  wants it). Likewise **number of passes is fixed at 1** for now (a cheap knob to expose later).
- **Coin reward** via the existing PRD-05 hook: a **modest `coin_value`** (above a Strafer, below a
  Convoy), **no power-up loot roll** (`loot_pool` empty — it's a combat enemy, not a piñata). Coins
  drop in `die()`, so a *completed* dive (despawn, not death) pays nothing.
- **Pure helpers** (`scripts/`, `class_name`, RefCounted, in the `BossState` / `IntroSchedule` /
  `SpawnPlan` mould):
  - **Formation layout** — `(count, spacing, shape) -> Array[Vector2]` of member offsets about the
    anchor (a centred V for the default shape).
  - **Commit schedule** — `(count, hold_time, stagger_gap) -> Array[float]` of per-member commit times.
  The coordinator consumes these; the dive line itself reuses the already-tested
  `FirePattern.aimed_direction`.
- **Tunables `.tres`** (`KamikazeWingTunables`) holding: formation shape/count/spacing, entry speed,
  hold time, stagger gap, telegraph seconds, dive speed/accel, member HP, member coin value. Seeded
  **conservative** (V of ~5, generous telegraph, unhurried stagger, moderate dive speed) per the
  slower-defaults principle — the human dials menace up.
- **Not a boss.** No `on_boss_*` signals, no health bar, no boss-music event (ADR-0014 gives even
  mini-bosses none). It plays over the normal stage track.
- **No timeline gating.** The `StageIntroTimeline` stays **time-based** as built (events at fixed times
  + tail pad); we do **not** add "wait until the wing clears." PRD-14 authors enough tail pad so the
  wing is the moment's focus. Pacing/placement is PRD-14's call.
- **DevConsole command** to spawn a `KamikazeWing` at a default anchor (mirrors PRD-12's spawnable
  reference fights), plus **one throwaway demo `StageIntroEvent`** wired into an existing prototype
  stage to prove the wing drops through the real intro-timeline path. Both are demo scaffolding PRD-14
  supersedes.

## Testing Decisions

- A good test asserts **external behaviour, not implementation** — feed knobs, assert the geometry /
  schedule out. No instantiation of full scenes; no rendering.
- **Formation-layout tests:** returns exactly `count` offsets; symmetric about the anchor (centred V);
  `count == 1` returns a single zero/centre offset; spacing scales the spread linearly.
- **Commit-schedule tests:** returns exactly `count` times; first commit == `hold_time`; each
  subsequent time increases by `stagger_gap`; monotonic; `count == 1` yields a single time.
- **Dive-line reuse:** the lock reuses `FirePattern.aimed_direction` (already covered by PRD-05's
  tests) — assert the member calls it with the player position at commit, not at spawn.
- **Prior art:** GUT `test/` layout from PRD-01–05 / PRD-12. Add the formation + schedule test files in
  that shape.
- The node-level behaviour (actual diving, contact, invuln-on-commit, bomb-clears-committed) is
  **feel-tested live** via the DevConsole — not unit-tested.

## Out of Scope

- **The Train** (Countryside set-piece) and **flak-tower gauntlet** (City) → their own **level PRDs**
  (Countryside / City), built+wired+felt in one slice. *Note for the Countryside PRD:* the campaign
  table currently double-bills the Train as both the L2 **signature** and the L2 **boss** — resolve
  that overlap there (is it a `PathFollow2D` boss built on the PRD-12 part system, or a separate
  mid-stage signature?), not here.
- **The Carrier** (Naval signature, "launches air waves") → the Naval level PRD.
- **A `SignatureEnemy` base class / framework** → not built; the pattern is a documented convention.
  Extract a base only if the Train/flak demonstrate real shared code.
- **Wiring the wing into actual Pacific content** (where in the Stage-1 intro it lands, tail pad,
  surrounding spawns) → **PRD-14**.
- **Final art skinning** (which sprite skins the kamikaze plane) → human taste call during PRD-14.
- **Looping / multi-pass dives** and a **simultaneous-commit mode** → deferred knobs, not built now.
- **Juice** (dive trails, impact polish, screenshake on crash) → PRD-20.

## Further Notes

- **Why one signature, not three.** The roadmap originally batched Train + Kamikaze + flak into PRD-13,
  but only the **Kamikaze wing** is consumed by the next spine PRD (PRD-14, Pacific/L1). The Train (L2)
  and flak gauntlet (L3) belong to levels not built until later, so building them now would mean merged,
  **unwired, unplaytested** content sitting for several PRDs — against the tracer-bullet principle. They
  move to their level PRDs (grilled 2026-06-04). This also defers the Train's signature-vs-boss
  question to where L2 is actually on the table.
- **The signature pattern this establishes** (for the Train/flak/Carrier to follow): a bespoke
  **composite scene** (a coordinator owning members, or a single scripted set-piece) built from the
  existing archetype / `FirePattern` / `Enemy` ingredients, **introduced via one `StageIntroEvent`**,
  with pure choreography helpers and `.tres` feel knobs — *not* a class hierarchy.
- **FTUE synergy (PRD-17).** PRD-17 teaches the bomb via "a gifted pickup + a survivable swarm + the
  pulsing JETT button." A telegraphed Kamikaze wing *is* that survivable swarm ("you can't shoot these
  in time… JETT!"), and the bomb-clears-committed rule makes the lesson land. The two reinforce each
  other; PRD-14/PRD-17 author the actual teaching beat.
- **Done =** a `KamikazeWing` is DevConsole-spawnable and drops through one demo `StageIntroEvent`; it
  enters in formation, holds, then commits **staggered, telegraphed, one-shot locked dives** that deal
  contact damage; members are **killable during the telegraph** (1–2 HP) and **invulnerable to shots
  once committed** but **clearable by the bomb**; kills pay coins, completed dives pay nothing; the wing
  fires **no projectiles**, shows **no boss bar/music**, and **self-frees** when empty; formation-layout
  + commit-schedule helpers are pure and pass under GUT; and all feel values are `.tres` knobs.
