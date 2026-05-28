# PRD-16 — Audio direction

> **Published as [issue #42](https://github.com/stanhasmusic/ocelot/issues/42)** — the tracker is canonical.
> Phase 5 polish slice. Implements
> [[0014-boss-music-hard-swap-with-leitmotif-track-family]] and
> [[0015-sfx-organised-by-weapon-class-not-threat-tier]] on top of the existing `SoundManager`
> (music crossfade + dynamic SFX pooling, `scripts/SoundManager.gd`) and the existing three-bus
> topology (CLAUDE.md "Audio Bus Architecture").

## Problem Statement

As a player, the game today is functionally silent at every emotional moment. There's a placeholder
track on `SoundManager` but no per-level music identity, no boss music swap when BIG MAMA appears,
no fanfare when I beat her, no audible difference between the basic MG I started with and the
cannon I just bought in the Hangar, and the bomb — my screen-clearing power move — doesn't get any
musical room to land. As the developer, `SoundManager.play_music` already crossfades, but there's
no track-to-slot mapping, no stinger channel, no ducking, and no defined SFX-to-event taxonomy —
so the audio direction has to be built before any of these moments can ship.

## Solution

A small `MusicDirector` autoload sits above `SoundManager` and maps game-state transitions (level
enter, stage transition, boss spawn, boss death, level complete, Hangar enter) to the locked rules
from ADR-0014, looking up tracks from a `MusicSlots` resource the user edits without touching code.
`SoundManager` grows by exactly two things: a stinger channel (one-shot `AudioStreamPlayer` on the
Music bus, plays *over* music) and an event-triggered duck (tween `music_player.volume_db`).
Per-event SFX assignment lives in a `SFXMap` resource — events grouped by **weapon class** per
ADR-0015, not by threat tier. The mix sits inside the existing bus trims and limiters with no
topology changes.

## User Stories

1. As a player, each level has a distinct musical identity I can recognise on the second play.
2. As a player, when the named boss appears, the music swaps so I *feel* the level pivoting into
   its finale.
3. As a player, when I beat the named boss, a victory fanfare lands before the screen calms into
   the Hangar.
4. As a player, when I drop my bomb, it sounds like a screen-clearing event — the music breathes
   so the blast lands.
5. As a player, enemy fire sounds like the actual weapon — a tank goes BOOM, an MG goes rat-tat-tat,
   AA flak punches.
6. As a player, when I buy a Guns-tier upgrade in the Hangar, my next shot sounds different from my
   last one.
7. As a player, when I pause to take a call, all audio stops; when I unpause, the music resumes
   exactly where it left off — the boss tension I paused on is still there.
8. As a player, the Main Menu and the Hangar feel like different places — one is "Ocelot, the
   game," the other is "ready to deploy."
9. As a player, dying never blinks the music — the world keeps going while I respawn.
10. As a player, between stages of a level the music keeps going — I'm on the same front for the
    full level.
11. As the developer, track-to-slot assignment lives in a `.tres` so swapping a track requires zero
    code changes.
12. As the developer, SFX-to-event assignment lives in a `.tres` for the same reason.
13. As the developer, the duck depth and duration per event are tunable values on the same `.tres`,
    so the bomb-vs-stinger-vs-boss-death duck can each be tuned independently.
14. As the developer, `MusicDirector` exposes a single entry point per game-state transition
    (`on_level_enter(level_id)`, `on_boss_spawned()`, `on_boss_died()`, `on_level_complete()`,
    `on_hangar_enter()`, `on_main_menu_enter()`), so wiring new transitions doesn't require
    touching `SoundManager`.
15. As the developer, adding a new music slot or stinger event is a resource-only change.
16. As the developer, pause behaviour is handled via Godot's `process_mode` on the audio nodes, so
    pause auto-pauses audio with no manual coupling.

## Implementation Decisions

### Music inventory (the slot table)

10 music tracks total. **7 are already in `assets/audio/`**; the remaining 3 are authored by the
user ([[user-can-author-music]]).

| Slot ID | Use | Notes |
|---|---|---|
| `main_menu` | Main Menu | Thematic anchor — the actual "Main Theme Music" |
| `hangar` | Hangar | Distinct "ready to deploy" energy — `Main Theme Music v2_ Ocelot` is the candidate |
| `l1_pacific` | Level 1 (Pacific Beachhead) | Plays continuously across all 3 stages |
| `l2_countryside` | Level 2 (Countryside) | Plays continuously across all 3 stages |
| `l3_city` | Level 3 (City) | Plays continuously across all 3 stages |
| `l4_naval` | Level 4 (Naval) | Plays continuously across all 3 stages |
| `boss_shared` | Coastal Fortress (L1) + the Train (L2) | The shared L1/L2 boss track |
| `boss_big_mama` | BIG MAMA (L3 finale) | Bespoke; hero sprite earns hero track |
| `boss_double_trouble` | Double Trouble (L4 finale) | Bespoke; campaign finale |
| `splash_video` | n/a | The splash video carries its own audio — not a track slot |

**Composition directive** for the 3 boss tracks (`boss_shared`, `boss_big_mama`, `boss_double_trouble`):
written around a **shared melodic leitmotif** — common chord progression or theme melody — so the
boss family reads as one *idiom* across the campaign (ADR-0014).

### Stinger inventory

| Stinger ID | Trigger | Length | Required |
|---|---|---|---|
| `victory_fanfare` | Named-boss death | ~2–4s | Mandatory |
| `life_up_chime` | `life_up` pickup collected | ~0.5–1s | Optional |

### Transition rules (the `MusicDirector` state machine)

| Game event | Music behaviour |
|---|---|
| Main Menu enter | Crossfade to `main_menu` |
| Hangar enter (from menu or level-complete) | Crossfade to `hangar` |
| Level enter (start of Stage 1) | Crossfade to the level's track (`l1_pacific`, etc.) |
| Stage 2 / Stage 3 start | **No music change** — current level track keeps playing (Q7) |
| Mini-boss spawn / death (Stages 1–2) | **No music event** (Q2) |
| Named boss spawn (Stage 3) | Hard-swap crossfade to the boss track (`boss_shared` for L1/L2; `boss_big_mama` for L3; `boss_double_trouble` for L4) |
| Player loses a life (respawn in place) | **No music change** (Q3) |
| Player drops to checkpoint | **No music change** *unless* the boss is no longer present — then crossfade boss track back to level track (Q3) |
| Named boss death | `victory_fanfare` stinger fires; music ducks under it (see ducking rules); after stinger, ~2s silence; then crossfade to `hangar` track which plays through level-complete and Hangar (Q8) |
| Game pause | Pause all audio via `process_mode` (Q12) |
| Game unpause | Resume exactly where music left off |

### `SoundManager` extensions

`scripts/SoundManager.gd` grows by exactly:

- **`stinger_player: AudioStreamPlayer`** — second player on the **Music bus**, created in
  `_ready()` alongside `music_player`. Distinct so a stinger can play *over* a music track without
  cutting it.
- **`play_stinger(stream: AudioStream, duck_db: float = -6.0, duck_duration: float = 0.3) -> void`**
  — plays the stream on `stinger_player` and simultaneously ducks `music_player.volume_db` via tween
  for the duration (then restores it). Mid-stinger calls cancel the in-flight duck tween before
  starting a new one (no stacking).
- **`duck_music(db: float = -6.0, duration: float = 0.3) -> void`** — public method other systems
  call for event-driven ducks not tied to a stinger (bomb detonation, boss-death explosion).
- **Pause** — set `process_mode = PROCESS_MODE_PAUSABLE` on both `music_player` and `stinger_player`
  (or whichever Godot 4 idiom achieves "pauses with the scene tree"). The SFX pool already inherits
  scene-tree pause via `sfx_pool` being under the autoload tree; verify on implementation.

No new buses. The existing Master / Music / SFX three-bus layout and the limiter chain stand
([[CLAUDE]] Audio Bus Architecture). Per-source `volume_db` trims on individual players stay deferred
to end-of-project polish.

### Ducking rules

Music ducks under three event classes (Q5), tunable per event in `.tres`:

| Event | Default depth | Default duration |
|---|---|---|
| Bomb detonation | −6 dB | 0.30 s |
| Named boss death | −6 dB | 0.40 s |
| Stinger (`victory_fanfare`, `life_up_chime`) | −6 dB | matches stinger length + 0.1 s release |

The values are starting points; the user owns the playtest sign-off. The duck depth is shallow
on purpose — a *blink*, not a dip — so musical energy is preserved.

### `MusicDirector` autoload

- New autoload `scripts/MusicDirector.gd`, registered alongside `GameManager` and `SoundManager`.
- Holds a `MusicSlots` resource and a current-slot ID.
- Exposes the public API listed in user story #14.
- Listens for the relevant `GameManager` signals (e.g., `on_boss_spawned`, `on_boss_died`) and the
  level-lifecycle signals.
- Owns the transition state machine table above. Pure dispatch on top of `SoundManager`.

### `MusicSlots` resource

- `Resource` (`.tres`) with one `AudioStream` exported per slot ID in the music inventory table.
- Lives at `resources/MusicSlots.tres`. Prior art: `StageConfig.gd`, `PlayerTunables.tres`.

### `SFXMap` resource

- `Resource` (`.tres`) mapping event IDs to `AudioStream` resources. Lives at `resources/SFXMap.tres`.
- Event IDs grouped by **weapon class** per ADR-0015:

**Player events**
- `player_fire_tier_0`, `player_fire_tier_1`, `player_fire_tier_2`, `player_fire_tier_3`
- `player_hit` (per damage-state advance)
- `player_death`
- `bomb_detonate`
- `pickup_coin`, `pickup_bomb`, `pickup_life_up`, `pickup_fire_pattern`,
  `pickup_wingman`, `pickup_missile`, `pickup_repair`

**Enemy events — by weapon class** (per ADR-0015)
- `enemy_fire_mg_light` (Strafer / Diver MG)
- `enemy_fire_mg_heavy` (Gunship)
- `enemy_fire_cannon_tank` (Tank, panzer)
- `enemy_fire_cannon_naval` (Warship turret)
- `enemy_fire_aa_flak` (Emplacement AA)
- `enemy_fire_missile` (heavy weapon)

**Enemy deaths — by mass class**
- `enemy_death_light_air` (Strafer / Diver)
- `enemy_death_heavy_air` (Gunship)
- `enemy_death_ground_vehicle` (Tank / Convoy)
- `enemy_death_structure` (Emplacement / part)
- `enemy_death_naval` (Warship)

**Boss events**
- `boss_part_hit`
- `boss_part_destroyed`
- `boss_phase_transition`
- `boss_death` (the big one — also triggers the `victory_fanfare` stinger and music duck)

**UI events**
- `ui_button_hover`, `ui_button_click`, `ui_confirm`, `ui_cancel`
- `hangar_purchase_success`, `hangar_purchase_blocked`
- `pause_open`, `pause_close`

The library at `assets/audio/Sound Effects/` is rich enough that most events have an existing
candidate. Final asset paths are the user's curation call ([[user-learning-exercise]] — taste lives
with him). PRD-16 does not pre-assign them.

