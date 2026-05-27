# Ocelot — Design Status (resume-here pointer)

Last updated: 2026-05-26. A pointer for any session picking this work back up.

## What this game is (one line)

A WWII-skinned, modern-systems top-down shmup: persistent campaign + Hangar upgrade metagame,
mobile-first + PC, built asset-first from `assets/`, for a noob/mid-tier audience.

## Canonical sources (read these first)

- **`CONTEXT.md`** — the glossary. All in-game vocabulary (threat tiers, campaign/level/stage,
  Hangar/coins/pickups, player loadout, enemy archetypes, bosses).
- **`docs/adr/0005`–`0013`** — the foundational decisions made this design pass:
  - 0005 persistent campaign + Hangar metagame *(amended by 0011: persistence is per-Playthrough, not forever)*
  - 0006 input-aware controls over one shared difficulty curve
  - 0007 Hangar = 4 stat tracks + gadget loadout
  - 0008 unified fire + armor/damage-type layer
  - 0009 destructible-weak-point + phase bosses
  - 0010 absolute difficulty curve + Hangar catch-up (skill substitutes for ~1 tier)
  - 0011 economy = Guns-spine pace track + scarce skill-fed slack, reset every Playthrough
  - 0012 player fire = its own visual class (white/pale-gold), tier escalates by mass not hue *(amends 0001)*
  - 0013 onboarding = invisible scenario-teaching + self-suppressing hints (no tutorial, no first-run state)
  - (pre-existing/prototype-era, take with a grain of salt: 0001 projectile colour *(amended by 0012)*,
    0002 hybrid stage difficulty, 0003 hand-authored backgrounds, 0004 defer test framework)
- **`docs/prd/ROADMAP.md`** — the build plan: 20 PRDs in 5 phases, with the human-in-the-loop split.
- **`docs/prd/PRD-01-flight-and-fire.md`** — the PRD detail-format exemplar.

## Locked design pillars

1. WWII skin, modern systems (mobile-first + PC)
2. Per-Playthrough campaign + Hangar metagame; death → checkpoint; New Game resets to zero (arcade arc)
3. Level = biome theater (3 stages, checkpoints); Hangar between levels
4. Drag/positional + auto-fire; auto-swap to velocity on pad/kbd; one shared difficulty curve + assists
5. Plane-as-HP (d0→d4) + lives cushion
6. Permanent Guns tier owns the plane sprite; pickups are temporary toppings
7. Hangar = Guns/Armour/Engine/Bombs tracks + Items gadget loadout
8. Unified fire + armor/damage-type layer (explosives bonus vs armor)
9. 8 enemy archetypes + a signature enemy per level; elites = lone non-boss pattern user
10. Destructible-weak-point bosses with telegraphed phases

## Locked campaign (grilled 2026-05-26)

Four levels, escalating, naval finale. Difficulty is an absolute authored curve with the Hangar as
between-level catch-up (ADR-0010). Built scenes (LevelLand/Jungle/Ocean) are disposable prototypes —
the campaign is built fresh from the PRD-14 template.

| # | Level | Difficulty role | Signature set-piece | Teaches | Boss | Boss art |
|---|-------|-----------------|---------------------|---------|------|----------|
| 1 | **Pacific Beachhead** | onramp (tier ~0) | Kamikaze wing | dodge straight→aimed, weak-points, bomb | Coastal fortress | assembled |
| 2 | **Countryside** | mid (tier ~1) | the Train | mobile ground + armor (explosives matter) | the Train | assembled (Train + gun-cars) |
| 3 | **City** | high (tier ~2) | flak-tower gauntlet | Pattern tier (purple) via Elites; readability | **BIG MAMA** (giant tank) | hero sprite |
| 4 | **Naval** | peak (tier ~3) | Carrier (launches air waves) | Warship archetype + multi-target weak-points | **Double Trouble** (super-bomber) | hero sprite |

Note: BIG MAMA's `.psd` is a giant *tank* (→ City, ground), Double Trouble is a twin-fuselage
*bomber* (→ Naval, air finale). Hero sprites deliberately anchor the climactic back half; L1/L2
bosses are assembled from modular weak-point parts (ADR-0009).

