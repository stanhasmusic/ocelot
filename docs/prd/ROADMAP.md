# Ocelot — PRD Roadmap & Human-in-the-Loop Split

This is the build plan: the design decided in `CONTEXT.md` + ADRs 0005–0009, sliced into
independently-buildable PRDs and ordered so something is **playable as early as possible**.

## How to read this

- Each PRD is a **vertical slice** — it ends in something you can run and feel, not a layer of
  plumbing with nothing to see.
- Ordered by the **tracer-bullet principle**: get a thin, end-to-end playable shmup first, then
  thicken it. You should be flying and dying by the end of Phase 1.
- The canonical design lives in `CONTEXT.md` + `docs/adr/`. **PRDs implement those decisions; they
  don't re-litigate them.** If a PRD wants to change a locked decision, that's a new ADR first.
- Each PRD below lists: **Goal**, **Depends on**, the **HITL split** (You / I / Together), and
  **Done =** (the demoable outcome).

## The one operating principle behind the whole split

The single thing an AI building a game cannot do is **feel** it. So every task sorts by one rule:

> **Feel, taste, and play-sensation are yours. Construction is mine. And every feel-dependent value
> is exposed as a tunable `.tres` knob, so your iteration loop never requires me to touch code.**

**You own (recurring, every phase):**
- **Backgrounds** — author/approve the hand-authored scrolling backgrounds and landmark placement
  per level ([[0003-hand-authored-backgrounds]]). The largest art commitment; it's yours.
- **Playtest & feel** — you are the validation loop. Pacing, difficulty, juice, readability,
  "does this feel good." You play on PC (controller + mouse/kbd); treat **mouse as the touch proxy**,
  and get a phone into the loop before any mobile-specific sign-off (see [[project-playtest-setup]]).
- **Audio curation** — which of the 7 tracks plays where, which SFX maps to what. Taste calls.
- **Sprite-variant taste** — when the library offers many options (which aircraft = which archetype,
  which explosion reads best), you choose.
- **Final balance sign-off** — I propose numbers; you decide when they feel right.

**I build (recurring, every phase):**
- All code, systems, scene wiring, state machines, save/load.
- **Asset integration** — importing, slicing the sprite sheets via their `.json`, building
  `SpriteFrames`/`AnimatedSprite` from the prop/explosion/ripple frame sets.
- **First-pass numbers** (spawn rates, prices, HP, payouts) delivered as **tunable resources** so you
  can adjust without me.
- Boss/phase/weak-point scripting; enemy behaviors; tests for logic-heavy modules.

**Together:**
- Difficulty calibration and boss attack patterns — I build + expose knobs, you playtest + call the
  adjustment, repeat until it feels right.

---

## Phase 1 — Playable Core (the tracer bullet)

Goal of the phase: **a losable 60-second shmup loop.** Fly, shoot, kill something, get hit, see your
plane take damage, die. Everything else in the game hangs off this skeleton.

### PRD-01 — Flight & Fire
- **Goal:** P-38 moves under positional drag (finger/mouse → target point, high speed cap) and
  auto-fires the player shot upward. Placeholder scrolling background so motion reads.
- **Depends on:** nothing (first slice).
- **You:** confirm base movement speed + fire cadence *feel* right (first knob-tuning loop).
- **I:** player controller (positional path), auto-fire, player-shot projectile, a scrolling
  background stub, wire the P-38 `lvl_0_d0` sprite + prop animation.
- **Done =** you can fly the plane around the screen with your mouse and watch it shoot.

### PRD-02 — Threats & Survival
- **Goal:** readable incoming fire + the plane-as-HP model.
- **Depends on:** PRD-01.
- **You:** sanity-check that blue (straight) vs orange (aimed) read clearly at a glance.
- **I:** enemy projectile types in threat-tier colors ([[0001-projectile-colour-by-threat-tier]]),
  one **Strafer** firing straight-tier, plane-as-HP via `d0→d4` sprite swap, lives cushion +
  respawn-in-place, a checkpoint stub.