### Player gun SFX across Guns tier

Per Q9 and ADR-0015 consequence #3: spec is **4 distinct sounds** (`player_fire_tier_0` …
`player_fire_tier_3`). The fallback if the 4-distinct version feels too noisy in playtest is
**1 shared sound across all tiers** — the resource map collapses to one asset path on all four
event IDs. The fallback is graceful: no code change, just a `.tres` edit.

## Testing Decisions

Audio is mostly **feel work** — the right test is "does this land in playtest?" rather than "does
this assertion pass?" Two narrow areas where unit tests are still worth it:

- **`MusicDirector` transition table** — the state-machine dispatch is deterministic: given a
  game-state event, the director should call `SoundManager` with the correct slot ID. Testable via
  a `SoundManager` stub that records calls. Catches transition-table regressions if the table is
  refactored later. Worth ~10 small tests across the rows of the transition rules table above.
- **Ducking timing** — `SoundManager.play_stinger` and `duck_music` mutate `music_player.volume_db`
  via tween; a regression that stops restoring it would silently kill the music until the next
  swap. One test asserts that volume_db returns to its pre-duck value after the duration elapses.

Everything else (asset-to-event taste, mix balance, leitmotif cohesion, "does the bomb feel
weighty") is playtest sign-off.

## Out of Scope

- **Adaptive layering** for music. Locked as the deferred upgrade in ADR-0014; would require
  re-authoring every level track as layered stems plus a stem-mixer in `SoundManager`.
- **Per-biome ambient layer** (surf, wind, city rumble, ocean). Worth doing for atmosphere but
  not on this PRD — could land with PRD-20 (juice).
- **Adaptive boss-phase music** (different intensity per phase) — adjacent to adaptive layering;
  deferred with it.
- **Colour-blind / shape-redundancy accessibility** ([[0012-player-fire-is-a-visual-class-outside-the-threat-palette]] consequence) — visual, not audio.
- **Spatial audio / positional panning** for enemies on screen. Mobile shmup at 540×960 doesn't
  earn it; stereo is enough.
- **Mix automation across the bus topology** (compressor sidechaining, etc.). The existing limiter
  chain at Master and SFX stays; tunable per-event ducking handles the dynamic-range moments we
  actually need.
- **Music loop-point authoring** (seamless loops with custom loop points) — Godot's stream import
  has loop settings; default looping is fine for the first pass. Address per-track if a level
  noticeably "restarts" mid-play.

## Further Notes

- The user authors all music ([[user-can-author-music]]) — the 7 existing tracks are starting
  points, not a budget. Of the 10 music slots, 7 have candidates in the library; the remaining 3
  (one of the level tracks, the BIG MAMA bespoke, the Double Trouble bespoke — or any other gap the
  user decides) are author-as-needed.
- The leitmotif directive on the 3 boss tracks (`boss_shared`, `boss_big_mama`, `boss_double_trouble`)
  is a composition note, not a code constraint. The architecture works without it; the cohesion is
  the bonus.
- **Done =** every game-state transition in the transition-rules table fires the correct music
  behaviour, the stinger channel works, ducking is tunable and restores cleanly, pause stops and
  resumes audio, the `MusicSlots` and `SFXMap` resources expose every slot/event listed above for
  user editing, and a complete L1 playthrough has a recognisable musical arc from menu → Hangar →
  level → boss-spawn → boss-death → silence → Hangar.
