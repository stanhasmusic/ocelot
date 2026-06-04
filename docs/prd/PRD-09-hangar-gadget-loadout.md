# PRD-09 — Hangar: Gadget Loadout

> **To be published as [issue #38](https://github.com/stanhasmusic/ocelot/issues/38)** (`ready-for-agent`) — the tracker is canonical.
> Phase 3 slice — the **build-variety** half of the metagame, sitting beside the four
> stat tracks (PRD-08). Canonical design lives in `CONTEXT.md` (the **Gadget** /
> **Item** / **Flare** / **Spotter** entries) and
> `docs/adr/0007-hangar-four-stat-tracks-plus-gadget-loadout.md` (the **Items**
> category is a *gadget loadout system*, not a fifth stat bar). Builds directly on
> the Hangar screen + coin-spend seam (PRD-08) and the reserved `owned_gadgets` /
> `equipped_loadout` save slots (PRD-07).

## Problem Statement

PRD-08 made the Hangar a meaningful spend, but every purchase is a **linear stat
bump** — buy Guns/Armour/Engine/Bombs toward max and there are no *build* decisions,
just a shopping order. ADR-0007 deliberately chose the **Items** category to be a
**gadget loadout** precisely so the Hangar doesn't collapse to "buy all five to max":
the player buys a *limited* number of slots plus individual gadgets and **mixes them
to taste**, giving genuine build-crafting and a recurring reason to revisit the
Hangar ([[0005-persistent-campaign-with-hangar-metagame]]). None of that exists yet.
PRD-07 reserved `owned_gadgets` / `equipped_loadout` (empty, opaque) and PRD-06
explicitly deferred the **Flare** here as "a Hangar gadget, not an in-run pickup" —
so the slots are dug, the hook is named, and there is nothing to put in them.

## Solution

The **Gadget Loadout**: a second Hangar surface where the player spends coins on
(a) **gadget slots** — start with 1, buy up to 3 — and (b) individual **gadgets**,
then **equips** owned gadgets into the slots they can afford to run at once. Slots
are scarcer than gadgets *by design*, so which gadgets you run is a real choice, not
a checklist. The four starting gadgets each change how a run plays:

- **Flare** (defensive) — auto-fires on an otherwise-fatal hit: clears nearby enemy
  fire + brief i-frames, on a cooldown. The noob-forgiving panic-saver (smaller and
  more frequent than a bomb).
- **Auto-Repair** (sustain) — slowly regenerates plane HP while out of combat.
- **Coin Magnet** (economy) — widens the pickup-magnet radius so coins drift to you.
- **Spotter** (information) — flags incoming aimed fire with a directional indicator.
  *(Kept deliberately minimal this pass; its canonical job — revealing boss
  weak-points + telegraphing phases — is the PRD-12 upgrade we revisit then.)*

The own/equip/slot **decision math is pure and isolated** from nodes (a
`GadgetLoadout` helper with static functions, in the `HangarUpgrades` /
`CheckpointState` mould) so it unit-tests under GUT (ADR-0004). The gadget registry,
per-gadget **effect knobs**, and **prices** live in a tunable `GadgetCatalog.tres`,
so the loadout iterates without code — and, exactly as in PRD-08, the **price** arrays
are the seam **PRD-11** (#39, economy) takes over for real balancing; this PRD ships
only conservative placeholders so the loop is playable. Buying is one-way within a
Playthrough; **equipping/unequipping is free** between levels.

## Design notes

- **Save shape (this PRD owns it).** Two reserved slots get their shapes; one field
  is added:
  - `owned_gadgets: Array[String]` — gadget ids the player has bought this
    Playthrough (e.g. `["coin_magnet", "flare"]`). Order-insensitive; membership is
    what matters.
  - `equipped_loadout: Array[String]` — the subset currently slotted, length capped
    by `gadget_slots`. Reads as the loadout to apply at level start.
  - `gadget_slots: int` (**new persisted field**, default **1**) — owned slot count.
    Added to `SaveGame` with `@export var gadget_slots: int = 1`; a v2 save written
    before PRD-09 simply loads the `@export` default, so — exactly like PRD-08's
    `owned_tiers` — there is **no migration and no `SCHEMA_VERSION` bump**.
    `reset_playthrough()` sets it back to 1 (New Game → 1 slot, no gadgets).
- **The buy seams (coins leave the wallet here, nowhere else).**
  - `GameManager.purchase_gadget(id) -> bool` — delegates to
    `GadgetLoadout.purchase_gadget(...)`; on success deducts the price, adds the id
    to `owned_gadgets`, `save_data()`s, emits `on_coins_changed`. Refuses an unknown
    id, an already-owned id, or an unaffordable price (no debt, no double-buy).
  - `GameManager.purchase_gadget_slot() -> bool` — same shape for the next slot;
    refuses at `MAX_SLOTS` (3) or when unaffordable.
- **The equip seams (free, between levels only).**
  - `GameManager.equip_gadget(id) -> bool` / `unequip_gadget(id) -> bool` — mutate
    `equipped_loadout` and `save_data()`. `equip` refuses an unowned id, an
    already-equipped id, or a full loadout (`len(equipped_loadout) >= gadget_slots`).
    Buying a smaller slot count is impossible (slots only grow), so an over-cap
    loadout can never arise.
- **The apply seam.** The plane reads `equipped_loadout` **once at level start**
  (`Player._ready()`, beside the PRD-08 tier read) into a cached `_equipped` set —
  the Hangar only exists between levels, so there is no live re-equip. Each gadget is
  a thin, isolated behaviour gated on membership in that set:
  - **Flare** → in `take_damage()`, when an incoming hit would be fatal
    (`current_hp - amount <= 0`) and the flare cooldown is ready, **consume the
    cooldown instead of dying**: negate the lethal hit, clear enemy projectiles within
    `flare_radius` of the plane, grant `flare_iframes` of invincibility. **Auto-trigger
    only** this pass (no new input binding — keeps mobile clean; manual activation is a
    later knob). Reuses the bomb's projectile-clear machinery via a new *radius* variant
    (see below).
  - **Auto-Repair** → a regen clock in `_physics_process`: after `repair_grace_seconds`
    with no damage taken, tick `repair_amount` HP every `repair_interval_seconds` up to
    `max_hp` (via the existing `repair_health()`), re-armed by any hit.
  - **Coin Magnet** → `current_magnet_radius()` adds `magnet_bonus_px` when equipped,
    so pickups (which already query that getter, PRD-06) drift from farther out.
  - **Spotter** → a lightweight indicator that points to the source when an aimed shot
    is inbound within `spotter_lead_seconds`. Kept minimal on purpose — no enemy-highlight
    or weak-point/phase reveal yet (revisited in PRD-12, which gives it a real job).
- **One new pure helper for Flare.** `BombTargeting` already owns the testable
  "what's in range" decision for the bomb; add a sibling
  `within_radius(positions: Array, center: Vector2, radius: float) -> Array` (indices
  of positions inside the circle). The bomb stays whole-screen; the Flare is the
  *nearby* clear. Pure, no nodes — tests alongside `affected_by_bomb`.
- **Slots are scarcer than gadgets (the whole point).** Four gadgets ownable, 1–3
  slots runnable, so the player picks an identity (turtle = Flare + Auto-Repair;
  greed = Coin Magnet + Spotter) rather than running everything. ADR-0007's warning
  ("resist shipping a loadout screen with only one meaningful choice") is met by
  starting at 1 slot but making slot 2 an early, affordable goal.
- **Conservative first-pass numbers** ([[feedback-feel-defaults-conservative]] — I
  propose slow/cheap-to-survive, you dial up). All in `GadgetCatalog.tres`:

  | Slot | Price* |
  |------|--------|
  | 1 (owned at start) | — |
  | 2 | 120 |
  | 3 | 220 |

  | Gadget | Price* | Effect knobs (first pass) |
  |--------|--------|---------------------------|
  | **Coin Magnet** | 70  | `magnet_bonus_px = 160` (≈ doubles a typical assist radius) |
  | **Flare**       | 90  | `flare_cooldown_seconds = 12`, `flare_radius = 220`, `flare_iframes = 1.0` |
  | **Spotter**     | 90  | `spotter_lead_seconds = 0.6` (inbound-aimed indicator only) |
  | **Auto-Repair** | 110 | `repair_grace_seconds = 5`, `repair_interval_seconds = 8`, `repair_amount = 1` |

  \*Prices are **placeholders owned by PRD-11** — flat here; PRD-11 replaces them
  with the real payout-vs-price curve + anti-grind guardrails (gadgets/slots are
  *expression-slack*, [[0011-economy-guns-spine-plus-scarce-skill-slack]]).

## User Stories

1. As a player, after clearing a level I want to open a Loadout screen from the Hangar and spend coins on gadgets, so my plane gains abilities, not just bigger stats.
2. As a player, I want to buy extra gadget slots, so I can run more gadgets at once as my Playthrough goes on.
3. As a player, I want to equip and unequip owned gadgets freely between levels, so I can retune my build for the level ahead without re-buying.
4. As a player, I want the screen to show which slots are open, which are filled, and which aren't bought yet, so my capacity is obvious at a glance.
5. As a player, I want **Flare** to auto-save me from an otherwise-fatal hit by clearing nearby fire, so a single mistake isn't instant death.
6. As a player, I want **Auto-Repair** to slowly heal my plane when I'm not being shot, so surviving a rough patch is rewarded.
7. As a player, I want **Coin Magnet** to pull coins toward me, so I bank more currency for upgrades.
8. As a player, I want **Spotter** to warn me about incoming aimed fire, so I read a busy screen more easily.
9. As a player, I want to be stopped from equipping more gadgets than I have slots for, so the loadout is an honest choice.
10. As a player, I want the game to refuse a gadget or slot I can't afford rather than going into debt, so the economy is trustworthy.
11. As a player, I want a gadget I already own to show as owned (equip, not buy again), so I never waste coins double-buying.
12. As a player, I want my owned gadgets, slot count, and equipped loadout to survive quitting and relaunching (via Continue), so my build is permanent within the Playthrough.
13. As a player, I want New Game to reset me to 1 slot and no gadgets, so each Playthrough rebuilds from scratch (the weak→strong arc).
14. As a player, I want a clear way back from the Loadout screen to the Hangar (and Deploy), so the between-levels beat still has an obvious exit.
15. As the developer, I want every gadget's price and effect magnitude in a `.tres` I can edit without touching code, so build feel + the catch-up curve (ADR-0010) tune in a tight loop.
16. As the developer, I want the own/equip/slot math isolated from nodes, so I can unit-test affordability, the slot cap, double-buy/double-equip refusal, and reset deterministically.
17. As the developer, I want each gadget's in-run behaviour gated on a single cached "equipped" read at level start, so the game has no live-loadout machinery and a gadget is a self-contained, deletable behaviour.

## Implementation Decisions

- **`GadgetLoadout` (pure logic, `class_name`, no nodes).** The testable core, parallel
  to `HangarUpgrades`:
  - `const STARTING_SLOTS := 1`, `const MAX_SLOTS := 3`.
  - `owns(owned_gadgets, id) -> bool`, `is_equipped(equipped_loadout, id) -> bool`.
  - `gadget_price(id, catalog) -> int` (−1 unknown), `slot_price(current_slots, catalog) -> int` (−1 at `MAX_SLOTS`).
  - `purchase_gadget(owned_gadgets, coins, id, catalog) -> { ok, owned_gadgets, coins }`
    — refuses unknown / already-owned / unaffordable; returns **fresh copies**, inputs
    untouched on refusal.
  - `purchase_slot(slots, coins, catalog) -> { ok, slots, coins }` — refuses at cap /
    unaffordable.
  - `equip(equipped_loadout, owned_gadgets, slots, id) -> { ok, equipped_loadout }` —
    refuses unowned / already-equipped / full (`len >= slots`); fresh copy.
  - `unequip(equipped_loadout, id) -> Array` — id removed (no-op if absent), fresh copy.
- **`GadgetCatalog` (`Resource`/`.tres`).** The registry + knobs + prices: parallel
  arrays `gadget_ids` / `gadget_names` / `gadget_descriptions` / `gadget_prices`, the
  `slot_prices` array, and the per-gadget effect knobs from the table. Prior art:
  `HangarTunables`, `PlayerTunables`. A `knob(id, name)` accessor (or typed fields)
  keeps `Player` reads tidy.
- **`GameManager`** gains `gadget_slots: int` (persisted + reset), the four seams
  (`purchase_gadget`, `purchase_gadget_slot`, `equip_gadget`, `unequip_gadget`), and
  read helpers (`owns_gadget`, `is_equipped`). `save_data()` / `load_data()` round-trip
  `gadget_slots` alongside the existing `owned_gadgets` / `equipped_loadout`. No
  `SCHEMA_VERSION` change (new field defaults; see Design notes).
- **`Player.gd`** caches `_equipped` at `_ready()` (beside `_apply_hangar_tiers()`),
  then runs each gadget behaviour gated on membership: Flare in `take_damage()` +
  a cooldown timer; Auto-Repair regen clock in `_physics_process`; Coin Magnet in
  `current_magnet_radius()`; Spotter overlay. Each behaviour is a small private block
  that no-ops when its gadget isn't equipped.
- **`BombTargeting`** gains `within_radius(positions, center, radius) -> Array` for the
  Flare nearby-clear (the bomb keeps `affected_by_bomb` / whole-screen).
- **`Hangar.tscn` / `Hangar.gd`** — add a **[Loadout]** button (between the tracks and
  Deploy) routing to `GadgetLoadout.tscn`. Deploy stays on the Hangar.
- **`GadgetLoadout.tscn` / `GadgetLoadout.gd`** — the new screen: a coin total
  (listens to `on_coins_changed`), a **slots strip** (filled / open / locked pips + a
  Buy-Slot button showing price or `MAX`), a **gadget list** (each row: name + short
  desc + a state-aware action — `[Buy <price>]` when unowned, `[Equip]` /
  `[Equipped ✓]`→unequip when owned, Equip disabled when no free slot), and a
  **[Back]** to the Hangar. Built **responsive to the 540 px (9:16) viewport** — name/desc
  takes the slack (`SIZE_EXPAND_FILL`), the action column stays compact-fixed — per
  [[feedback-menus-fit-viewport]]. Keyboard/controller focus wired like Hangar /
  LevelComplete (the user playtests on a pad — [[project-playtest-setup]]).
- **`SpotterOverlay`** — a small `Control`/`Node2D` the Player adds when Spotter is
  equipped: draws the inbound-aimed indicator only. Self-contained so the PRD-12
  enemy-highlight + weak-point upgrade is purely additive.

## Testing Decisions

- **Prior art:** `test/unit/test_hangar_upgrades.gd` (the purchase/cap/no-mutation
  discipline to mirror), `test_save_game.gd` / `test_continue_resume.gd` (round-trip +
  reset), `test_affected_by_bomb.gd` (the `BombTargeting` test shape). Same "assert
  external behaviour, not private state" rule as PRD-01.
- **`GadgetLoadout` tests:** buying a gadget adds it + deducts the price; refused
  (inputs unchanged) when unaffordable, when already owned, or for an unknown id;
  buying a slot increments + deducts; refused at `MAX_SLOTS` (3); equip adds to the
  loadout and refuses unowned / already-equipped / full (`len >= slots`); unequip
  removes (no-op when absent); the input arrays are **not mutated** on any refusal.
- **`BombTargeting.within_radius` tests:** positions inside the circle are selected,
  outside are not; on the boundary behaves consistently; empty input → empty.
- **Persistence test:** buy a slot + buy + equip a gadget → `save_data()` →
  `load_data()` round-trips `gadget_slots` / `owned_gadgets` / `equipped_loadout`;
  **New Game** resets to 1 slot + empty gadgets/loadout while high-score/volumes
  survive (extends the PRD-07/08 reset test).
- **Default/migration test:** a save with no `gadget_slots` field and empty
  `owned_gadgets`/`equipped_loadout` loads as 1 slot / nothing owned / nothing equipped
  with no crash (the no-migration guarantee).
- **(Optional) Auto-Repair clock:** if the regen tick is factored into a small pure
  helper, test that it heals only after the grace window and never past `max_hp`.

## Out of Scope (scope guards)

- **Spotter's enemy-highlight + weak-point / phase reveal** — kept out to keep this pass
  simple; the weak-point reveal depends on the destructible-weak-point boss system →
  **PRD-12** (#34, [[0009-destructible-weakpoint-phase-bosses]]), where we revisit
  Spotter's full read. This PRD ships only the inbound-aimed indicator; the highlight +
  weak-point overlay is an additive upgrade on the same gadget.
- **More gadgets** (Decoy, etc.) — the catalog starts at four; ADR-0007 wants the set to
  **grow** later. Adding one is a `GadgetCatalog.tres` entry + a behaviour block.
- **Manual Flare activation / a new input binding** — auto-trigger only this pass (keeps
  mobile input untouched). Manual-on-cooldown is a later knob.
- **Real economy balancing** — gadget + slot price curves, payout tuning, anti-grind →
  **PRD-11** (#39). The placeholders here are conservative; PRD-11 owns them (gadgets =
  expression-slack per ADR-0011).
- **In-run HUD indicators for gadgets** (Flare-ready icon, Auto-Repair pulse, equipped
  strip) → **PRD-18** (#40, HUD & menus). This PRD's gadgets act; the HUD readout is
  later. The Loadout screen itself uses `Airfield`-era functional layout, not final art.
- **Armor / explosive-damage math** (the missile/bomb-vs-armor interaction) → **PRD-10**
  (#33). Unrelated to gadgets.
- **Refund / respec of *purchases*** — buying a gadget or slot is one-way within a
  Playthrough; New Game is the only reset. (Equip/unequip is free and unlimited — only
  *buying* is permanent.)

## Acceptance criteria

- [ ] The Hangar has a **[Loadout]** button that opens the Gadget Loadout screen on the
  540×960 viewport (nothing clipped); **[Back]** returns to the Hangar, and Deploy still
  enters `GameManager.next_level`.
- [ ] The screen shows the coin total, a slots strip (owned/open/locked), and a row per
  gadget with its name, a short description, and a state-aware action (Buy with price
  when unowned; Equip / Equipped→unequip when owned).
- [ ] Buying a **slot** deducts its price and raises capacity (1 → up to 3); buying a
  **gadget** deducts its price and marks it owned; both update the screen immediately and
  **persist** (Continue after relaunch shows them).
- [ ] Equipping is **free** and refused when no slot is free, when already equipped, or
  when unowned; unequipping frees a slot. The equipped count never exceeds `gadget_slots`.
- [ ] A purchase is **refused** (no coin change, no state change) when unaffordable, when
  the gadget is already owned, or when slots are maxed — no debt, no double-buy, no
  over-cap.
- [ ] Each gadget measurably changes a run: **Flare** auto-saves an otherwise-fatal hit
  (clears nearby fire + i-frames, then goes on cooldown); **Auto-Repair** heals HP while
  out of combat; **Coin Magnet** widens coin pickup; **Spotter** flags inbound aimed fire.
- [ ] **New Game** resets to 1 slot, no owned gadgets, empty loadout (high score +
  volumes preserved); a save lacking the new field reads as 1 slot with no
  migration/crash.
- [ ] GUT covers: `GadgetLoadout` (gadget/slot purchase success/insufficient/already-
  owned/cap, equip/unequip incl. full-loadout refusal, no-mutation), `within_radius`,
  the slot/gadget/loadout round-trip, and the New-Game reset + empty-slot default.

## Files

- `scripts/GadgetLoadout.gd` — pure own/equip/slot math (`class_name`, static).
- `resources/GadgetCatalog.gd` + `resources/GadgetCatalog.tres` — gadget registry +
  per-gadget effect knobs + placeholder gadget/slot prices (PRD-11's tuning surface).
- `scripts/SaveGame.gd` — add `@export var gadget_slots: int = 1`; `reset_playthrough()`
  resets it to 1 (no `SCHEMA_VERSION` bump — defaulted field, no migration).
- `scripts/GameManager.gd` — `gadget_slots` var (persisted + reset), `purchase_gadget`,
  `purchase_gadget_slot`, `equip_gadget`, `unequip_gadget`, `owns_gadget`, `is_equipped`;
  round-trip `gadget_slots` in `save_data`/`load_data`.
- `actors/Player.gd` — cache `_equipped` at `_ready()`; Flare (auto-trigger in
  `take_damage` + cooldown + radius clear), Auto-Repair (regen clock), Coin Magnet
  (augment `current_magnet_radius`), Spotter (overlay).
- `scripts/BombTargeting.gd` — add pure `within_radius(positions, center, radius)`.
- `ui/Hangar.tscn` / `ui/Hangar.gd` — add the `[Loadout]` button → `GadgetLoadout.tscn`.
- `ui/GadgetLoadout.tscn` / `ui/GadgetLoadout.gd` — the loadout screen (slots strip +
  gadget rows + Back), responsive to 540 px.
- `scripts/SpotterOverlay.gd` (+ scene if needed) — Spotter's inbound-aimed indicator
  (PRD-12 adds enemy-highlight + weak-point reveal here later).
- `test/unit/test_gadget_loadout.gd` — purchase/equip/slot + persistence + reset coverage.
- `test/unit/test_affected_by_bomb.gd` — add `within_radius` cases (or a sibling
  `test_within_radius.gd`).
</content>
</invoke>