- **Done =** a Strafer shoots at you, you take hits, the plane visibly degrades, you lose a life,
  respawn, and eventually die. **The loop is real.**

---

## Phase 2 — The Shmup Loop

Goal: **one complete, hand-crafted Stage** — intro that teaches, procedural body, checkpoint, the full
enemy cast, bombs and pickups.

### PRD-03 — Input-aware controls
- **Goal:** the auto-swapping control layer ([[0006-input-aware-controls-shared-difficulty]]).
- **Depends on:** PRD-01.
- **You:** feel-test the gamepad (velocity) path against the mouse (positional) path; call the
  per-input assist values.
- **I:** device detection, velocity movement model, assist knobs (snap, magnet, hitbox), touch-button
  + prompt-glyph swap.
- **Done =** picking up a controller mid-game seamlessly swaps the scheme and HUD.

### PRD-04 — Stage engine
- **Goal:** the hybrid scripted-intro + procedural-body spawner ([[0002-hybrid-stage-difficulty]]).
- **Depends on:** PRD-02.
- **You:** pace-test the intro timeline; tune the spawn-table knobs (`.tres`).
- **I:** stage-intro timeline player, weighted spawn-table procedural body, checkpoints, stage→stage
  flow, boss trigger hook.
- **Done =** a stage runs intro → procedural body → (boss placeholder), with a working checkpoint.

### PRD-05 — Enemy archetype kit
- **Goal:** the 8 reskinnable archetypes feeding the spawn tables.
- **Depends on:** PRD-04.
- **You:** pick which art variant skins each archetype per biome.
- **I:** Strafer, Diver, Gunship, Emplacement, Tank, Convoy, Warship, Elite as reusable units with
  threat-tier-correct fire; coin drops.
- **Done =** spawn tables can mix all 8; each behaves distinctly.

### PRD-06 — Bombs, flare & pickups
- **Goal:** the in-run toolkit.
- **Depends on:** PRD-02, PRD-05.
- **You:** feel-test bomb impact + pickup cadence.
- **I:** bomb action (clear projectiles + AoE), in-run pickups (fire-pattern swap, wingman, missile,
  repair, life_up, coin, bomb pickup).
- **Done =** you can grab a spread-fire pickup + a wingman, bank coins, and panic-bomb a swarm.

---

## Phase 3 — The Metagame

Goal: **the earn → spend → get-stronger loop** across more than one level.

### PRD-07 — Save & campaign progression
- **Depends on:** PRD-04.
- **You:** —
- **I:** persistent save (progress, coins, owned tiers, owned gadgets, equipped loadout), level-select,
  checkpoint persistence.
- **Done =** quit and relaunch; your progress, coins, and upgrades are intact.

### PRD-08 — Hangar: stat tracks
- **Depends on:** PRD-07. **Design:** [[0007-hangar-four-stat-tracks-plus-gadget-loadout]].
- **You:** taste-check the Hangar screen against the `upgrade_screen` art; sign off tier feel.
- **I:** Guns/Armour/Engine/Bombs tiers, coin spend, Guns-tier → plane-sprite swap, Armour → HP,
  Engine → speed, Bombs → capacity.
- **Done =** spend coins between levels and your plane is visibly + mechanically stronger next level.

### PRD-09 — Hangar: gadget loadout
- **Depends on:** PRD-08.
- **You:** decide the starting gadget set + slot count feel.
- **I:** slot/equip UI, Flare, Auto-Repair, Coin Magnet, Spotter (start with ~4).
- **Done =** equip a loadout that measurably changes how a run plays.

### PRD-10 — Combat depth: armor / damage types
- **Depends on:** PRD-05, PRD-06. **Design:** [[0008-unified-fire-no-air-ground-split]].
- **You:** feel-test that gun-only grind is *tedious-but-possible*, not a wall.
- **I:** armor value on heavy targets (gun-damage reduction + explosive bonus).
- **Done =** missiles/bombs visibly shred a bunker that your guns only chip.

