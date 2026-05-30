# PRD-07 — Save & Campaign Progression

> **Published as [issue #32](https://github.com/stanhasmusic/ocelot/issues/32)** (`ready-for-agent`) — the tracker is canonical.
> Phase 3 slice — the first piece of the metagame. Turns the in-memory Playthrough state
> (coins, checkpoint, campaign progress) into a **saved, resumable Playthrough**, per ADR-0005 as
> amended by **ADR-0011**. Canonical design lives in `CONTEXT.md`,
> `docs/adr/0005-persistent-campaign-with-hangar-metagame.md`, and
> `docs/adr/0011-economy-guns-spine-scarce-skill-fed-slack.md`.

## Problem Statement

The metagame has no memory. Coins (`GameManager.run_coins`) accumulate during a level but live only in
RAM and are reset by `reset_score()`; the checkpoint (`CheckpointState`) is in-memory for the current
run only; and the save file (`SaveGame.tres`) still carries the **prototype's** shape — `high_score`,
volumes, `unlocked_level`, and per-level `level_stars` for the three disposable prototype scenes
(LevelLand / Jungle / Ocean). Quit the app mid-campaign and you lose your coins, your checkpoint, and
your place in the campaign. There is nothing for the Hangar (PRD-08) to spend, nothing for a Continue
button to resume, and no notion of a **Playthrough** as a saved, self-contained arc that a **New Game**
wipes. The prototype also exposes a free-jump `LevelSelect` screen, which contradicts the forward-only
campaign the design locked.

## Solution

Promote the save to a **two-tier schema**:

- **Profile-level** state survives forever, across any number of Playthroughs: audio volumes and the
  all-time `high_score` (score is ranking-only, per `CONTEXT.md`).
- **Playthrough-level** state is the saved, resumable forward pass: the coin **wallet**, campaign
  progress (furthest level reached, 1–4), the persisted **checkpoint**, and **reserved slots** for the
  things PRD-08/09 will own (purchased Hangar tiers, owned gadgets, equipped loadout). A **New Game**
  resets exactly the Playthrough tier to zero and leaves the profile tier untouched (ADR-0011: "nothing
  persists across Playthroughs").

`MainMenu` collapses to **Continue** (resume the saved Playthrough at its furthest level) + **New Game**
(wipe the Playthrough, start at Pacific Beachhead), and the prototype `LevelSelect` is retired — the
Hangar is the only between-levels branch (ADR-0011). The save schema versions cleanly so an existing
v1 `SaveGame.tres` loads without data loss. The serialization/reset/migration logic is isolated from the
autoload so it is unit-testable under GUT, the same way `PlayerMovement` / `CheckpointState` were.

## User Stories

1. As a player, I want to quit the app mid-campaign and relaunch to find my **coins** intact, so banking coins toward a Hangar purchase is never wasted by closing the game.
2. As a player, I want my **campaign progress** (which level I've reached) saved, so **Continue** drops me back where I left off.
3. As a player, I want my **checkpoint** within the current level to survive a relaunch, so quitting mid-level doesn't cost me the whole level.
4. As a player, I want a **Continue** button on the main menu that resumes my saved Playthrough, so I don't have to replay levels I've cleared.
5. As a player, I want **New Game** to start me fresh at Pacific Beachhead with zero coins and no upgrades, so each Playthrough is a clean weak→strong arc (ADR-0011).
6. As a player, I want my **all-time high score** and my **audio settings** to persist even after I start a New Game, so a fresh Playthrough doesn't reset my preferences or my best-ever ranking.
7. As a player, I never want to lose coins or progress by *dying* — only by choosing New Game — so failure stays cheap (ADR-0005, checkpoints).
8. As the developer, I want purchased Hangar tiers, owned gadgets, and the equipped loadout to have **persisted slots reserved now**, so PRD-08/09 only fill them and never need a save migration.
9. As the developer, I want campaign progress stored as a **campaign-level index** decoupled from the disposable prototype scene paths, so the PRD-14 rebuild of the levels doesn't break saves.
10. As the developer, I want an existing **v1 save to migrate cleanly** (high score, volumes preserved; missing fields defaulted), so updating the build never wipes a player's settings or corrupts on load.
11. As the developer, I want the schema, the New-Game reset, and the migration to be **pure logic isolated from the autoload**, so I can unit-test save round-trips and resets under GUT without booting a scene.
12. As the developer, I want a single explicit place where a level-complete **commits the run's coins to the wallet**, so PRD-11 can tune the economy against one seam without hunting through code.

## Implementation Decisions

- **Two-tier `SaveGame` schema (v2).** Extend `scripts/SaveGame.gd` with a `save_version: int` and the
  Playthrough fields, keeping the existing fields:
  - *Profile tier (survives New Game):* `high_score`, `master_volume`, `music_volume`, `sfx_volume`.
  - *Playthrough tier (wiped by New Game):* `coins: int` (the persisted wallet), `campaign_level: int`
    (furthest reached, 1–4), `checkpoint_stage: int` + `checkpoint_marker: int` (the two
    `CheckpointState` fields, flattened — `CheckpointState` is a `RefCounted`, not a `Resource`),
    and **reserved slots** `owned_tiers: Dictionary`, `owned_gadgets: Array`,
    `equipped_loadout: Array` (empty by default; **shape owned by PRD-08/09** — this PRD only persists
    and resets them, it does **not** define the tier/gadget data model).
  - The prototype `unlocked_level` migrates into `campaign_level`; `level_stars` is carried forward
    as-is for migration safety but is prototype-era and not load-bearing here.
- **A small save-store seam, isolated for testing.** Put the schema→state mapping, the New-Game reset,
  and the v1→v2 migration in pure functions that take/return a `SaveGame` (or a plain Dictionary) and do
  **not** touch `get_tree()`, autoloads, or the filesystem — mirror `CheckpointState`'s "pure logic,
  safe to unit-test" pattern. `GameManager.save_data()` / `load_data()` stay the thin glue that calls
  `ResourceSaver`/`load` around this seam. Prior art: `CheckpointState.gd`, `StageConfig`-style resources.
- **Coins become a persisted wallet.** Add `GameManager.coins: int` (the Playthrough wallet) alongside
  the existing in-run `run_coins`. `add_coins()` keeps feeding `run_coins` during a level;
  `level_complete()` calls a new **`bank_run_coins()`** that commits `run_coins` into `coins` and saves.
  This is the single economy seam PRD-11 tunes. **First-clear-only falls out of forward-only progress**
  (you can't replay an earlier level within a Playthrough), so no explicit per-level payout ledger is
  needed in this PRD.
- **`reset_score()` stops nuking the wallet.** It currently zeroes `run_coins`; the persisted `coins`
  wallet must be untouched by per-life/per-level score resets. Only **New Game** clears the wallet.
- **`CheckpointState` gains (de)serialization.** Add `to_dict()` / `from_dict()` (or
  `serialize()`/`apply()`) so `GameManager.checkpoint` flattens into the save and rehydrates on Continue.
  Keep its monotonic `record()` behavior unchanged.
- **`new_game()` and `continue_playthrough()` on `GameManager`.**
  - `new_game()` — reset the Playthrough tier (coins, campaign progress, checkpoint, reserved
    tier/gadget/loadout slots) to zero, save, and launch campaign level 1.
  - `continue_playthrough()` — load the saved Playthrough, rehydrate coins + checkpoint, and route to
    the saved `campaign_level`.
- **`MainMenu` → Continue + New Game; retire `LevelSelect`.** `MainMenu` shows **Continue** (enabled
  only when a Playthrough is in progress, i.e. `campaign_level > 1` or a non-zero checkpoint/coins) and
  **New Game** (with a confirm prompt when it would overwrite an in-progress Playthrough). Remove the
  `ui/LevelSelect.tscn`/`.gd` free-jump screen and any navigation to it (ADR-0011).
- **Decouple progress from disposable scene paths.** Store `campaign_level` as a 1–4 index. The
  prototype `GameManager.LEVELS` path array is *not* the persisted unit; PRD-14's level template will map
  the index → the real level scene. This PRD may keep a thin index→prototype-scene lookup so the build
  still runs, but the **save** stores the index, not the path.

## Testing Decisions

- **GUT is already stood up** (PRD-01); follow the `test/unit/` precedent (e.g. `test_checkpoint_state.gd`).
- Tests assert **external behavior, not implementation** — given a save/state, assert the resulting
  state after round-trip / reset / migrate; no peeking at private fields.
- **Save round-trip:** a populated Playthrough (coins, `campaign_level`, checkpoint, reserved slots)
  written and re-read yields an equal state; profile fields (high score, volumes) round-trip too.
- **New-Game reset:** after `new_game()`-equivalent reset, every Playthrough field is zero/empty **and**
  profile fields (high score, volumes) are unchanged. (Encodes the ADR-0011 boundary.)
- **Migration:** a v1-shaped `SaveGame` (no `save_version`, no Playthrough fields) loads without error;
  `high_score` + volumes are preserved, `unlocked_level`→`campaign_level` carries, and the missing
  Playthrough fields default to zero/empty rather than erroring.
- **Coin banking:** `run_coins` accumulates during a level and commits to the persisted `coins` wallet
  exactly once on level-complete; a per-life score/coin reset does **not** touch the wallet.
- **`CheckpointState` (de)serialization:** `to_dict()`→`from_dict()` reproduces `resume_point()`, and
  monotonicity still holds after rehydration.

## Out of Scope

- **The Hangar screen, the tier/gadget data models, and spending coins** → **PRD-08** (stat tracks) and
  **PRD-09** (gadget loadout). This PRD only *reserves and persists* the `owned_tiers` / `owned_gadgets`
  / `equipped_loadout` slots; it does not define their contents or any UI.
- **Economy tuning** — coin payout curves, prices, the no-death bonus, anti-grind guardrails → **PRD-11**
  (#39). This PRD provides the single `bank_run_coins()` seam; it sets no balance numbers.
- **The rebuilt campaign levels** themselves and the index→scene mapping for the real levels → **PRD-14**
  (#37). Prototype scenes remain only so the build runs.
- **Level-complete / Game-over screen rework** beyond what Continue/New-Game routing requires — the
  broader menu/HUD pass is **PRD-18** (#40).
- **`level_stars`** semantics under the forward-only campaign — carried forward for migration safety but
  not redesigned here.

## Further Notes

- **Corrects the tracking issue.** Issue #32's acceptance line "Level-select reflects unlocked levels"
  predates ADR-0011 and is **superseded**: progress is forward-only, the prototype `LevelSelect` is
  retired, and `MainMenu` collapses to **Continue + New Game**. The other criteria stand.
- **The wallet-vs-run-coins split matters.** `run_coins` is the in-level tally the HUD shows building;
  `coins` is the saved Playthrough wallet the Hangar spends. Keeping them distinct is what lets coins
  survive death-to-checkpoint within a Playthrough while still resetting on New Game.
- **Profile vs Playthrough is the load-bearing distinction** — it's the concrete encoding of ADR-0011's
  "nothing persists across Playthroughs" against "settings and best score are mine forever." Get this
  boundary right and PRD-08/09/11 are purely additive.
- **Done =** quit and relaunch restores coins, campaign progress, and checkpoint; **Continue** resumes
  the saved Playthrough and **New Game** wipes only the Playthrough tier (coins/progress/checkpoint/
  reserved slots) while preserving high score + volumes; the prototype `LevelSelect` is gone; a v1 save
  migrates with no data loss; and the save round-trip, New-Game reset, migration, coin-banking, and
  `CheckpointState` (de)serialization tests pass under GUT.
