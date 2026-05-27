# PRD-06 — Bombs & in-run pickups

> **Published as [issue #31](https://github.com/stanhasmusic/ocelot/issues/31)** (`ready-for-agent`) — the tracker is canonical.
> Phase 2 slice. Completes the in-run toolkit: the bomb panic-button plus the full set of pickups
> ("temporary toppings" on the permanent Hangar loadout, per
> [[0005-persistent-campaign-with-hangar-metagame]] and the `CONTEXT.md` Pickup entries).
>
> **Grounding note:** the bomb and several pickups already exist. `actors/Player.gd` implements
> `drop_bomb()`/`detonate_bomb()` (clears on-screen enemy projectiles + 100 AoE damage to on-screen
> enemies + flash), and `objects/` has `PowerUp` (weapon +1), `DiagonalGunPickup` (weapon → max),
> `RepairPickup` (+2 HP), `LifeUpPickup` (+1 life), `BombPickup` (+1 bomb). What's **missing** from
> the design's pickup set is **coin**, **wingman**, **missile**, and a **fire-pattern swap** — and
> the five existing pickups are near-duplicate Area2D scripts (fall at 100px/s, `body.name ==
> "Player"`, despawn off-screen) that should share a base. This PRD adds the missing pickups, unifies
> the base, and verifies the bomb. *(Note: the roadmap titled this slice "Bombs, flare & pickups,"
> but per [[0007-hangar-four-stat-tracks-plus-gadget-loadout]] the **Flare is a Hangar gadget, not an
> in-run pickup** — it moves to PRD-09. See Out of Scope.)*

## Problem Statement

As a player, my in-run options are thin. I have a bomb and a few power-ups, but there's no way to
**bank currency** toward upgrades (so killing things doesn't build toward anything), no **temporary
firepower** swaps to chase or **wingman** to grab for a power fantasy, and no **missile** topping for
the heavy targets that guns chip slowly. The pickups I do have each behave slightly differently in
code, so cadence and feel are inconsistent and hard to tune.

## Solution

Round out the in-run toolkit so a run has texture: keep the bomb as the panic button, and add the
missing pickups — **coins** (the currency the metagame spends), a temporary **fire-pattern swap**
(e.g. spread), a **wingman** escort that adds fire, and a **missile** topping that's strong against
heavy targets. All pickups share one base (consistent fall, attract, collect, despawn, SFX), and the
*temporary* ones are time-limited "toppings" that expire and stack predictably on top of the
permanent Hangar loadout.

## User Stories

1. As a player, I want to grab coins dropped by enemies, so my kills build toward upgrades between levels.
2. As a player, I want a clear pickup that swaps my fire to a spread/alt pattern for a while, so I get a temporary power spike to chase.
3. As a player, I want to pick up a wingman that flies with me and adds fire, so I feel a burst of power and want to protect it.
4. As a player, I want a missile pickup that's especially effective against heavy targets, so I have an answer to armoured enemies in the moment.
5. As a player, I want temporary pickups to visibly expire (and warn before they do), so I understand they're toppings, not permanent.
6. As a player, I want temporary toppings to layer on top of my permanent Hangar loadout, not overwrite it, so collecting one never makes me permanently weaker afterward.
7. As a player, I want the bomb to clear on-screen enemy fire and damage on-screen enemies, so it's a reliable "get out of jail" button. *(Exists — verify + keep.)*
8. As a player, I want to pick up extra bombs, repairs, lives, and weapon upgrades as I do today, so the existing economy of pickups is unchanged. *(Exists — keep.)*
9. As a player, I want pickups to fall at a readable speed and be easy to collect, so grabbing them is satisfying rather than fiddly.
10. As a player, I want pickups to drift toward me when I'm close (magnet), so I'm not punished for imprecise positioning. *(Magnet radius comes from PRD-03; pickups must honour it.)*
11. As a player, I want a distinct sound/visual per pickup type, so I know what I grabbed without reading text.
12. As the developer, I want all pickups to share one base (fall, attract, collect, despawn, SFX), so adding or tuning a pickup is a one-place change.
13. As the developer, I want the active temporary effects (which toppings are live and their remaining time) tracked in an isolated module, so expiry/stacking is deterministic and unit-testable.
14. As the developer, I want coin values to come from the per-archetype `coin_value` (PRD-05), so currency flow is data-driven.
15. As the developer, I want the bomb's "what's on screen" selection isolated, so the AoE/clear rule is testable without spawning a level.
16. As the developer, I want the new pickups to slot into the existing `Enemy` loot pool + the PRD-05 coin-drop hook, so spawning them needs no new drop machinery.

## Implementation Decisions

- **Unify pickups under a `PickupBase`.** Today `PowerUp`/`RepairPickup`/`LifeUpPickup`/
  `BombPickup`/`DiagonalGunPickup` each re-implement fall + `body.name == "Player"` + off-screen
  despawn. Extract a base that owns: downward fall (tunable speed), **magnet attraction** toward the
  player within `pickup_magnet_radius` (the knob from PRD-03; `0` = today's straight fall), collect
  on player overlap, pickup SFX, off-screen despawn. Each concrete pickup overrides only its
  `_apply(player)` effect. Existing pickups are re-parented onto this base with identical effects.
- **New pickups (each a `PickupBase` subtype):**
  - **Coin** — increments run currency. The actual currency store + counter is **PRD-11/PRD-07**;
    here Coin calls a `GameManager.add_coins(n)` seam (may be a stub that just accumulates a run
    total until PRD-11 formalises it). Value comes from PRD-05's `coin_value`.
  - **Fire-pattern swap** — applies a *temporary* alternate fire (e.g. spread) for a duration.
  - **Wingman** — spawns an escort that mirrors/adds player fire for a duration (or until destroyed).
  - **Missile** — grants a temporary missile shot (homing/explosive flavour), the in-run answer to
    heavy targets (the armor *math* is PRD-10; here the missile simply exists and is explosive-tagged).
- **Temporary toppings are tracked by a pure `TemporaryEffectStack` module** — the deep, testable
  piece. It records active temporary effects with remaining durations, `tick(delta)` decrements and
  expires them, exposes `active() -> Array` and `time_left(effect)`, and defines **stacking rules**
  (re-grabbing the same effect refreshes/extends rather than double-applying). The Player queries it
  each frame to decide current fire/wingman state; it holds no node references.
- **Toppings layer over the permanent loadout.** The permanent baseline (Hangar Guns tier, PRD-08)
  is the floor; the stack only *adds* temporary state and, on expiry, returns to the floor — never
  below it. (Until PRD-08 exists, the floor is today's `weapon_level`.)
- **Bomb: verify + isolate selection, don't redesign.** Keep `detonate_bomb()`'s behaviour (clear
  on-screen enemy projectiles + AoE damage on-screen enemies + flash + SFX). Lift the "which entities
  are on screen" decision into a pure `affected_by_bomb(positions, screen_rect) -> indices` helper so
  the rule is testable; the node-side stays a thin loop over the result.
- **No change** to the existing weapon/repair/life/bomb pickups' *effects* — only their base class.

## Testing Decisions

- A good test asserts **external behaviour, not implementation**: tick the effect stack and assert
  what's active and for how long; feed positions + a screen rect and assert which indices the bomb
  hits. No node instantiation.
- **`TemporaryEffectStack` tests:** adding an effect makes it active for its duration; `tick` past
  the duration expires it; re-adding an active effect refreshes/extends per the stacking rule (not
  double-stacked); multiple distinct effects coexist and expire independently; ticking an empty stack
  is a no-op.
- **`affected_by_bomb` tests:** entities inside the screen rect are selected, outside are not; on a
  boundary behaves consistently; empty input returns empty.
- **(Optional) coin accumulation** seam test if `add_coins` holds logic beyond a bare counter.
- **Prior art:** GUT `test/` layout from PRD-01–05. Add `TemporaryEffectStack` + `affected_by_bomb`
  test files in that shape.

## Out of Scope

- **The Flare** — per ADR-0007 it's an equipped **Hangar gadget**, not an in-run pickup → **PRD-09**.
  (The roadmap's slice title mentioned it; it's deliberately deferred here.)
- **Coin currency store, persistence, counter UI, and economy balancing** → **PRD-07** (persistence)
  and **PRD-11** (economy). This PRD only *drops and collects* coins via a seam.
- **Armor / explosive-damage math** that makes the missile "shred" heavy targets → **PRD-10**. Here
  the missile is explosive-*tagged* but the resistance interaction is later.
- **Pickup magnet *implementation*** (the steering + radius knob) is defined in **PRD-03**; this PRD
  consumes the knob, it doesn't build the input-assist layer.
- **Permanent firepower / Guns-tier sprite ownership** → **PRD-08**; toppings here are temporary only.
- **Final drop rates / pickup cadence tuning** — a Together playtest loop, not a code deliverable.

## Further Notes

- The current `Enemy.drop_loot` already rolls a `loot_pool` with a bomb-rarity filter; new pickups
  slot into that pool (and PRD-05's separate coin hook), so no new drop machinery is needed.
- The **wingman** is the one pickup with its own scene-side presence (an escort node); keep its
  *targeting/fire* using PRD-05's `FirePattern` helpers so it computes fire the same way enemies do.
- **Done =** coins drop from kills and are collected toward a run total; fire-pattern-swap, wingman,
  and missile pickups exist and expire as temporary toppings over the permanent loadout; all pickups
  share one base with consistent fall/magnet/collect/SFX; the bomb behaves exactly as today; and
  `TemporaryEffectStack` + `affected_by_bomb` unit tests pass under GUT.
