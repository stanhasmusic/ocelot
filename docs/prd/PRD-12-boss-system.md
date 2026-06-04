# PRD-12 — Boss & mini-boss system

> **To be published as [issue #34](https://github.com/stanhasmusic/ocelot/issues/34)** (`ready-for-agent`) — the tracker is canonical.
> The destructible-**weak-point** + telegraphed-**phase** boss system. Canonical design lives in
> `CONTEXT.md` (the **Part** / **Weak-point** / **Core** / **Phase** / **Boss** / **Mini-boss** entries) and
> `docs/adr/0009-destructible-weakpoint-phase-bosses.md` (incl. the 2026-06-04 PRD-12 refinement).
> This is the **system** half of bosses; the bespoke, *named* bosses (BIG MAMA, …) and their art are
> authored later in the level PRDs ([[PRD-14]] / [[PRD-15]]) — the same system-vs-content split as
> PRD-09 (gadget system) → PRD-14 (Level 1 content).

## Problem Statement

Every stage currently ends in the same prototype boss: a single-entity sprite with one HP pool and a
crude half-HP "phase" flip (`actors/Boss.gd`). It underuses the asset library's modular gun pieces
(turrets/engines with `_hit`/`_destroyed` states), offers no target-prioritization depth, and isn't a
*learnable* set-piece — you just hose it down. ADR-0009 chose a richer fight (multi-part weak-points
guarding a core, escalating through telegraphed phases) precisely so the climactic moment rewards reading
the boss rather than reflexes, and so the armor/explosive layer and the Spotter/Flare gadgets all matter
at the climax. None of that exists, and **PRD-14 (Level 1) is blocked on it** — you cannot assemble a
level's final stage without a boss system, nor its stages 1–2 without mini-bosses.

## Solution

A reusable **boss system** in which a boss is a **tree of parts**: several **weak-points** guarding one
**core**. The player destroys the weak-points — each silencing the attack it drives — and only once **every
weak-point is destroyed** does the **core** become vulnerable; destroying the core ends the fight. The boss
escalates through **phases** driven *purely by weak-point destruction* (no HP-percentage flips), so the
player always sees *why* the boss got harder. Every attack **telegraphs** with a generous wind-up so the
fight is learnable and the Spotter gadget is a bonus, not a requirement.

A **mini-boss** is the degenerate case of the same system — **core-only**: a single heavy target, no
weak-points to peel, no phases — so stages 1–2 need no special-case code.

The **decision logic is pure and isolated** from nodes (a `BossState` helper with `class_name`, in the
`HangarUpgrades` / `GadgetLoadout` / `CheckpointState` mould) so the core gate, phase resolution, aggregate
health, and defeat all unit-test deterministically under GUT (ADR-0004). The node layer (`Boss`, `BossPart`)
composes a boss as a **scene**, reusing the existing `FirePattern` / `AutoFireClock` helpers (PRD-05) for fire
geometry and timing, and reports to the **existing** `on_boss_*` signals.

This PRD ships the **system + one reference boss + one reference mini-boss** that exercise it end-to-end
(using **existing art only**, reachable via a DevConsole spawn for playtest). The named bosses are deferred
to the level PRDs.

## Design notes

- **A boss is a tree of `Part`s; exactly one is the `core`.** A `Part` is the single reusable unit — own HP,
  own hitbox, own `armor` value, own `_hit`/`_destroyed` art. The non-core parts are the **weak-points**.
  Destroying the **core** ends the fight; this unifies the old "weak-points + core" language into one concept
  and makes the mini-boss fall out for free (one part, flagged core).
- **The core is hard-gated.** The core is **fully invulnerable until every weak-point is destroyed** — its
  hitbox does not take damage before then. Chosen over "always-damageable but heavily armored" because the
  hard gate is the most readable target-prioritization rule for the noob/mid-tier audience ("peel the guns,
  *then* the core is exposed"). **This invulnerability is a gate mechanic, distinct from armor** — see the
  armor note below.
- **Phases are driven purely by weak-point destruction.** Each phase declares its **entry trigger** as a
  weak-point milestone (e.g. "phase 2 when the first weak-point falls"); the **final phase is, by definition,
  "all weak-points destroyed → core exposed."** There are **no HP-percentage phase flips** (the prototype's
  `current_hp <= max_hp/2` is gone). So **N weak-points yield up to N+1 phases**. A phase change re-tunes the
  *surviving* parts' fire (rate/pattern), usually escalating.
- **Aggregate health bar.** `on_boss_spawned(max_hp)` reports the **sum of every part's HP** at spawn;
  `on_boss_health_changed(current, max_hp)` reports the **sum of living parts' remaining HP**, re-emitted on
  every hit and every part destruction. The bar drains **monotonically** through the whole fight (weak-points
  then core) — one continuous "boss is X% dead," no resets, no mid-fight re-max. The "core exposed" beat is
  carried by the part's art swap + telegraph, not by the bar.
- **Armor is reserved, not yet active.** A `Part` carries an `armor` field (per ADR-0009), but **PRD-12
  applies flat HP damage only** — `armor` is inert, exactly like SaveGame reserved `owned_tiers` before
  PRD-08 used it. **PRD-10** (#33) owns the gun-reduction / explosive-bonus interaction and will govern boss
  parts uniformly with every other heavy target — no PRD-12 rework. The **core's gate is separate from
  armor**: the gate is "can't be damaged yet"; armor (later) only tunes *how efficiently* an exposed part
  takes gun vs. explosive damage.
- **Telegraphs are a tunable wind-up.** Each attack pattern has a **`telegraph_seconds`** lead: a part about
  to fire enters a visible **wind-up** for that duration, then fires. PRD-12 ships a **functional placeholder
  tell** (the firing part flashes / shows a simple warning glyph) — enough to playtest readability. The lead
  defaults **generous** (slow, very readable; [[feedback_feel_defaults_conservative]]) and is the knob that
  makes the fight fair independent of Spotter. **Telegraph juice** (charge animations, muzzle build-up, screen
  cues) is deferred to **PRD-20**.
- **Reference set uses existing art only.** The reference boss (2 weak-points + core, 3 phases) and reference
  mini-boss (core-only) reuse heavy-archetype / boss-prototype sprites. This is what keeps PRD-12
  **buildable with no HITL art commitment** — the bespoke named bosses *and their art* are PRD-14's job. The
  reference boss is a deliberately-ugly proving harness, not BIG MAMA.
- **Replace the prototype.** `actors/Boss.gd` is the disposable single-entity prototype
  ([[project_next_session]]); PRD-12 replaces it with `Boss` + `BossPart` + `BossState`. Its sprite art may be
  salvaged for the reference boss.

## User Stories

1. As a player, I want a boss to be built from several destructible parts, so the climactic fight is about *where* I shoot, not just *how long*.
2. As a player, I want to destroy a boss's individual weak-points (turrets/engines) and see each one visibly break, so my progress is legible.
3. As a player, I want destroying a weak-point to silence the attack it was firing, so peeling the boss makes the screen calmer and rewards prioritization.
4. As a player, I want the boss's exposed core to be untouchable until I've destroyed all its weak-points, so there's a clear "peel, then finish" structure.
5. As a player, I want the boss to visibly escalate when I destroy a weak-point, so I understand *why* it got harder.
6. As a player, I want every boss attack to wind up with a clear tell before it fires, so I can react without memorizing or relying on a gadget.
7. As a player, I want a single boss health bar that drains as I damage the boss, so I always know roughly how close I am to winning.
8. As a player, I want the boss to die when I destroy its exposed core, so the kill condition is unambiguous.
9. As a player, I want a mini-boss to close stages 1–2 — a single tough target with aimed fire and no phases — so the non-final stages have a climax that's simpler than the level boss.
10. As a player, I want to be rewarded with score for defeating a boss (and a little for each weak-point I peel), so the fight pays off.
11. As a player, I want a boss I died to to reset cleanly when I retry from the stage checkpoint, so a failed attempt is a fresh attempt.
12. As the developer, I want the boss decision logic (gate, phases, aggregate HP, defeat) isolated from nodes, so I can unit-test it deterministically without spawning a level.
13. As the developer, I want a boss authored as a scene of parts I position and art in the editor, so building a new boss is composition, not code.
14. As the developer, I want a mini-boss to be just a one-part boss with no special-case code, so the two share one system.
15. As the developer, I want each part's HP, armor, core flag, and fire config to be editor-exported data, so boss feel tunes without code.
16. As the developer, I want bosses to reuse the existing `FirePattern`/`AutoFireClock` helpers, so fire geometry/timing is expressed one correct way everywhere.
17. As the developer, I want a reference boss and reference mini-boss built from existing art, so the system is proven end-to-end with no art commitment.
18. As the developer, I want to spawn the reference boss/mini-boss on demand from the DevConsole, so I can feel-test telegraph readability without grinding a stage to its score threshold.
19. As the developer, I want the boss to report through the existing `on_boss_*` signals and drive the existing health bar, so the HUD works without new plumbing.
20. As the developer, I want the `armor` field present but inert, so PRD-10 can layer the damage-type math onto boss parts with no schema rework.

## Implementation Decisions

- **`BossState` (pure logic, `class_name`, `RefCounted`, no nodes) — the deep module.** The GUT-testable
  brain, parallel to `HangarUpgrades` / `GadgetLoadout`. Holds the parts as data (per part: `max_hp`,
  `current_hp`, `is_core`, `armor`, and which phase-milestone it gates). Interface (behavioural, names
  indicative):
  - `apply_damage(part_id, amount) -> { destroyed, ... }` — reduces a part's HP (flat; `armor` ignored this
    PRD), clamped at 0; reports whether that hit destroyed the part. A no-op against a non-damageable part.
  - `is_damageable(part_id) -> bool` — the **core gate**: a weak-point is always damageable while alive; the
    core is damageable **iff every weak-point is destroyed**.
  - `current_phase() -> int` — resolved purely from which weak-points are destroyed + the phase-milestone
    table; the final phase corresponds to "all weak-points destroyed."
  - `aggregate_hp() -> { current, max }` — sum of living parts' HP / sum of all parts' HP at spawn.
  - `is_defeated() -> bool` — true once the core is destroyed.
- **`BossPart` (Area2D, scene + script).** Own hitbox + `_hit`/`_destroyed` art swap; exports `max_hp`,
  `armor`, `is_core`, the phase-milestone it belongs to, and its fire config (pattern kind + cadence). On a
  player-projectile hit it asks the owning `Boss` to route damage; the `Boss` consults `BossState.is_damageable`
  before applying, so an un-exposed core simply shrugs off hits (no damage, gate feedback only).
- **`Boss` (`Boss.gd` root — replaces the prototype).** At `_ready()` builds `BossState` from its child
  `BossPart`s and reports `on_boss_spawned(aggregate max)`. Routes part hits into `BossState`; on any HP change
  re-emits `on_boss_health_changed(aggregate)`. Drives each **living** part's fire via `FirePattern`
  (geometry) + `AutoFireClock` (cadence), gated by a per-pattern `telegraph_seconds` wind-up. On a
  `current_phase()` change, re-tunes surviving parts' cadence/pattern. On `is_defeated()`, awards a
  configurable defeat score (+ optional small per-weak-point score), runs the existing big-explosion/death,
  and emits `on_boss_died`.
- **Phase → pattern.** A phase is data: a milestone (which/how-many weak-points destroyed) + per-surviving-part
  fire overrides applied while that phase is current. The final phase exposes the core and starts the core's
  pattern. No HP triggers anywhere.
- **Boss health bar hookup (minimal).** Wire the existing, currently-dead `BossBar` `ProgressBar` to the
  `on_boss_*` signals (show on spawn, set value/max on change, hide on death). Functional only; segmented/tinted
  visuals and per-weak-point pips are **PRD-18**.
- **DevConsole.** Add reference-boss and reference-mini-boss spawn entries to the existing "— Encounter —"
  section (mirroring the archetype picker), spawning the reference scenes into the current level regardless of
  stage/score. Drives existing seams only — the console "touches no game code" rule holds.
- **Spawn/lifecycle seam is unchanged.** A boss is still a `StageConfig.boss_scene: PackedScene` instantiated
  by `EnemySpawner` on `boss_threshold_reached`; `LevelBase._on_boss_died` still advances the stage. PRD-12
  only changes *what that scene is internally*.
- **`StageConfig.boss_hp` is vestigial.** A multi-part boss owns its HP in its parts, so the stage-level
  `boss_hp` int is superseded for new bosses — annotated as a documented no-op and left in place to avoid
  churning `StageConfig` consumers. **Follow-up: retire `boss_hp` once no scene relies on it** (tracked here so
  the cleanup isn't lost). `boss_score_threshold` / `boss_spawn_position` stay (they decide when/where to
  spawn).
- **Telegraph timing** may be factored into a small pure helper (testable) or reuse `AutoFireClock`; left to
  the implementer, but if it lives as standalone logic it gets a test.

## Testing Decisions

- **What makes a good test here:** assert external behaviour through the module's interface, not private state
  — same rule as PRD-01/08/09. Drive `BossState` purely as data; never spawn a node.
- **Prior art:** `test/unit/test_hangar_upgrades.gd` (purchase/cap/no-mutation discipline to mirror),
  `test/unit/test_gadget_loadout.gd` (own/equip/cap), `test/unit/test_affected_by_bomb.gd` /
  `FirePattern` tests (pure combat-math shape).
- **`BossState` tests (the deep module — comprehensive):**
  - **Core gate:** the core is **not** damageable while any weak-point lives; it **becomes** damageable the
    instant the last weak-point is destroyed; damage applied to a gated core is a no-op.
  - **Phase resolution:** `current_phase()` advances exactly at each weak-point milestone; the final phase
    corresponds to all weak-points destroyed; order-independence where the milestone is a count.
  - **Aggregate HP:** `max` = sum of all parts at spawn; `current` decreases by damage and by part destruction;
    never negative; reaches a known floor (core HP) just before the core dies.
  - **Defeat:** `is_defeated()` is false until the core is destroyed, true after; destroying weak-points alone
    never defeats the boss.
  - **Mini-boss (degenerate):** a single core-only `BossState` is **immediately damageable** (gate vacuously
    satisfied), has a single phase, and is defeated when its one part dies — proving no special-casing.
  - **No mutation on no-op:** damage to a destroyed or non-damageable part leaves state unchanged.
- **Telegraph timing helper** (only if extracted as standalone logic): wind-up blocks firing until the lead
  elapses; fires once after; re-arms.
- The node layer (`Boss`/`BossPart` integration, telegraph *feel*, bar hookup, DevConsole spawn) is verified
  **in-editor + via the DevConsole**, the project norm — not via headless node tests.

## Out of Scope (scope guards)

- **Named, bespoke bosses (BIG MAMA, Double Trouble, …) and their art** → the level PRDs ([[PRD-14]]+). PRD-12
  ships only generic reference fights from existing art.
- **Armor / explosive-damage interaction** → **PRD-10** (#33). The `armor` field is present but inert (flat HP
  damage); PRD-10 makes it bite, on boss parts and other heavies uniformly.
- **Telegraph juice** (charge animations, muzzle build-up, screen cues) → **PRD-20**. PRD-12 ships a functional
  placeholder tell + the tunable lead time.
- **Fancy boss-bar visuals** (per-weak-point pips, core-segment tint, boss name plate) → **PRD-18** (HUD &
  menus). PRD-12 does the minimal functional hookup only.
- **Per-phase health-bar refill / multiple bars** — rejected in favour of one monotonic aggregate bar.
- **HP-percentage phase triggers / enrage timers** — rejected; phases are purely weak-point-driven this game.
- **Boss coin drops / economy tuning** — out; defeat reward is score only. Economy placement is PRD-11 / level
  PRDs.
- **New input bindings** — bosses add none.
- **Stage placement of the reference fights into real levels** — the reference boss/mini-boss are DevConsole-
  spawnable proving harnesses; wiring real bosses into real stages is PRD-14.

## Acceptance criteria

- [ ] A boss is composed of multiple `BossPart`s with one flagged `core`; each weak-point has its own HP and
  hitbox and swaps to destroyed art when killed, and destroying it silences the attack it drove.
- [ ] The **core takes no damage** until **every** weak-point is destroyed; once the last weak-point falls the
  core becomes damageable, and destroying the core ends the fight.
- [ ] The boss escalates through **telegraphed phases driven only by weak-point destruction** (no HP-threshold
  flips); destroying a weak-point visibly changes the surviving parts' fire.
- [ ] Every boss attack **telegraphs** with a tunable wind-up + a visible (placeholder) tell, generous by
  default; a player who reads tells can survive without the Spotter gadget (HITL feel-test).
- [ ] Boss health reports through the existing `on_boss_*` signals as a **monotonic aggregate**, and the
  existing `BossBar` shows/updates/hides accordingly.
- [ ] A **mini-boss** exists as a core-only boss: single heavy target, aimed fire, immediately damageable, no
  weak-points, no phases — built on the same system with no special-case code.
- [ ] A **reference boss** (2 weak-points + core, 3 phases) and **reference mini-boss** (core-only) are built
  from **existing art** and are spawnable from the **DevConsole**.
- [ ] Defeating a boss awards a configurable score (+ optional small per-weak-point bonus); dying mid-fight and
  retrying from the stage checkpoint resets the boss cleanly.
- [ ] The prototype `actors/Boss.gd` is replaced by the new system; `StageConfig.boss_hp` is annotated as a
  vestigial no-op for multi-part bosses.
- [ ] GUT covers `BossState`: the core gate (invulnerable → damageable on last weak-point), phase resolution
  from weak-point destruction, aggregate HP, defeat-on-core, the core-only mini-boss case, and no-mutation on
  no-op damage. (Plus telegraph-timing logic if extracted.)

## Files

- `scripts/BossState.gd` — pure parts/gate/phase/aggregate/defeat logic (`class_name`, no nodes).
- `actors/BossPart.gd` (+ `BossPart.tscn`) — Area2D part: hitbox, hit/destroyed art swap, exports
  (`max_hp`, `armor`, `is_core`, phase milestone, fire config).
- `actors/Boss.gd` — **replaces** the prototype: builds `BossState`, routes damage, drives per-part fire via
  `FirePattern`/`AutoFireClock`, telegraph wind-up, phase re-tune, defeat reward, `on_boss_*` emission.
- `actors/BossReference.tscn` — reference boss (2 weak-points + core, 3 phases), existing art.
- `actors/MiniBossReference.tscn` — reference mini-boss (core-only), existing art.
- `scripts/DevConsole.gd` — reference boss / mini-boss spawn entries in the Encounter section.
- HUD boss-bar hookup — wire the existing `BossBar` to the `on_boss_*` signals (minimal).
- `scripts/StageConfig.gd` — annotate `boss_hp` as vestigial (comment only).
- `test/unit/test_boss_state.gd` — `BossState` coverage per Testing Decisions.
- (optional) `test/unit/test_<telegraph>.gd` — only if telegraph timing is extracted as standalone logic.