### PRD-11 — Economy
- **Depends on:** PRD-08. **Design:** flagged first-class in [[0005-persistent-campaign-with-hangar-metagame]].
- **You:** **own the sign-off** — does progression feel earned, not grindy?
- **I:** coin payout curve vs upgrade prices as one tunable table; anti-grind guardrails. Likely the
  **first module worth a test harness** ([[0004-defer-test-framework-until-first-testable-module]]).
- **Done =** a player buying sensibly can afford the tier each level expects (no grind wall).

---

## Phase 4 — Set-pieces & Content

Goal: **at least one complete named-boss level**, then a repeatable template for the rest.

### PRD-12 — Boss & mini-boss system
- **Depends on:** PRD-05. **Design:** [[0009-destructible-weakpoint-phase-bosses]].
- **You:** feel-test telegraph timing (Spotter should be bonus, not required).
- **I:** weak-point/part system (per-part HP/armor/destroyed-art swap), phase state-machine, boss-health
  signals, mini-boss (single-heavy) variant.
- **Done =** a multi-part boss loses turrets, shifts phases, and dies.

### PRD-13 — Signature enemies
- **Depends on:** PRD-05.
- **You:** —
- **I:** the Train (Countryside set-piece), Kamikaze wing (Pacific), flak-tower gauntlet (City).
- **Done =** each is introduced cleanly in its stage intro.

### PRD-14 — Level Content Template + Level 1 (Pacific Beachhead)
- **Depends on:** PRD-04, PRD-05, PRD-12, PRD-13. **The repeatable "build a level" PRD.**
- **You:** **author the background + landmark placement** ([[0003-hand-authored-backgrounds]]); pick
  music; playtest pacing end-to-end.
- **I:** assemble 3 stages (intros + spawn tables), 2 mini-bosses, signature enemy, and the named boss
  (e.g. BIG MAMA) into a complete playable level.
- **Done =** Level 1 is beatable start-to-boss and *feels* like a place.

### PRD-15…N — Levels 2…N (clone the template)
- **Depends on:** PRD-14.
- Countryside (Double Trouble + the Train), City (flak gauntlet), etc. One PRD per level, same shape.

---

## Phase 5 — Polish & Reach

Goal: **a shippable vertical slice.**

- **PRD-16 — Audio direction:** per-biome music mapping, adaptive layers / boss stingers, full SFX
  mapping. *(You own curation; the Game Audio Engineer agent can help.)*
- **PRD-17 — Onboarding / FTUE:** the non-gamer's first 60 seconds, tutorialization, difficulty easing.
  *(You own validation — this is the make-or-break for the [[project-ocelot-target-audience]].)*
- **PRD-18 — HUD & menus:** `game_hud`, level select, pause, options, level-complete screen.
- **PRD-19 — Mobile reach:** touch build, on-screen controls, the **first real phone validation pass**,
  per-input assist tuning. *(Closes the [[project-playtest-setup]] gap.)*
- **PRD-20 — Juice & game-feel:** screenshake, hit-stop, explosion/muzzle/impact polish. *(You own taste.)*

---

## Dependency spine (the critical path to "playable")

```
PRD-01 → PRD-02 → PRD-04 → PRD-05 → PRD-12 → PRD-14 (first full level)
                    │         │
                    │         └→ PRD-06, PRD-10, PRD-13
                    └→ PRD-07 → PRD-08 → PRD-09, PRD-11
PRD-03 hangs off PRD-01 (can land any time after).
Phase 5 polish hangs off the content existing.
```

## Notes
- These PRDs are written as repo docs. If you want them as trackable, independently-grabbable tickets,
  the `to-issues` skill converts this roadmap into GitHub issues using the same vertical slices.
- Each PRD should get its own `docs/prd/PRD-NN-*.md` with full detail when it's picked up; see
  `PRD-01-flight-and-fire.md` for the format.
