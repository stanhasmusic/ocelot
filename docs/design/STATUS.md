# Ocelot — Design Status (resume-here pointer)

Last updated: 2026-06-01. A pointer for any session picking this work back up.

## What this game is (one line)

A WWII-skinned, modern-systems top-down shmup: persistent campaign + Hangar upgrade metagame,
mobile-first + PC, built asset-first from `assets/`, for a noob/mid-tier audience.

## Canonical sources (read these first)

- **`CONTEXT.md`** — the glossary. All in-game vocabulary (threat tiers, campaign/level/stage,
  Hangar/coins/pickups, player loadout, enemy archetypes, bosses).
- **`docs/adr/0005`–`0015`** — the foundational decisions made this design pass:
  - 0005 persistent campaign + Hangar metagame *(amended by 0011: persistence is per-Playthrough, not forever)*
  - 0006 input-aware controls over one shared difficulty curve
  - 0007 Hangar = 4 stat tracks + gadget loadout
  - 0008 unified fire + armor/damage-type layer
  - 0009 destructible-weak-point + phase bosses
  - 0010 absolute difficulty curve + Hangar catch-up (skill substitutes for ~1 tier)
  - 0011 economy = Guns-spine pace track + scarce skill-fed slack, reset every Playthrough
  - 0012 player fire = its own visual class (white/pale-gold), tier escalates by mass not hue *(amends 0001)*
  - 0013 onboarding = invisible scenario-teaching + self-suppressing hints (no tutorial, no first-run state)
  - 0014 boss music = hard-swap crossfade with a leitmotif-linked track family (1 shared L1/L2 + bespoke L3/L4); adaptive layering deferred
  - 0015 SFX organised by weapon class (diegetic), not by threat tier — threat language stays visual-only
  - (pre-existing/prototype-era, take with a grain of salt: 0001 projectile colour *(amended by 0012)*,
    0002 hybrid stage difficulty, 0003 hand-authored backgrounds, 0004 defer test framework)
- **`docs/prd/ROADMAP.md`** — the build plan: 20 PRDs in 5 phases, with the human-in-the-loop split.
- **`docs/prd/PRD-01-flight-and-fire.md`** — the PRD detail-format exemplar.
- **`docs/prd/PRD-16-audio-direction.md`** — the audio direction detail (transition rules, slot table, stinger architecture, SFX taxonomy).

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

*(none — all design open items resolved this pass.)*

## Resolved this pass

- **Audio direction** (grilled 2026-05-27 → **ADR-0014** + **ADR-0015** + **PRD-16** / issue #42).
  Boss music is a **hard-swap crossfade** to a dedicated track on named-boss spawn; mini-bosses get
  no music event; music carries through death/respawn; on boss death a victory stinger fires, music
  ducks under it, then ~2s silence, then Hangar music plays through level-complete + Hangar.
  **Boss-track family = 3** (shared L1/L2 "encounter" + bespoke BIG MAMA + bespoke Double Trouble),
  all linked by a **shared melodic leitmotif** so the family reads as one idiom. **Adaptive
  layering** is the explicitly-deferred upgrade — wanted eventually, an asset-class commitment we
  don't take on for the first audio pass. **SFX organised by weapon class** (diegetic — a tank
  goes BOOM, an MG goes rat-tat-tat), not by threat tier; threat-language teaching stays
  visual-only (the colour palette, plus the eventual shape-redundancy upgrade from ADR-0012). The
  user **personally composes music** ([[user-can-author-music]]), so the **10-slot inventory**
  (menu + hangar + 4 levels + 3 boss tracks) isn't budget-constrained; 7 tracks exist, the rest are
  authored as needed. Player gun SFX escalates per Guns tier (4 distinct sounds, with "1 shared
  sound" as the playtest-fallback). Pause halts all audio and resumes exactly where it left off.
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

## Tracker state (2026-06-03)

The whole roadmap is on GitHub Issues. Build progress down the dependency spine:
- **Merged / built:** PRD-01 #26 · PRD-02 #27 · PRD-03 #28 · PRD-04 #29 · PRD-05 #30 · PRD-06 #31 · **PRD-07 #32** (two-tier save + Continue/New Game; PR #59) · **PRD-08 #36** (four stat-track Hangar between levels, Guns-tier firepower floor, legacy weapon pickups retired; PR #60) · **PRD-09 #38** (Items/gadget loadout — slots + Flare/Spotter/Magnet/Auto-Repair on the four stat tracks; PR #62). Phases 1–2 complete; Phase 3 (metagame) underway.
- **Detailed, `ready-for-agent` (built next):** PRD-16 #42 (`docs/prd/PRD-16-audio-direction.md`).
- **Lightweight tracking issues** (earn a full PRD + `ready-for-agent` when next-up): PRD-09 #38 · PRD-10 #33 · PRD-11 #39 · PRD-12 #34 · PRD-13 #35 · PRD-14 #37 · PRD-15+ #41 · PRD-17 #43 · PRD-18 #40 · PRD-19 #44 · PRD-20 #45.
- All formerly-`needs-triage` issues are **grilled**: #41 (Levels 2…N), #39 (Economy → ADR-0011), #42 (Audio → ADR-0014 + ADR-0015).

## Next action

**PRD-09 merged.** The spine continues with **PRD-11 (#39, economy)** — needs a full PRD before
`ready-for-agent`, and a design grill on the payout/price specifics (the one remaining open economy
item per #39). The plumbing is all in place: coins drop (`Coin.gd`), bank once per level
(`GameManager.bank_run_coins`), and spend through the pure `HangarUpgrades.purchase` /
`GadgetLoadout.purchase_*` seams against `HangarTunables`. **PRD-11 inherits PRD-08's placeholder
price arrays** in `resources/HangarTunables.tres` (flat `[60, 100, 160]` per track) as its tuning
surface, and adds the *payout* side (per-archetype `coin_value`, the bounded no-death clear bonus, the
Convoy faucet) — two interlocked curves that must stay in lockstep, hence the first module to earn a
test harness (ADR-0011 + ADR-0004). No un-grilled design open items remain elsewhere. (Audio →
ADR-0014 + ADR-0015 + PRD-16; FTUE → ADR-0013 + PRD-17; threat-tier colour → ADR-0012.)
