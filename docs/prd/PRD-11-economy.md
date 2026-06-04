# PRD-11 — Economy

> **To be published as [issue #39](https://github.com/stanhasmusic/ocelot/issues/39)** (`ready-for-agent`) — the tracker is canonical.
> Phase 3 slice — the **earn** half of the metagame's earn→spend→get-stronger loop (PRD-08 built the spend half).
> Canonical design lives in `CONTEXT.md` and `docs/adr/0011-economy-guns-spine-scarce-skill-fed-slack.md`
> (**amended 2026-06-03** by the grill this PRD comes from — read the amendment first).
> The **price** side already exists as PRD-08/09 placeholders; this PRD owns the **payout** side and the
> real per-track price curve. Numbers were grilled and seeded into
> `resources/EconomyTunables.tres`, `resources/HangarTunables.tres`, `resources/GadgetCatalog.tres`.

## Problem Statement

The Hangar can spend coins (PRD-08/09) and levels drop coins (PRD-06), but the **economy that connects them is
unbalanced and exploitable**. Three concrete failures:

1. **No payout design.** Coins come only from per-kill drops, which the player may never collect (coins fall
   off-screen; mobile drag-to-move can't always reach them; no Coin Magnet early). So the **Guns spine itself can
   under-fund** — a death-prone or poor-collecting player (the median of the noob/mid-tier audience; confirmed by
   playtest — the developer has never completed a deathless run) can fail to afford the firepower the difficulty
   curve assumes (ADR-0010). The prices are flat placeholders unconnected to any income.
2. **No anti-grind guard — and the glossary is already lying.** `CONTEXT.md` states *"each level pays its coins
   only on first clear within a Playthrough (no farming by replay)"*, but `GameManager.level_complete()` banks
   `run_coins` **unconditionally**, and `LevelComplete` has a **[Play Again]** button — so a player can farm Level 1
   indefinitely. The code must catch up to the locked vocabulary.
3. **No purpose for terminal coins.** There is no Hangar after the L4 finale, so all coins earned on L4 (and any
   unspent earlier) are stranded with no use.

## Solution

A balanced two-curve economy — **payout and price in lockstep** — built on the Guns spine and two *bounded,
audience-aware* skill faucets, with first-clear gating and a terminal coins→score cash-out. From the player's view:

- **The Guns spine is guaranteed.** Base income is a **floor topped up at level-complete**: collect what you can
  during the level, and if you finish below the level's floor you're topped up to it. Even a no-collect,
  die-every-level run affords **Guns 0→3** (60/100/160 = 320 across the 3 Hangar visits). *Missing coins costs
  slack, never Guns.*
- **Two ways to earn slack, so everyone has a faucet they can turn:**
  - **No-death bonus** (the *survival* faucet) — a per-level bonus for clearing a level without dying. Per-level, so
    a run that dies in L3 still banks L1+L2 if those were clean.
  - **Collection** (the *engagement* faucet) — coins collected *above* the floor are kept as slack. Earnable **even
    on a messy run** (you collect before you die), which is how a shaky player gets coin-rich enough to buy
    survivability (ADR-0011's promised catch-up). The **Coin Magnet** amplifies the fraction you realize; the
    **Convoy** is the high-variance, risk/reward spike inside this faucet.
- **First-clear only.** Each level pays once per Playthrough; replays bank nothing (kills/score still work). No farm.
- **Terminal mop-up.** On campaign completion every *unspent* coin converts to a one-time score bonus — the arcade
  end-of-run cash-out — so L4 coins and any surplus still count, for ranking.

The whole budget lives in tunable `.tres` so it iterates without code, with the **no-death / collection split** and
the **total slack budget** called out as the explicit *playerbase dials*.

## Design notes

### The grilled budget (all in `EconomyTunables` / `HangarTunables` / `GadgetCatalog`, already seeded)

**Per-level income** (L1 Beachhead → L4 Naval; only L1–L3 are spendable, L4 → score):

| Level | Base income (floor) | No-death bonus | Collection pool (over-floor) | Clean total |
|-------|--------------------:|---------------:|-----------------------------:|------------:|
| L1 | 70 | +30 | 30 | 130 |
| L2 | 110 | +40 | 40 | 190 |
| L3 | 170 | +50 | 40 | 260 |
| L4 (finale) | 200 | +60 | 90 | → **score** |

- **Base floor L1–L3 = 350**, a thin ~30 margin over Guns (320) — slack is meant to come from skill, not base income.
- **No-death pool L1–L3 = 120**, **collection L1–L3 = 110** → ~230 clean slack, split across the *two faucets*.
- These two figures are the **playerbase dials** (raise post-playtest without touching the spine).

**Per-track prices** (`HangarTunables`, already updated): Guns **60/100/160** (spine); Armour & Engine **50/90/150**
(*survival slack* — cheap 50 entry for catch-up); Bombs **60/110/170** (*expression slack*). Gadgets
(`GadgetCatalog`, unchanged): slots **120/220**, Coin Magnet **70**, Flare/Spotter **90**, Auto-Repair **110**.
Two survival tracks to t2 (2×140) exceeds the ~230 budget → a Playthrough kits a *specialist-with-a-splash*, never a
maxed board.

### The floor top-up (the spine guarantee)

At level-complete, `topup = max(0, base_income[level] - collected_this_level)`. Banked payout for a **first** clear =
`topup + no_death_bonus[level]` (if the level was cleared without a death) **+** whatever the player collected above
the floor (already in `run_coins`). On a **replay** (level already cleared this Playthrough) the banked payout is
**0** — the first-clear gate. Collecting above the floor is kept as slack; the top-up only fills a shortfall.

### Convoy

Convoy units (path-following ground traffic — `Truck`/`Train`, PRD-05/ADR-0009) drop **one guaranteed coin** of
`convoy_coin_value` (skip the random loot roll — the reward is the point). The *risk* is opportunity cost, not
damage: convoys are ground traffic (don't collide, barely shoot), so downing one means diverting fire and
repositioning away from the live air threat. PRD-11 owns **only the coin value + the budget rule** (convoy + ambient
collection together stay inside the per-level `collection_pool`, so level authors can't inflate the economy by adding
convoys). **Placement, escape timers, and path authoring are deferred to the level PRDs (PRD-13/14).**

### Terminal coins→score

On campaign completion, `score += unspent_coins * coin_to_score_rate` (a modest mop-up rate so hoarding-for-score
never competes with spending-to-survive). One-way and terminal; coins and score stay distinct *during* play
(`CONTEXT.md` "Coins").

## User Stories

1. As a death-prone player, I want to afford Guns 0→3 even if I die every level and collect no coins, so the rising difficulty curve never walls me out for lacking firepower.
2. As a player who can't always reach the coins, I want a guaranteed clear payout topped up to a floor, so missing pickups costs me optional power, never the mandatory power.
3. As a skilled player, I want a bonus for clearing a level without dying, so clean play is rewarded with extra slack to spend.
4. As a player who dies late in a run, I want to keep the no-death bonus for the early levels I *did* clear cleanly, so a single late death doesn't erase all my skill reward.
5. As an aggressive, engaged player, I want the coins I actively collect above the floor to be kept as slack, so hunting pickups pays off.
6. As a shaky-but-engaged player, I want collection to earn me coins even on a messy run, so I can buy a tier of survivability to catch up (rather than only the unreachable no-death bonus paying out).
7. As a Coin-Magnet user, I want the gadget to meaningfully increase the coins I bank, so the slot I spent on it is worth it.
8. As a risk-taker, I want convoys to be a worthwhile coin burst that I must divert to destroy before they escape, so there's an optional high-reward play.
9. As a player, I want replaying a level I've already cleared to bank **no** coins, so there's no grind incentive and progress feels honest (matches what the game already tells me).
10. As a player, I want a level I replay to still award score/feel fun, so first-clear gating removes the *coin* farm without making replays pointless.
11. As a player finishing the campaign, I want my unspent coins to convert to a score bonus, so efficient play and my final-level coins still count for ranking.
12. As a player, I want all coins, tiers, and first-clear progress wiped on New Game, so each Playthrough is the intended weak→strong arc with no carryover.
13. As a player, I want my first-clear progress to survive quit/relaunch (Continue), so I can't accidentally (or deliberately) re-earn a level's coins by quitting before the Hangar.
14. As the developer, I want every payout magnitude in a `.tres` I can edit without code, so the budget tunes in a tight loop.
15. As the developer, I want the no-death/collection split exposed as a single clear dial, so I can loosen generosity for the audience after playtests without touching the Guns spine.
16. As the developer, I want the payout math isolated in a pure module, so I can unit-test the floor top-up, the no-death bonus, first-clear gating, and the score cash-out deterministically.
17. As the developer, I want the bank-once / first-clear behaviour covered at the wiring level, so a future refactor of `level_complete` can't silently re-open the farm.

## Implementation Decisions

- **`CoinEarnings` (pure logic, `class_name`, no nodes)** — the payout-side mirror of `HangarUpgrades`, in the same
  static-function mould (ADR-0004). The testable core, reading `EconomyTunables`:
  - `floor_topup(collected: int, level_idx: int, tunables) -> int` → `max(0, base_income[idx] - collected)`.
  - `no_death_bonus(level_idx: int, died_this_level: bool, tunables) -> int` → 0 if died, else the per-level bonus.
  - `level_payout(collected: int, level_idx: int, died: bool, already_cleared: bool, tunables) -> int` → the total
    banked at clear: `0` when `already_cleared` (first-clear gate), else `floor_topup + no_death_bonus`. (Coins
    collected above the floor are already in the wallet; this returns only the *added* payout.)
  - `score_cashout(unspent_coins: int, tunables) -> int` → `unspent_coins * coin_to_score_rate`.
- **`EconomyTunables` (`Resource`/`.tres`, already created).** `base_income`, `no_death_bonus`, `collection_pool`
  (per-level, indexed L1→L4), `convoy_coin_value`, `coin_to_score_rate`. Prior art: `HangarTunables`, `PlayerTunables`.
- **`SaveGame`** gains **`cleared_levels`** (a persisted set of cleared level indices for this Playthrough; the
  first-clear ledger). Round-trips like the existing fields; `reset_playthrough()` clears it. An absent field on an
  old save reads as empty (no-migration, like `owned_tiers`).
- **`GameManager`** wiring (the thin seam over `CoinEarnings`):
  - Loads `EconomyTunables` (a const like `HANGAR_TUNABLES`).
  - Tracks a **`died_this_level`** flag — set when the player dies (the same hook that sends them to a checkpoint),
    reset at level start (paired with `_level_start_lives`).
  - `level_complete()` now: looks up the level index; calls `CoinEarnings.level_payout(run_coins_above_floor, idx,
    died_this_level, cleared_levels.has(idx), tunables)`; banks `run_coins` + that added payout into `coins` **only
    if not already cleared** (replay → banks nothing); marks the level cleared; `save_data()`s. `bank_run_coins()` is
    refactored/absorbed so banking is gated in one place.
  - On **campaign completion** (clearing the final level), calls `score_cashout(coins)` and folds it into the run's
    score for the results screen; the wallet itself is irrelevant after (New Game resets it).
- **`Enemy` / `Truck` (Convoy)** — convoy units drop a guaranteed `Coin` of `convoy_coin_value` (bypass the random
  `EnemyLoot.loot_roll`). Per-archetype `coin_value` is tuned so each level's authored spawns sum toward
  `base_income + collection_pool` — but the **actual spawn authoring is the level PRDs' job** (13/14); this PRD sets
  the targets and the convoy value.
- **`LevelComplete`** — `[Play Again]` no longer implies a re-bank (the first-clear gate in `level_complete` handles
  it). Optionally surface the payout breakdown (floor / no-death / collected) and, on the final level, the
  coins→score cash-out line.

## Testing Decisions

- **What makes a good test here:** assert *external behaviour* of the pure module and the banking seam — coins in →
  coins/score out — never private state. Same discipline as PRD-01/07/08.
- **Prior art:** `test/unit/test_hangar_upgrades.gd` (pure-module purchase math), `test/unit/test_coin_banking.gd`
  (the `run_coins → coins` seam), `test/unit/test_save_game.gd` (round-trip + New-Game reset).
- **`test_coin_earnings.gd` (the pure module — primary coverage):**
  - **Floor top-up:** collect 0 → payout includes full floor; collect < floor → topped up to floor; collect ≥ floor
    → top-up is 0 (overage already kept); per-level floors read from tunables.
  - **No-death bonus:** clean clear → bonus added; died → bonus is 0; per-level values correct.
  - **First-clear gating (the anti-grind guarantee):** a first clear pays `floor + bonus`; an `already_cleared`
    clear pays **0** regardless of collection or no-death.
  - **Score cash-out:** `unspent * rate`; 0 coins → 0; rate read from tunables.
- **`test_economy_banking.gd` (the `GameManager` wiring — confirm the seam):** first clear of a level banks the
  expected payout and marks the level cleared; **replaying that same level banks nothing** (the farm stays closed);
  `cleared_levels` round-trips through save/load; **New Game** clears `cleared_levels` (extends the PRD-07/08 reset
  test). Driven like `test_coin_banking.gd` (call the seam, assert the wallet).

## Out of Scope (scope guards)

- **Convoy set-piece authoring** — paths, escape timers, spawn counts, *which* levels get convoys → **PRD-13/14**.
  This PRD ships the `convoy_coin_value` knob and the "stay inside the collection pool" budget rule only.
- **Per-level spawn tuning** to actually realize each level's `base_income + collection_pool` total → the level PRDs
  (13/14) author spawns against these targets; PRD-11 sets the targets, not the spawn tables.
- **Combo → coins.** The combo multiplier stays **score-only** (ADR-0011) and is untouched here.
- **NG+ / cross-Playthrough persistence.** Clean-slate reset stands (ADR-0011); nothing carries across New Game.
- **Refund / respec.** One-way purchases within a Playthrough (PRD-08 scope guard holds).
- **Final-number balance sign-off.** The seeded values are a grilled *first pass*; whether progression *feels*
  earned-not-grindy is the HITL playtest sign-off, tuned via the `.tres` dials (no code change).
- **Coins→score *rate* polish** and any results-screen animation of the cash-out → numbers tunable here, visual
  polish defers to PRD-18 (HUD/UI).

## Acceptance criteria

- [ ] A run that dies on every level and collects no coins still banks enough to buy **Guns 0→3** across the 3 Hangar
  visits (the floor top-up guarantees the spine).
- [ ] Finishing a level **below** its base-income floor tops the banked payout up to the floor; finishing **above**
  it keeps the overage as slack (no top-up, no clawback).
- [ ] Clearing a level **without dying** banks the per-level no-death bonus; dying anywhere in that level banks **0**
  bonus for it — and earlier clean levels keep their bonuses.
- [ ] **Replaying an already-cleared level banks 0 coins** (kills/score still function); first clear pays normally.
  The `[Play Again]` farm is closed.
- [ ] `cleared_levels` persists through quit/relaunch (Continue) and is **reset by New Game** (along with coins +
  tiers; high score/volumes preserved).
- [ ] On clearing the **final** level, unspent coins convert to a score bonus at `coin_to_score_rate` and show in the
  results.
- [ ] Convoy units drop a guaranteed coin of `convoy_coin_value` (no random roll), and convoy + ambient collection in
  a level cannot exceed the level's `collection_pool` budget.
- [ ] All payout magnitudes are editable in `EconomyTunables.tres` with no code change; the no-death/collection split
  is adjustable there.
- [ ] GUT covers `CoinEarnings` (floor top-up, no-death, **first-clear gating**, score cash-out) **and** the
  `GameManager` banking seam (first-clear banks / replay banks nothing / `cleared_levels` round-trip + reset).

## Files

- `resources/EconomyTunables.gd` + `resources/EconomyTunables.tres` — payout knobs (**created**, seeded).
- `resources/HangarTunables.gd` + `resources/HangarTunables.tres` — real per-track price curve (**updated** from flat
  placeholders).
- `scripts/CoinEarnings.gd` — pure payout math (`class_name`, static): floor top-up, no-death, first-clear gate,
  score cash-out.
- `scripts/SaveGame.gd` — add `cleared_levels` (persisted; cleared by `reset_playthrough()`).
- `scripts/GameManager.gd` — load `EconomyTunables`; `died_this_level` flag; gate banking through `CoinEarnings` in
  `level_complete()`; score cash-out on campaign completion.
- `actors/Enemy.gd` / `actors/Truck.gd` — convoy guaranteed-coin drop (bypass loot roll).
- `ui/LevelComplete.gd` — no re-bank on `[Play Again]`; optional payout/cash-out breakdown.
- `test/unit/test_coin_earnings.gd` — pure-module coverage.
- `test/unit/test_economy_banking.gd` — first-clear / replay / reset seam coverage.
