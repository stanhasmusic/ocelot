# PRD-14 — Level content template + Level 1 (Pacific Beachhead)

> **To be published as [issue #37](https://github.com/stanhasmusic/ocelot/issues/37)**
> (`ready-for-agent`) — the tracker is canonical.
> The convergence PRD of the content spine: it assembles the **first real, beatable level** out of the
> systems built before it (PRD-04 stage engine, PRD-05 archetypes, PRD-12 boss system, PRD-13 Kamikaze
> wing) **and** establishes the **clone-able recipe** every later level follows. It also clears out the
> prototype-era scaffolding those systems left standing.
>
> Grilled 2026-06-05 (`grill-with-docs`). Canonical design lives in `CONTEXT.md` + the ADRs; this PRD
> implements them. Companion artefact: `docs/design/level-build-guide.md` (the HITL background/landmark
> handbook authored during the grill).

## Problem Statement

The game has every *system* a level needs — a stage engine (PRD-04), an 8-archetype enemy kit (PRD-05),
a multi-part weak-point/phase boss system (PRD-12), and the Pacific Kamikaze wing signature (PRD-13) —
but **no real level that uses them**. Normal play still runs the disposable prototype scenes
(`LevelLand`/`LevelJungle`/`LevelOcean`) over legacy single-entity `PrototypeBoss` fights; the real boss
system is only DevConsole-spawnable, wired into nothing. There is also no **established pattern** for
assembling a level, so Levels 2–4 would each reinvent it.

Two debts come due here specifically. PRD-12 deferred **purging the `PrototypeBoss` scaffolding** until a
real boss was wired into a stage (carry-over on #37). PRD-11 deferred **convoy placement/counts** to the
level content. And a latent gap blocks the level's whole teaching premise: the campaign opener is
supposed to teach "dodge **straight** (blue) → then **aimed** (orange)" (ADR-0013), but **no enemy in the
roster fires straight/blue** — every flyer is tagged aimed or pattern.

## Solution

Assemble **Level 1 — Pacific Beachhead** end-to-end as the worked exemplar of a repeatable level recipe,
and use the assembly to retire the prototype debris.

**The "template" is a documented recipe + L1 as the exemplar — not a framework.** At N=1 a level-builder
abstraction is premature (the same anti-abstraction rule that governed the PRD-13 signature pattern). The
repeatability is "clone `LevelOcean.tscn`'s 14-line shape, author the content `.tres`, point `boss_scene`
at a boss assembly," plus a written checklist so L2–L4 don't rediscover it. An abstraction is extracted
only if L2 reveals genuine shared structure.

**Level 1 is the campaign, trimmed honest.** Build `LevelPacific.tscn` as the one real level; **delete the
three prototype level scenes and their stage configs**; trim `GameManager.LEVELS` to `[LevelPacific]`. The
campaign array now tells the truth (one real level, growing as L2–L4 land), and "campaign complete" + the
terminal coins→score cash-out fire after Pacific — exercising those paths for real.

**Purge the legacy boss apparatus.** With the prototypes gone, delete `PrototypeBoss.gd`, `Boss.tscn`,
`BossL2`/`BossL3` (scripts + scenes), and the now-orphaned prototype stage configs; remove the vestigial
`StageConfig.boss_hp` field and its `EnemySpawner`/`Boss.gd` shims. `Boss.gd` remains the canonical
multi-part boss base; **named boss scenes are descriptive** (`CoastalFortress.tscn`, not a generic
`Boss.tscn`).

**Fix the roster so L1 is teachable** (folded into this PRD, not a separate cleanup). Designate `Fighter`
as the **Strafer** (retag → `STRAIGHT`/blue + fire straight-down), use `Helicopter` as the **orange aimed
flyer** (productively splitting today's identical `Fighter`/`Helicopter` twins), and **exclude the purple
spread-flyers** (`AceFighter`/`Bomber`/`Interceptor`) from L1 — **purple debuts at City/L3** per the locked
campaign. The whole level is **blue + orange only**.

**The three-stage spine** (difficulty carried entirely by spawn rate / concurrency / projectile speed — no
new threat colour, no new archetype after S1):

| | Stage 1 — Onramp + FTUE | Stage 2 — Escalation | Stage 3 — Climax |
|---|---|---|---|
| Intro teaches | blue Strafer → orange aimed flyer → bomb pickup + **Kamikaze wing** (the survivable swarm) | first **shooting ground** (Tank/Emplacement) | dense air+ground; **Kamikaze wing reprise** |
| Procedural body | light: Strafers + a few aimed flyers; **1 Truck convoy** (harmless ground intro); low rate | Strafers + aimed flyers + Tanks; convoy continuity; medium rate | full blue+orange cast; peak rate |
| Closes with | **Warship mini-boss** (naval) | **Coastal-gun mini-boss** (ground) | **Coastal Fortress** (named boss) |

The ground ramp is deliberate: **harmless ground (S1 convoy) → shooting ground (S2 Tank) → ground mini-boss
(S2 coastal gun) → ground boss (S3 fortress)**, so nothing on the ground surprises the player cold. S1's
intro is authored to **PRD-17's FTUE beat-sheet** (PRD-17 later adds the self-suppressing hint *layer*;
this PRD builds the spawn choreography that creates the failure-trigger moments).

**Backgrounds are placeholder-first, art is HITL.** Wire `PacificScrollingBackground.tscn` + a
`level_pacific.tres` with three stage strips + a boss arena, shipped on **placeholder gradients** so the
level is playable immediately; the human authors the real hand-authored strips + **baked-in landmarks**
(incl. the ADR-0003 pre-boss fortress telegraph) and the fortress arena, dropped in via the `.tres` with
no code. See `docs/design/level-build-guide.md`.

## User Stories

1. As a player, I want a complete Level 1 that runs intro → body → mini-boss across three stages and ends
   in a named boss, so the game finally has a real level to play, not a prototype.
2. As a new player, I want the opener to teach me by playing — a readable blue straight-shooter first,
   then an orange aimed shot that punishes standing still, then a swarm that makes me reach for the bomb —
   so I learn without a tutorial (ADR-0013).
3. As a player, I want the threat to escalate across the three stages through *more and faster*, not
   through a confusing new bullet colour, so Level 1 stays an honest onramp.
4. As a player, I want to meet harmless ground traffic, then ground that shoots, then a ground mini-boss,
   then the ground fortress — so each ground threat is "a bigger version of something I've seen."
5. As a player, I want a named boss — a Coastal Fortress whose guns I peel before its core opens — so the
   level climaxes in a real set-piece, with the scenery dropping away to the fortress arena.
6. As a player, I want the Kamikaze wing in the opener and again at the climax, so the level's signature
   threat is taught once and tested once.
7. As a player, I want the world to visibly build toward the boss (ocean → beachhead → fortress shore,
   with the fortress on the horizon before it spawns), so I feel progress and "boss coming."
8. As the developer, I want a documented, clone-able level recipe (not a framework), so Levels 2–4 are
   assembled the same way without reinventing it.
9. As the developer, I want the prototype level scenes and the entire `PrototypeBoss` apparatus deleted
   and `boss_hp` removed, so the only boss path in the game is the real multi-part system.
10. As the developer, I want the campaign array trimmed to the one real level, so it reflects what exists
    and the end-of-campaign flow is exercised for real.
11. As the developer, I want the enemy roster made coherent for L1 (a real blue Strafer, the twins split,
    purple held back to L3), so the teaching premise is actually buildable.
12. As the developer, I want a cheap structural smoke test over the assembled level, so the heavy
    deletion/rewiring can't silently break the wiring.
13. As the human, I want the background art + landmarks + music to be drop-in (`.tres` + exports) on top
    of a playable placeholder level, so my art/feel iteration never requires code changes.

## Implementation Decisions

### Template & campaign
- **Documented recipe, no framework.** Deliver `LevelPacific.tscn` (clone of the `LevelOcean.tscn` shape)
  + extend `docs/design/level-build-guide.md` with the **assembly checklist** (clone scene → author N
  stage configs → author intros → wire boss scenes → wire background). No level-builder abstraction.
- **Trim the campaign.** `GameManager.LEVELS = ["res://scenes/LevelPacific.tscn"]`; update
  `current_level` default. **Delete** `LevelLand/Jungle/Ocean.tscn` and the prototype stage configs
  (`levelland_*`, `levelocean_*`, `level03_*`). Accept that "campaign complete" + coin cash-out fire
  after Pacific — and feel-test those paths in this PRD.

### Purge (PRD-12 carry-over)
- **Delete:** `actors/PrototypeBoss.gd`, `actors/Boss.tscn`, `actors/BossL2.{gd,tscn}`,
  `actors/BossL3.{gd,tscn}`, and the orphaned prototype stage configs.
- **Remove `StageConfig.boss_hp`** (field) + the `boss.max_hp = _config.boss_hp` line in
  `EnemySpawner._spawn_boss()` + the `var max_hp` shim in `Boss.gd`. Multi-part bosses own HP in parts.
- `Boss.gd` stays the boss base; **named boss scenes are descriptively named.**
- `BossReference.tscn` / `MiniBossReference.tscn` (PRD-12 DevConsole proving harnesses) are **kept** —
  separate lineage from PrototypeBoss; still useful for telegraph feel-testing.

### Roster fix (folded in)
- `Fighter` → **Strafer**: set `primary_threat_tier = STRAIGHT`; fire straight-down (drop the
  `aimed_direction` call). The missing blue tier-0 enemy.
- `Helicopter` → the **orange aimed flyer** (already `AIMED`; no change beyond being the designated one).
- `AceFighter`/`Bomber`/`Interceptor` (pattern/purple) — **not used in L1**; held for L3.
- Glossary already trued-up (`CONTEXT.md`: Gunship = pattern/purple + the archetype→scene mapping note).
  **Not fixed here** (their own PRDs): the `EliteEscort` AIMED→PATTERN mistag, and the absent `Diver` scene.

### Bosses
- **`CoastalFortress.tscn`** (fresh, `Boss.gd` base): **1 bunker core + 2 flanking gun weak-points → 3
  phases**. Core invulnerable until both guns die. Fire is **blue + orange only** (guns aimed-orange;
  core a wide straight-spread on exposure) — **no purple**. Skinned from `buildings/bunkers/`
  (`bunkers_big`, `gun_big_tripple` to honour "triple coastal guns", dual guns), with `_hit`/`_destroyed`
  variants. **Armor values authored into parts as data** but mechanically inert until PRD-10; do not
  balance around armor.
- **Two core-only mini-bosses** (`Boss.gd`, single `is_core` part, no weak-points/phases):
  - **S1 — Warship** (naval): full sway, single aimed-orange shots (movement-forward). Skin from
    `shipz/` (`ship_large_body` + a `ship_gun`).
  - **S2 — Coastal gun** (ground): **very gentle** sway (reads as turret tracking), narrow **aimed
    3-shot fan** (more bullets, near-stationary) — foreshadows the fortress's multi-gun fire. Skin from
    the `bunkers/` gun family.
  - Cores ~**20–24 HP**, `defeat_score ~1500` each (vs. the boss's 5000) — conservative first pass.
- **Named-boss distinction:** add a reusable flag on `Boss.gd` (e.g. `is_named_boss`). **Only the named
  boss** triggers the background **arena swap** (mini-bosses fight over the parked strip, staying in the
  world). The same flag is what **PRD-16** will use to gate the **boss-music hard-swap** (ADR-0014: minis
  get no music). Mini-bosses still show the aggregate health **bar** — only arena (now) and music (later)
  are named-boss-only.

### Stages, intros, spawns
- **3 `StageConfig` `.tres`** (`level01_stage{0,1,2}.tres` rewritten as the real Pacific content), each:
  `intro_timeline`, blue+orange `enemy_scenes`/`enemy_weights`, ascending `boss_score_threshold`,
  conservative rates (`spawn_interval_*`, `max_concurrent_enemies`, `projectile_speed_mult`), `boss_scene`.
- **3 intro timelines.** S1 authored to PRD-17's beat-sheet (empty sky → blue Strafer → orange aimed
  flyer → bomb pickup + **Kamikaze wing** survivable swarm). S3 intro **reprises** the Kamikaze wing.
- **Convoy placement (PRD-11 carry-over):** **~1 convoy of ~4 `Truck` units across L1** (the S1 convoy
  doubles as the harmless ground-plane introduction; 1–2 stray trucks in S2/S3 for continuity).
  **No economy `.tres` retune** — `convoy_coin_value`/floors stay PRD-11's tunables; this PRD only places
  units. (The other PRD-11 deferral, the Naval-finale math, is **L4's**, out of scope here.)

### Background
- Wire `PacificScrollingBackground.tscn` → `level_pacific.tres` (3 `StageBackground` strips +
  `boss_arena_texture`), exposing `scroll_speed` per stage. Ship on **placeholder gradient strips** so the
  level is playable; real art is the HITL drop-in. **Landmarks baked into the strip PNGs**
  (`parallax_layers` is unconsumed by the runtime — do not rely on it). Pre-boss fortress landmark near
  the top of the S3 strip (ADR-0003 telegraph). Arena = the Coastal Fortress set-piece backdrop.

## Testing Decisions

- PRD-14 is overwhelmingly **content assembly**; per ADR-0004, content is **feel-tested**, only pure
  logic earns GUT tests. The boss/mini-bosses reuse the already-tested `BossState`; the arena-gating flag
  and `Fighter`'s straight-fire are wiring/one-liners — feel-tested.
- **One new test file, `test_level_one_assembly.gd`** — a cheap, headless, no-render **wiring guard**:
  - Each of the 3 stage configs loads with `intro_timeline != null`, `boss_scene != null`, non-empty
    `enemy_scenes`, and `enemy_weights.size() == enemy_scenes.size()`.
  - `boss_scene` per stage is correct (S0 → Warship mini, S1 → Coastal-gun mini, S2 → `CoastalFortress`).
  - Boss part structure via `SceneState` (no instantiation): `CoastalFortress` = **1 core + 2 non-core**;
    each mini-boss = **1 core, 0 non-core** (guards the CONTEXT "degenerate boss" definition).
  - `level_pacific.tres` has **3 `stage_backgrounds`** + a non-null `boss_arena_texture`.
  - `LevelPacific.tscn` wires **3 stages** and points `background_scene` at the Pacific background.
- **One-line test update:** `test_enemy_archetype_tiers.gd` — `Fighter` AIMED → **STRAIGHT**.
- **Regression guard:** the full suite must **stay green after the deletions + array trim + `boss_hp`
  removal** (verified no test currently references the removed scenes/field). Suite-green *is* the purge
  regression check.
- **Deliberately left codifying a known defect:** `EliteEscort` stays AIMED in scene + test (the L3 PRD
  flips both) — consistent-but-wrong now beats a half-fix.

## Out of Scope

- **Levels 2–4** (Countryside/City/Naval) — clone this template in their own PRDs (#41 / PRD-15+).
- **The FTUE hint layer** (self-suppressing prompts) → **PRD-17**; this PRD only builds the L1S1 spawn
  choreography the hints attach to.
- **Boss music / audio polish** → **PRD-16** (consumes the `is_named_boss` flag).
- **Armor mechanics** → **PRD-10** (parts carry inert armor data now).
- **Juice** (dive trails, impact polish, screenshake) → **PRD-20**.
- **The `EliteEscort` tier mistag + a real `Diver` scene** → their relevant later PRDs.
- **The Naval-finale economy math** (PRD-11 deferral) → the **L4** PRD.
- **Per-biome enemy reskinning mechanism** → deferred until a later biome proves the need (N=1 rule);
  L1 reuses the existing Pacific-consistent sprites as-is.
- **Final background/arena art + music** → HITL deliverables (gated done-bar), not the code deliverable.

## Further Notes

- **Two done-bars.** Criteria 1–4 + 6 (below) are the **code/assembly** deliverable — *code-complete on
  placeholder art*. Criterion 5 is the **gated HITL** deliverable (real art + music + pacing sign-off).
  The level is playable and testable the moment assembly lands; it becomes *art-complete* when the human
  authors the strips.
- **Why fold the roster fix in (not a precursor PR).** The blue Strafer is a hard prerequisite for a
  teachable L1 — assembling the level without it would mean authoring an opener that can't teach its first
  lesson. Splitting the identical `Fighter`/`Helicopter` twins into the two teaching tiers also leaves the
  code cleaner than it found it.
- **Synergy to preserve.** The `is_named_boss` flag is intentionally reusable: arena swap (this PRD) and
  boss music (PRD-16) are the *same* named-boss distinction. Don't implement it as a one-off.
- **Companion doc.** `docs/design/level-build-guide.md` is the HITL handbook (how the strip/scroll/arena
  system works, the strip-height formula, asset picks, per-stage placement, the baked-in-landmark
  workflow). It is part of this PRD's "documented recipe" deliverable.

## Done =

1. `LevelPacific.tscn` runs **intro → procedural body → mini-boss across 3 stages with checkpoints**,
   ending in the **Coastal Fortress**; `GameManager.LEVELS` is `[LevelPacific]`; "campaign complete" +
   coin cash-out fire after it (feel-tested).
2. **All `PrototypeBoss` scaffolding deleted**, `boss_hp` removed, prototype levels/configs gone — and the
   GUT suite stays green.
3. Roster coherent for L1: a **blue Strafer + an orange aimed flyer**, **no purple anywhere in L1**;
   **Kamikaze wing in S1 intro + S3 reprise**; **only the named boss** swaps to the arena.
4. **`test_level_one_assembly.gd` + the updated `test_enemy_archetype_tiers.gd` pass; full suite green.**
5. **(HITL-gated)** real hand-authored background + baked-in landmarks (incl. pre-boss fortress telegraph)
   + fortress arena placed; Pacific `level_music` chosen; **L1 is beatable start→boss and *feels* like a
   place** (pacing sign-off).
6. The **assembly recipe is documented** (`docs/design/level-build-guide.md`, extended with the assembly
   checklist) as the clone-able template for Levels 2–4.