## Locked economy (grilled 2026-05-26)

Structure is locked in **ADR-0011**: Guns is the near-auto pace track the curve is authored against;
Armour/Engine/Bombs/gadgets are scarce slack where build choice lives. Skill→coins is a *bounded*
no-death stage bonus (combo stays score-only); supply is fixed/first-clear-only and resets every
Playthrough (clean-slate arcade); escalating prices with scaling payouts; survival-slack (Armour/Engine)
vs expression-slack (Bombs/gadgets) as a pricing principle. Exact coin/price numbers remain PRD-11's
tunable `.tres` knobs (the first module worth a test harness).

## Open / not yet grilled

- Audio direction (per-biome music mapping, adaptive layers) — PRD-16.

## Resolved this pass

- **Onboarding / FTUE** (grilled 2026-05-26 → **ADR-0013** + **PRD-17** / issue #43). Onboarding is
  invisible scenario-teaching baked into the Level-1 Stage-1 intro + self-suppressing behavioural hints
  (no tutorial, no first-run flag — competence suppresses the hint). Teaches blue-vs-orange via clean
  contrast + a failure-hint; teaches the bomb via a gifted-pickup + survivable swarm + pulsing JETT
  button; vocabulary stays **Bomb** ("Jettison" is button flavour). FTUE owns no difficulty/glyph
  machinery — it's a teaching-spec for the L1S1 timeline (PRD-14 builds it) riding on PRD-03's control
  scheme. Drag-to-move stays (ADR-0006 holds); the HUD centre rose is movement *feedback*, not a
  D-pad. Two-pass validation: PC mouse-proxy for logic now, real-phone non-gamer for feel — the latter
  **gated on PRD-19 (#44)**, so #43 stays open until a phone is in the loop. *(Side-product: cockpit-HUD
  bezel art reviewed; `CONTEXT.md` "Damage state" amended to plane + HUD gauge; HUD/dimensions notes
  parked on issue #40.)*
- **Threat-tier colour rework** (grilled 2026-05-26 → **ADR-0012**). Enemy fire already conforms to the
  locked blue/orange/purple scheme (the asset-driven commit wired the `aircrafts2` pills). The one real
  conflict was the player shot reusing the blue enemy pill; resolved by making player fire its own visual
  class (white/pale-gold, escalates by mass not hue). Implementation lands in PRD-02 (the `ThreatTier`
  module + recolouring the player pill); colour-blind palette + shape-redundancy remain deferred.

## Tracker state (2026-05-26)

The whole roadmap is now on GitHub Issues:
- **Detailed, `ready-for-agent` PRDs:** PRD-01 #26 · PRD-02 #27 · PRD-03 #28 · PRD-04 #29 · PRD-05 #30 · PRD-06 #31. (PRD-02–06 are *gap-closing refactors* — much of the engine/cast/pickups already exists; each issue states built-vs-missing.)
- **Lightweight tracking issues** (earn a full PRD + `ready-for-agent` when next-up): PRD-07 #32 · PRD-08 #36 · PRD-09 #38 · PRD-10 #33 · PRD-11 #39 · PRD-12 #34 · PRD-13 #35 · PRD-14 #37 · PRD-15+ #41 · PRD-16 #42 · PRD-17 #43 · PRD-18 #40 · PRD-19 #44 · PRD-20 #45.
- Both formerly-`needs-triage` issues are now **grilled**: #41 (Levels 2…N) and #39 (Economy, → ADR-0011).
  They can earn full `ready-for-agent` PRD detail off the locked-campaign table + ADR-0011.

## Next action

Build a `ready-for-agent` issue (#26–#31, start with #26→#27), or **detail PRD-11 (#39)** off ADR-0011
(the structure is locked; PRD-11 just needs the tunable payout/price curves + the test harness).
Remaining un-grilled open item: audio (#42). (FTUE resolved → ADR-0013 + PRD-17; threat-tier colour rework → ADR-0012.)
