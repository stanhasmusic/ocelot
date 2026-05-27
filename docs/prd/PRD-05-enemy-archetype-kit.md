# PRD-05 — Enemy archetype kit

> **Published as [issue #30](https://github.com/stanhasmusic/ocelot/issues/30)** (`ready-for-agent`) — the tracker is canonical.
> Phase 2 slice. Systematises the enemy cast into the 8 reskinnable archetypes that feed the spawn
> tables, each with **threat-tier-correct fire** ([[0001-projectile-colour-by-threat-tier]]) and coin
> drops. Canonical vocabulary lives in `CONTEXT.md` (Enemy archetype, Elite, Signature enemy).
>
> **Grounding note:** the cast already exists but grew ad-hoc. `actors/Enemy.gd` is the base
> (downward drift, timer fire, 22% loot roll, off-screen despawn). Subclasses already implemented:
> `Tank` + `Ship` (turret tracks player → aimed fire within range), `RocketLauncher` (aimed, homing
> `RocketBullet`), `Fighter` + `Helicopter` (sinusoidal + aimed), `EliteEscort` (aimed), `Bomber`
> (5-shot wide spread), `AceFighter` (3-shot spread), `Interceptor` (2-shot V), plus `Train`/`Truck`
> (path/convoy) and three bosses. So the *behaviours* mostly exist — what's missing is a **named,
> consistent archetype taxonomy**, **declared threat tiers** (so fire colour and the PRD-04 director
> classifier are correct), and **coin drops**. This PRD is a consolidation refactor, not new enemies
> from scratch.

## Problem Statement

As the developer, the enemy roster is a pile of one-off scripts that each re-implement "find the
player, fire toward them" or "fire a spread" slightly differently, with no shared notion of what
*kind* of threat each one is. There's no canonical list of archetypes, so spawn tables are assembled
from whatever scripts happen to exist, and nothing guarantees an "aimed" enemy actually fires
aimed-tier (orange) projectiles or that the director's spacing rules apply to it. And no enemy drops
coins, so the earn→spend loop the metagame depends on has nothing feeding it.

## Solution

Define the **8 canonical archetypes** as a clean reusable kit, each declaring its **primary threat
tier** so its fire is the right colour and the stage director classifies it correctly by data (not
filename). Fold the existing scripts into these archetypes rather than rewriting them, factor the
repeated "fire" math into shared pure helpers, and give every archetype a **coin drop** on death so
the economy has a source. Each archetype is art-reskinnable per biome (the human picks which sprite
skins which archetype), but behaviour and tier are fixed by the archetype.

## User Stories

1. As the developer, I want a canonical, named set of 8 enemy archetypes, so spawn tables are built from a known vocabulary instead of whatever scripts exist.
2. As the developer, I want each archetype to declare its primary threat tier, so its projectiles are the correct colour and the director classifies it without sniffing filenames.
3. As a player, I want a basic straight-firing flyer (Strafer) whose shots are blue, so the easiest enemy is the most readable.
4. As a player, I want a diving/closing enemy (Diver) that threatens by movement, so positioning matters, not just dodging bullets.
5. As a player, I want a spread/pattern flyer (Gunship) whose fire is purple, so I know to thread it.
6. As a player, I want a ground turret (Emplacement) that fires aimed orange shots, so stationary threats read as "keep moving."
7. As a player, I want an armoured ground unit (Tank) with a tracking turret firing aimed shots, so heavy ground targets feel distinct from flyers.
8. As a player, I want convoy units (trucks/train on a path) that are about positioning and reward, so set-piece ground traffic reads differently from combat flyers.
9. As a player, I want a naval unit (Warship) with tracking aimed fire, so water biomes have a signature heavy.
10. As a player, I want an Elite — a lone, tougher enemy that uses pattern (purple) fire — so occasional spikes of intensity punctuate the procedural body.
11. As a player, I want each archetype to read as visually distinct even when reskinned per biome, so I can tell threats apart at a glance.
12. As the developer, I want the repeated firing math (aimed direction, N-shot spread angles) factored into shared pure helpers, so every archetype computes fire the same correct way and I can unit-test it.
13. As the developer, I want every archetype to drop coins on death (amount scaling with difficulty/score value), so the economy has a consistent source.
14. As the developer, I want coin drops separated from the existing weapon/bomb/repair/life loot roll, so currency and power-ups are tuned independently.
15. As the developer, I want archetypes to share the base `Enemy` lifecycle (HP, hit-flash, explosion, off-screen despawn), so per-archetype scripts only express what's unique.
16. As the developer, I want the spawn-table `.tres` to be able to mix all 8 archetypes with weights, so stage authoring (PRD-04 engine, PRD-14 content) has the full palette.
17. As the developer, I want this refactor to preserve how current enemies behave in existing levels, so consolidation doesn't change today's pacing.

## Implementation Decisions

- **The 8 archetypes** (folding existing scripts in), each with a fixed **primary threat tier**:
  | Archetype | Role | Primary tier | Folds in / basis |
  |---|---|---|---|
  | **Strafer** | basic straight flyer | STRAIGHT (blue) | base `Enemy` straight fire |
  | **Diver** | closes/dives at player | (contact + STRAIGHT) | new behaviour atop base movement |
  | **Gunship** | spread/burst flyer | PATTERN (purple) | `Bomber` / `AceFighter` / `Interceptor` |
  | **Emplacement** | static aimed turret | AIMED (orange) | turret logic from `Tank`/`Ship` (no move) |
  | **Tank** | mobile armoured turret | AIMED (orange) | `Tank` |
  | **Convoy** | path-following ground traffic | (low/none) | `Truck` / `Train` |
  | **Warship** | naval tracking heavy | AIMED (orange) | `Ship` |
  | **Elite** | lone tougher pattern user | PATTERN (purple) | `EliteEscort` / sinusoidal `Fighter` line |
  - The mapping consolidates today's overlapping scripts (Fighter/Helicopter ≈ moving variants;
    AceFighter/Interceptor/Bomber ≈ Gunship spread variants). Variants survive as data/skins on an
    archetype, not as separate one-off classes where they only differ by spread count or sprite.
