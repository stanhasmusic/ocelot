# PRD-07 — Save & Campaign Progression

> **Published as [issue #32](https://github.com/stanhasmusic/ocelot/issues/32)** (`ready-for-agent`) — the tracker is canonical.
> Phase 3 slice — the first piece of the metagame. Canonical design lives in `CONTEXT.md` and
> `docs/adr/0005-persistent-campaign-with-hangar-metagame.md` **as amended by**
> `docs/adr/0011-economy-guns-spine-scarce-skill-fed-slack.md` (persistence is per-Playthrough, not forever).

## Problem Statement

The metagame has no memory. Coins (`GameManager.run_coins`) live only in RAM and are wiped by
`reset_score()`; the `CheckpointState` is in-memory for the current run; and `SaveGame.tres` still has
the **prototype shape** (`high_score`, volumes, `unlocked_level`, `level_stars` for the three disposable
prototype scenes). Quit mid-campaign and you lose coins, checkpoint, and your place — there's nothing for
the Hangar (PRD-08) to spend, nothing for a Continue button to resume, and no notion of a **Playthrough**
that **New Game** wipes.

## Solution

A **two-tier save schema** keyed off ADR-0011's "arcade arc — New Game resets to zero":

- **Profile tier** (survives any New Game): audio volumes + all-time `high_score`.
- **Playthrough tier** (wiped by New Game): coin **wallet**, `campaign_level` (1-based furthest level),
  the persisted **checkpoint**, `level_stars`, and **reserved slots** (`owned_tiers` / `owned_gadgets` /
  `equipped_loadout`) that PRD-08/09 will fill.

`MainMenu` collapses to **Continue** (enabled only with a Playthrough in progress) + **New Game** (confirm
before overwriting an in-progress run). The prototype `LevelSelect` is retired — progression is
forward-only, so the Hangar (later) is the only between-levels branch. The schema **versions cleanly**: a
v1 `SaveGame.tres` migrates with no data loss (`unlocked_level` → `campaign_level`, missing fields
defaulted). Serialize/reset/migrate logic is **isolated from the autoload** (static methods on `SaveGame`
+ `CheckpointState.serialize/deserialize`) so it unit-tests like `CheckpointState` (ADR-0004).

## Design notes

- **Schema-version detection.** `SaveGame.schema_version` defaults to **1** (the floor), not the current
  version: a v1 file never stored the field, so it loads as 1 and triggers `migrate()`. Code writing a
  fresh save sets it to `SCHEMA_VERSION` explicitly.
- **The coin seam.** `run_coins` stays the in-run tally (PRD-05 drops feed it). `bank_run_coins()` is the
  **single** place it commits into the persisted `coins` wallet — called once per level from
  `level_complete()`. Death-to-checkpoint (respawn in place) never resets `run_coins`; game-over loses the
  run's *uncommitted* coins but never touches the banked wallet. Only New Game clears the wallet.
- **Checkpoint persistence** is the data round-trip (`CheckpointState.serialize/deserialize` through the
  save). Continue resumes at **level** granularity (`campaign_level`); `LevelBase` still resets the
  stage-checkpoint on level entry, so mid-level stage-resume across a relaunch is intentionally out of
  scope here.
- **Legacy field.** `SaveGame.unlocked_level` is kept as a loadable `@export` purely as a migration
  source; it is never read at runtime after migration.

## What this PRD does *not* do (scope guards)

- Hangar UI + tier/gadget **data models** + spending → **PRD-08** (#36) / **PRD-09** (#38). This PRD only
  reserves/persists the slots.
- Economy tuning (payout/price curves, no-death bonus) → **PRD-11** (#39). This PRD provides only the
  `bank_run_coins()` seam.
- Rebuilt campaign levels + index→real-scene mapping → **PRD-14** (#37); the prototype scenes in `LEVELS`
  stay only so the build runs.

## Acceptance criteria

- [x] Quit and relaunch restores **coins**, **campaign progress**, and **checkpoint**.
- [x] **Continue** resumes the saved Playthrough at its furthest level; **New Game** starts fresh at
  level 1 with zero coins/progress/checkpoint.
- [x] **New Game wipes only the Playthrough tier** — high score and audio volumes are preserved (ADR-0011).
- [x] `owned_tiers` / `owned_gadgets` / `equipped_loadout` slots are **persisted and reset**, so PRD-08/09
  need no migration.
- [x] Coins survive death-to-checkpoint within a Playthrough; only New Game clears the wallet. `run_coins`
  commits to the persisted wallet once on level-complete via a single `bank_run_coins()` seam.
- [x] An existing **v1 `SaveGame.tres` migrates cleanly** — high score + volumes preserved,
  `unlocked_level`→`campaign_level`, missing fields defaulted (no crash, no data loss).
- [x] Prototype `LevelSelect` is removed; `MainMenu` shows Continue (enabled only with a Playthrough in
  progress) + New Game (confirm before overwriting an in-progress Playthrough).
- [x] GUT tests cover: save round-trip, New-Game reset (Playthrough zeroed / profile preserved), v1→v2
  migration, coin-banking, and `CheckpointState` (de)serialization.

## Files

- `scripts/SaveGame.gd` — versioned two-tier schema + static `migrate()` / `reset_playthrough()`.
- `scripts/CheckpointState.gd` — `serialize()` / `deserialize()`.
- `scripts/GameManager.gd` — two-tier load/save + migration; `bank_run_coins()`,
  `start_new_playthrough()`, `continue_playthrough()`; `unlocked_level` → `campaign_level`.
- `ui/MainMenu.gd` / `ui/MainMenu.tscn` — Continue + New Game + confirm dialog.
- `ui/LevelComplete.gd` — campaign-cleared exit routes to the menu (LevelSelect retired).
- `ui/LevelSelect.gd` / `ui/LevelSelect.tscn` — **removed**.
- `test/unit/test_save_game.gd`, `test/unit/test_coin_banking.gd`,
  `test/unit/test_checkpoint_state.gd` — coverage.
