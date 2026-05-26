# Ocelot — Design Status (resume-here pointer)

Last updated: 2026-05-26. A pointer for any session picking this work back up.

## What this game is (one line)

A WWII-skinned, modern-systems top-down shmup: persistent campaign + Hangar upgrade metagame,
mobile-first + PC, built asset-first from `assets/`, for a noob/mid-tier audience.

## Canonical sources (read these first)

- **`CONTEXT.md`** — the glossary. All in-game vocabulary (threat tiers, campaign/level/stage,
  Hangar/coins/pickups, player loadout, enemy archetypes, bosses).
- **`docs/adr/0005`–`0009`** — the foundational decisions made this design pass:
  - 0005 persistent campaign + Hangar metagame
  - 0006 input-aware controls over one shared difficulty curve
  - 0007 Hangar = 4 stat tracks + gadget loadout
  - 0008 unified fire + armor/damage-type layer
  - 0009 destructible-weak-point + phase bosses
  - (pre-existing: 0001 projectile colour, 0002 hybrid stage difficulty, 0003 hand-authored
    backgrounds, 0004 defer test framework)
- **`docs/prd/ROADMAP.md`** — the build plan: 20 PRDs in 5 phases, with the human-in-the-loop split.
- **`docs/prd/PRD-01-flight-and-fire.md`** — the PRD detail-format exemplar.

## Locked design pillars

1. WWII skin, modern systems (mobile-first + PC)
2. Persistent campaign + Hangar metagame; death → checkpoint
3. Level = biome theater (3 stages, checkpoints); Hangar between levels
4. Drag/positional + auto-fire; auto-swap to velocity on pad/kbd; one shared difficulty curve + assists
5. Plane-as-HP (d0→d4) + lives cushion
6. Permanent Guns tier owns the plane sprite; pickups are temporary toppings
7. Hangar = Guns/Armour/Engine/Bombs tracks + Items gadget loadout
8. Unified fire + armor/damage-type layer (explosives bonus vs armor)
9. 8 enemy archetypes + a signature enemy per level; elites = lone non-boss pattern user
10. Destructible-weak-point bosses with telegraphed phases

## Open / not yet grilled

- Economy specifics (coin payouts vs prices) — framed in ADR-0005, detailed in PRD-11.
- Full level list / order / difficulty arc (have: Pacific Beachhead, Countryside, City).
- Audio direction (per-biome music mapping, adaptive layers) — PRD-16.
- Onboarding / first-time-user experience — PRD-17.
- Named-boss identities beyond the BIG MAMA / Double Trouble sketches.

## Next action

Either start building **PRD-01**, or grill one of the open items above before structuring its PRD.