- **`primary_threat_tier` is a declared property** on each archetype (exported), consumed by PRD-02's
  projectile tagging and PRD-04's director classifier. This is the contract that replaces filename
  sniffing.
- **Extract fire math into a pure `FirePattern` helper** — the deep, testable module:
  - `aimed_direction(from, to) -> Vector2` (unit vector toward target),
  - `spread_directions(base_dir, count, arc) -> Array[Vector2]` (the N-shot fan today hard-codes as
    literal angle lists `[-0.5,-0.25,0,0.25,0.5]` etc.).
  Archetypes call these instead of re-deriving angles inline, so a "3-shot 30° fan" is computed one
  correct way everywhere.
- **Coin drop is its own hook**, separate from `Enemy.drop_loot`'s power-up roll. On death, spawn a
  coin pickup (count from a `coin_value` export, defaulting to scale with `score_value`). The
  **coin pickup scene itself is delivered in PRD-06**; this PRD adds the drop *hook* and the
  per-archetype value. Until PRD-06's coin exists, the hook is a no-op flag — no economy logic here.
  - The roll math (current `Enemy.drop_loot`: 22% pool roll + a 50% extra filter on bomb pickups) is
    pure and worth lifting into a testable `loot_roll(rng, pool, filters) -> scene_or_null`.
- **Base-class consolidation:** the shared lifecycle (HP, `_flash_hit`, explosion, score, off-screen
  despawn) stays in `Enemy.gd`; archetypes override only movement and `_on_shoot_timer_timeout`.
  Remove duplicated player-lookup boilerplate by lifting it to the base.
- **Behaviour parity:** existing level spawn tables must still produce equivalent encounters; archetype
  consolidation is internal.

## Testing Decisions

- A good test asserts **external behaviour, not implementation**: feed positions/counts and assert
  the returned direction vectors; feed an RNG roll and assert which loot (or none) drops. No
  instantiation of full enemy scenes.
- **`FirePattern` tests:** `aimed_direction` returns a unit vector pointing from source to target
  (cardinal + diagonal cases); `spread_directions` returns exactly `count` vectors, symmetric about
  the base direction, spanning the requested arc; `count == 1` returns the base direction unchanged;
  even vs odd counts both centre correctly.
- **`loot_roll` tests:** below the drop threshold returns null; above it returns a pool member; the
  bomb extra-filter roughly halves bomb selection; an empty pool returns null. (Deterministic via an
  injected RNG/roll value.)
- **Threat-tier declaration test:** each archetype reports the tier in the table above (guards the
  PRD-04 classifier contract).
- **Prior art:** GUT `test/` layout from PRD-01–04. Add `FirePattern` + `loot_roll` test files in
  that shape.

## Out of Scope

- **Coin currency, coin counter, and economy balancing** → coin *value* lives here as data, but the
  currency system and prices are **PRD-11**; the coin *pickup scene* is **PRD-06**.
- **Armor / damage-type resistance** on heavy archetypes (Tank/Warship/Emplacement) → **PRD-10**
  (they declare being heavy; the resist math is later).
- **Signature enemies** (the Train as a Countryside set-piece, Kamikaze wing, flak gauntlet) →
  **PRD-13**. `Convoy` here is the generic path-traffic archetype, not the scripted Train set-piece.
- **Bosses / mini-bosses** → **PRD-12**.
- **Final per-biome art skinning** (which sprite = which archetype per level) → human taste call made
  during **PRD-14** content authoring.

## Further Notes

- This PRD and **PRD-02** share the threat-tier concept: PRD-02 makes tiers exist on projectiles;
  this PRD makes each archetype *declare* its tier; **PRD-04** consumes that declaration to replace
  filename classification. Sensible sequence: PRD-02 → PRD-05 → PRD-04 (or PRD-04's classifier swap
  lands once both tier-producers exist).
- Watch the existing `Fighter`/`Helicopter`/`AceFighter`/`Interceptor`/`Bomber` overlap — the goal is
  *fewer* classes expressing the 8 archetypes via data, not preserving every one-off. Where two
  scripts differ only by a spread count or sprite, collapse them into one archetype + a `.tres`/export.
- **Done =** spawn tables can mix all 8 named archetypes; each declares and fires its correct threat
  tier (blue/orange/purple); shared `FirePattern` helpers back every archetype's fire; every
  archetype has a coin-drop hook with a per-archetype value; existing levels play equivalently; and
  `FirePattern` + `loot_roll` unit tests pass under GUT.
