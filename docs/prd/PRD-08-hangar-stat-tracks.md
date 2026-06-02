# PRD-08 — Hangar: Stat Tracks

> **To be published as [issue #36](https://github.com/stanhasmusic/ocelot/issues/36)** (`ready-for-agent`) — the tracker is canonical.
> Phase 3 slice — the spend half of the metagame's earn→spend→get-stronger loop.
> Canonical design lives in `CONTEXT.md` and
> `docs/adr/0007-hangar-four-stat-tracks-plus-gadget-loadout.md`
> (four stat tracks; the **Items/gadget loadout** is the *fifth* category and is
> **PRD-09**, not this slice). Builds directly on the wallet + reserved
> `owned_tiers` slot that **PRD-07** persisted.

## Problem Statement

PRD-07 gave the Playthrough a coin wallet and reserved an `owned_tiers` slot, but
there is nowhere to **spend** coins and nothing the spend **does**. Clearing a
level banks coins (`bank_run_coins()`) and then drops the player straight into the
next level via `LevelComplete → [Next Level]`; the Airfield art sits unused; and
the player's plane is exactly as strong in Level 4 as in Level 1. The campaign's
core metagame — *get coins, get stronger, survive the rising curve*
([[0005-persistent-campaign-with-hangar-metagame]],
[[0010-absolute-difficulty-curve-with-hangar-catchup]]) — has no payoff. Worse, the
prototype-era in-run `PowerUp`/`DiagonalGunPickup` still bump `weapon_level`,
which now collides with the decision that the **permanent Guns tier** owns
firepower growth + the plane sprite (ADR-0007; flagged out-of-scope in PRD-01).

## Solution

The **Hangar**: a between-levels screen (`Airfield.png`) with four tiered-purchase
tracks — **Guns / Armour / Engine / Bombs**, each 0→3 — paid for out of the
persisted coin wallet, applied at the next level's start, and persisted across
quit/relaunch by the slot PRD-07 already round-trips. The flow becomes
**LevelComplete (results) → [To Hangar] → Hangar (spend) → [Deploy] → next level**;
results and spend stay as separate beats so "how I did" never crowds "what I buy".

Guns tier becomes the **permanent firepower floor**: it seeds `weapon_level` at
level start (and on respawn — back to the Guns floor, never 0), drives the
`lvl_0→lvl_3` plane sprite, and is the *only* firepower progression. The
prototype in-run `PowerUp`/`DiagonalGunPickup` (which bumped `weapon_level`) are
**retired** — in-run firepower variety is the PRD-06 *toppings* (fire-swap shape,
wingman, missile), and the metagame owns *power*.

Purchase + tier→effect math is **pure and isolated** from the nodes (a
`HangarUpgrades` helper with static functions, in the `SaveGame`/`CheckpointState`
mould) so it unit-tests under GUT (ADR-0004). Every effect magnitude **and** the
first-pass prices live in a tunable `HangarTunables.tres` so the curve iterates
without code — the **price** arrays are the seam **PRD-11** (#39, economy) takes
over for real balancing; PRD-08 ships only conservative placeholders so the loop
is playable.

## Design notes

- **`owned_tiers` shape (this PRD owns it).** `{ "guns": int, "armour": int,
  "engine": int, "bombs": int }`, each `0–3`. Read through a
  `GameManager.tier(track) -> int` getter that defaults missing keys to `0`, so an
  empty `{}` (fresh Playthrough / pre-PRD-08 save) needs **no migration** — it
  simply reads as all-zero. New Game already clears the slot
  (`reset_playthrough()`); this PRD adds nothing to the schema.
- **The spend seam.** `GameManager.purchase_tier(track) -> bool` is the single
  place coins leave the wallet for a tier. It delegates the decision to the pure
  `HangarUpgrades.purchase(...)`, and on success deducts coins, bumps the tier,
  `save_data()`s, and emits `on_coins_changed`. It refuses when the track is at
  tier 3 or the wallet can't afford the next tier (no debt, no over-cap).
- **The apply seam.** The plane reads its tiers **once at level start**
  (`Player._ready()` via the `GameManager.tier()` getters + `HangarTunables`), not
  continuously — buying mid-level is impossible (the Hangar only exists between
  levels), so there's no live re-apply. Respawn re-applies the same floor.
  - **Guns** → `weapon_level` floor (0–3) → existing fire-pattern + `lvl_N` sprite.
  - **Armour** → `max_hp` = base + curve (stretches the `d0→d4` budget; the
    `damage_index` clamp at 4 means tiers past the 5th HP read as extra hits at the
    `d4` sprite — exactly ADR-0007's "stretches the budget").
  - **Engine** → `max_speed` multiplier, applied to **both** movement branches
    (positional *and* velocity) so it's the accessibility dial for every input.
  - **Bombs** → starting/max bomb stock + a blast size/damage multiplier on the
    bomb action.
- **Conservative first-pass numbers** ([[feedback-feel-defaults-conservative]] — I
  propose slow, you dial up). All in `HangarTunables.tres`:
  | Tier | Guns (fire stage) | Armour (max_hp) | Engine (×speed) | Bombs (max / ×blast) | Price* |
  |------|-------------------|-----------------|-----------------|----------------------|--------|
  | 0    | 0 (base)          | 4               | 1.00            | 3 / 1.00             | —      |
  | 1    | 1                 | 5               | 1.08            | 4 / 1.15             | 60     |
  | 2    | 2                 | 6               | 1.16            | 5 / 1.30             | 100    |
  | 3    | 3                 | 7               | 1.24            | 6 / 1.45             | 160    |

  \*Prices are **placeholders owned by PRD-11** — flat per-track here; PRD-11
  replaces them with the real payout-vs-price curve + anti-grind guardrails.
- **Retiring the legacy weapon pickups (clean, bounded).** Enemies carry **two
  independent** drop systems (`actors/Enemy.gd`): the `loot_pool: Array[PackedScene]`
  (in-run pickups, 22%-rolled) and a separate always-on `coin_scene`/`coin_value`.
  Retirement = pull `PowerUp.tscn` + `DiagonalGunPickup.tscn` **out of every
  `loot_pool`** (the remaining PRD-06 toppings — Repair, LifeUp, Bomb, fire-swap,
  wingman, missile — and the coin drop stay, so drops stay meaningful), delete the
  two scenes/scripts, remove `power_up_weapon()`/`power_up_to_max()` from
  `Player.gd`, and re-point `Truck.gd`'s direct `load("…/PowerUp.tscn")` to a coin
  drop. Per [[project-archetype-scene-pattern]] the `loot_pool` edit must be made
  in **each archetype `.tscn` by hand** (Enemy.tscn is never instantiated at
  runtime) — see Files for the full list.

## User Stories

1. As a player, after clearing a level I want to visit the Hangar and spend my coins, so my plane gets stronger before the next, harder level.
2. As a player, I want to see each track's current tier, the next tier's price, and whether I can afford it at a glance, so buying is a quick, clear decision.
3. As a player, I want buying **Guns** to visibly change my plane sprite and add to my fire, so the upgrade reads as real.
4. As a player, I want buying **Armour** to let me survive more hits next level, so a tough stretch becomes beatable.
5. As a player, I want buying **Engine** to make my plane faster and easier to dodge with, so I feel more in control (and the game gets more accessible).
6. As a player, I want buying **Bombs** to raise my stock and blast, so the panic button is stronger.
7. As a player, I want a track that's maxed (tier 3) to show as maxed with no buy button, so I'm never confused about a dead-end purchase.
8. As a player, I want the game to refuse a purchase I can't afford rather than letting me go into debt, so the economy is trustworthy.
9. As a player, I want my purchased tiers to survive quitting and relaunching (via Continue), so my investment is permanent within the Playthrough.
10. As a player, I want New Game to reset all my tiers to zero, so each Playthrough is the intended weak→strong arc.
11. As a player, I want a clear **[Deploy]** action that takes me from the Hangar into the next level, so the between-levels beat has an obvious exit.
12. As a player, when I clear the **final** level I want to go to the results/menu as before (no Hangar with nothing after it), so the campaign ends cleanly.
13. As the developer, I want every tier's effect magnitude and price in a `.tres` I can edit without touching code, so the catch-up curve (ADR-0010) tunes in a tight loop.
14. As the developer, I want the purchase + tier→effect math isolated from nodes, so I can unit-test affordability, the tier cap, and effect application deterministically.
15. As the developer, I want the legacy `weapon_level` pickups gone so the permanent Guns tier is the single source of firepower growth (ADR-0007), with no second, conflicting progression.

## Implementation Decisions

- **`HangarUpgrades` (pure logic, `class_name`, no nodes).** The testable core:
  - `purchase(owned_tiers: Dictionary, coins: int, track: String, tunables) -> Dictionary`
    → `{ "ok": bool, "owned_tiers": Dictionary, "coins": int }`. Refuses at tier 3
    or when `coins < next price`; returns inputs unchanged on refusal (no mutation
    of the caller's dictionaries — returns fresh copies).
  - `price_for(track, current_tier, tunables) -> int` (−1 when maxed).
  - `max_hp_for(tier, tunables)`, `speed_mult_for(tier, tunables)`,
    `bomb_max_for(tier, tunables)`, `bomb_blast_mult_for(tier, tunables)` — the
    apply-side getters. Guns→`weapon_level` is the identity (tier *is* the fire
    stage), so it needs no curve.
- **`HangarTunables` (`Resource`/`.tres`).** Holds the four effect curves +
  per-track price arrays from the table above. Prior art: `PlayerTunables`,
  `StageConfig`.
- **`GameManager`** gains `tier(track) -> int` (defaulting getter),
  `purchase_tier(track) -> bool` (the spend seam), and applies Engine's speed
  multiplier wherever it's read. No schema change (the slot exists since PRD-07).
- **`Player.gd`** reads its tiers at `_ready()` and on `_respawn()`: seed
  `weapon_level` from Guns, `max_hp` from Armour (then restore `current_hp` to the
  new max at level start), `max_speed` ×= Engine, bomb stock/blast from Bombs.
  Remove `power_up_weapon()`/`power_up_to_max()`. `_respawn()` resets `weapon_level`
  to the **Guns floor**, not 0.
- **`Hangar.tscn` / `Hangar.gd`** — `Airfield.png` background, a coin total label
  (listens to `on_coins_changed`), four track rows (label + tier pips + price +
  Buy button), and a **[Deploy]** button → `GameManager.next_level`. Buy buttons
  disable on unaffordable/maxed; the row reflects the new tier immediately on
  purchase. Keyboard/controller focus wired like `LevelComplete` (the user
  playtests on a pad — [[project-playtest-setup]]).
- **`LevelComplete`** — when `next_level` is non-empty, the `[Next Level]` button
  becomes **[To Hangar]** routing to `Hangar.tscn`; when empty (campaign cleared)
  it routes to the menu exactly as today (no Hangar).
- **Retire** `PowerUp` + `DiagonalGunPickup` per the Design-notes recipe.

## Testing Decisions

- **Prior art:** `test/unit/test_save_game.gd`, `test_coin_banking.gd`,
  `test_checkpoint_state.gd` (PRD-07) — same GUT layout, same "assert external
  behaviour, not private state" discipline as PRD-01.
- **`HangarUpgrades.purchase` tests:** a buy increments the track and deducts the
  correct price; refused (inputs unchanged) when `coins < price`; refused at tier 3
  (cap); exactly-enough coins succeeds and floors the wallet to 0; an unknown track
  is refused; the input dictionaries are **not** mutated on refusal.
- **Tier→effect tests:** each getter returns the table value per tier and clamps
  outside `0–3`; `max_hp_for` increases monotonically; `speed_mult_for(0)==1.0`.
- **Persistence test:** buy → `save_data()` → `load_data()` round-trips
  `owned_tiers`; **New Game** zeroes all four tracks while high-score/volumes
  survive (extends the PRD-07 reset test).
- **Default/migration test:** a save with `owned_tiers == {}` reads as all-zero
  through `tier()` with no crash (the no-migration guarantee).

## Out of Scope (scope guards)

- **Items / gadget loadout** (slot+equip UI, Flare/Auto-Repair/Coin-Magnet/Spotter)
  → **PRD-09** (#38). This PRD ships only the four stat tracks.
- **Real economy balancing** — payout curve, price curve, no-death bonus,
  anti-grind, first-clear-only payout → **PRD-11** (#39). PRD-08's prices are
  conservative placeholders in the `.tres`; PRD-11 owns them.
- **Armor *damage-type* layer** (explosives-vs-armor on heavy targets, ADR-0008) →
  **PRD-10** (#33). Unrelated to the player's **Armour tier** despite the name (see
  the `CONTEXT.md` "Armor" vs "Armour tier" disambiguation).
- **Hangar art polish / final HUD** → **PRD-18** (#40). This slice uses
  `Airfield.png` + functional buttons; it need not be pretty, only clear.
- **A Hangar before Level 1** — first Hangar is after L1 clear (the weak→strong arc
  starts the player at all-zero tiers, per CONTEXT "New Game").
- **Refund / respec** — purchases are one-way within a Playthrough; New Game is the
  only reset. No respec UI.

## Acceptance criteria

- [ ] After clearing a non-final level, `LevelComplete`'s primary button reads
  **[To Hangar]** and opens the Hangar on `Airfield.png`; the Hangar's **[Deploy]**
  enters `GameManager.next_level`.
- [ ] Each of Guns/Armour/Engine/Bombs shows current tier, next-tier price, and a
  Buy button that is **disabled when unaffordable or at tier 3**.
- [ ] Buying a tier deducts the price from the wallet, bumps the tier, updates the
  row immediately, and **persists** (Continue after relaunch shows the bought
  tiers).
- [ ] **Guns** changes the plane sprite (`lvl_N`) and fire pattern next level;
  **Armour** raises hits-survived; **Engine** raises top speed on both control
  branches; **Bombs** raises stock + blast.
- [ ] A purchase is **refused** (no coin change, no tier change) when the wallet
  can't afford it or the track is maxed — no debt, no over-cap.
- [ ] **New Game** resets all four tracks to 0 (high score + volumes preserved);
  an empty `owned_tiers` reads as all-zero with no migration/crash.
- [ ] Clearing the **final** level routes to results/menu as before — no dangling
  Hangar.
- [ ] The legacy `PowerUp`/`DiagonalGunPickup` are gone: removed from every
  `loot_pool`, scenes/scripts deleted, `power_up_weapon`/`power_up_to_max` removed,
  `Truck.gd` re-pointed; the game runs and enemies still drop coins + the remaining
  PRD-06 toppings.
- [ ] GUT covers: `purchase` (success/insufficient/cap/no-mutation), tier→effect
  getters, `owned_tiers` round-trip, New-Game reset, and the empty-slot default.

## Files

- `resources/HangarTunables.gd` + `resources/HangarTunables.tres` — effect curves +
  placeholder price arrays (PRD-11's tuning surface).
- `scripts/HangarUpgrades.gd` — pure `purchase()` + `price_for()` + tier→effect
  getters (`class_name`, static).
- `scripts/GameManager.gd` — `tier(track)`, `purchase_tier(track)`, Engine speed
  application; default `owned_tiers` reads as all-zero (no schema change).
- `actors/Player.gd` — apply tiers at `_ready()`/`_respawn()` (Guns floor, Armour
  HP, Engine speed, Bombs stock/blast); remove `power_up_weapon`/`power_up_to_max`.
- `ui/Hangar.tscn` / `ui/Hangar.gd` — the Hangar screen (4 rows + coins + Deploy).
- `ui/LevelComplete.gd` — `[Next Level]` → `[To Hangar]` when a next level exists.
- `objects/PowerUp.gd` / `objects/PowerUp.tscn` (+`.uid`) — **removed**.
- `objects/DiagonalGunPickup.gd` / `objects/DiagonalGunPickup.tscn` — **removed**.
- `actors/Truck.gd` — re-point the direct `PowerUp.tscn` load to a coin drop.
- `actors/*.tscn` — drop `PowerUp.tscn`/`DiagonalGunPickup.tscn` from `loot_pool`
  in each archetype that carries them: `Enemy`, `Fighter`, `AceFighter`, `Bomber`,
  `Interceptor`, `Helicopter`, `RocketLauncher`, `Tank`, `Ship`, `EliteEscort`,
  and `Boss`/`BossL2`/`BossL3` (per [[project-archetype-scene-pattern]], by hand).
- `test/unit/test_hangar_upgrades.gd` — purchase + effect + persistence coverage.
- `test/unit/test_loot_roll.gd` — swap the `PowerUp.tscn` fixture for a surviving
  pickup (e.g. the coin or a topping scene).
