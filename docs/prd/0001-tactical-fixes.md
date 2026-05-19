# PRD: Tactical fixes — audio stacking, Stage 1 banner, stage indexing

## Problem Statement

Three concrete issues block the "more solid foundation" goal and are felt directly while playing:

1. When multiple enemies explode in the same frame, the SFX bus pumps audibly — music and other sounds duck and the mix sounds squashed. This will get worse as encounter density grows (more enemies, bigger bombs).
2. When a player starts a level, no "STAGE 1" banner appears. They see banners for STAGE 2 and STAGE 3 when they reach them, plus LEVEL CLEAR at the end — so the missing banner reads as a bug, not a design choice. The player has no opening cue that the level has begun or that there are multiple stages ahead of them.
3. The stage-progression code mixes 1-indexed and 0-indexed counters in the same file, papered over with a `- 1` at the call site. The next refactor will silently skip or repeat a stage.

## Solution

1. **Audio**: retune the SFX and Master bus limiters to provide real gain-reduction headroom (instead of brick-walling at the ceiling), and add a per-stream concurrency cap plus small pitch jitter in `SoundManager.play_sfx` so identical samples decorrelate when stacked.
2. **Stage 1 banner**: call the existing `StageOverlay.show_stage` once at level load so Stage 1 announces itself like Stage 2 and Stage 3 already do.
3. **Stage indexing**: normalise to **0-indexed internally** everywhere. The overlay displays `stage_index + 1` only at the call site.

## User Stories

1. As a player, I want sound effects to remain clear and music to keep playing at full volume when many enemies explode at once, so that the game feels polished rather than chaotic.
2. As a player, I want to never hear the mix audibly "squash" during heavy combat, so that bursts of action feel exciting rather than broken.
3. As a player, when I start a level, I want to see a "STAGE 1" banner just like I see "STAGE 2" and "STAGE 3" later, so that the game's structure is consistent and I understand a level has multiple stages from the very beginning.
4. As a new player, I want the opening of a level to give me a moment of clear visual feedback before enemies arrive, so that I'm not thrown straight into combat without orientation.
5. As a developer maintaining the project, I want stage indexing to be consistent across files, so that I can refactor stage logic without introducing off-by-one bugs.
6. As a developer adding a new level, I want a single, unambiguous convention for "what number is this stage," so that I'm not guessing whether a function expects 0-based or 1-based input.
7. As a player on a quieter device, I want explosion volumes to remain perceptually consistent whether one enemy or eight enemies die at once, so that I'm not surprised by volume spikes.
8. As a sound designer (future), I want the bus chain to provide gain-reduction headroom before limiting kicks in, so that I can mix new SFX without re-tuning the master bus.

## Implementation Decisions

### Audio bus retune (`resources/default_bus_layout.tres`)

- SFX bus limiter: `threshold_db = -8.0`, `ceiling_db = -1.0`. Gives ~7 dB of soft gain-reduction headroom before the ceiling is reached, so summed SFX is tamed transparently rather than slammed flat.
- Master bus limiter: `threshold_db = -3.0`, `ceiling_db = -0.5`. Catches the bus sum as a safety net without acting as the primary dynamics processor.
- No compressor added (yet); keep the chain minimal and reassess after the limiter retune. If a single explosion still pumps audibly, the next step is a gentle compressor on the SFX bus (ratio 3:1, attack ~5 ms, release ~80 ms) — but defer until heard.

### SFX concurrency + decorrelation (`scripts/SoundManager.gd`)

- `play_sfx(stream)` rejects a new play if there are already `MAX_PER_STREAM` (= 4) currently-playing pool members with the same `stream`. The rejection is silent — no fallback, no queue.
- When a play is accepted, set `player.pitch_scale = randf_range(0.95, 1.05)` so identical samples played back-to-back decorrelate.
- `MAX_PER_STREAM` and the pitch-jitter range live as `const`s at the top of `SoundManager.gd` so they're tunable in one place.
- The existing pool reuse + dynamic-grow behaviour is unchanged.

### Stage indexing normalisation (`scripts/Level01.gd`)

- `current_stage` becomes a 0-indexed integer (`var stage_index: int = 0`), matching `EnemySpawner.current_stage`. Constant `TOTAL_STAGES` stays semantically "count of stages" (= 3).
- Rename `current_stage` → `stage_index` to make the index nature explicit at the call site.
- The `- 1` adjustment at the `reset_for_stage` call goes away.
- `show_stage` receives `stage_index + 1` — display conversion happens at the boundary, never internally.

### Stage 1 banner (`scripts/Level01.gd`)

- In `_ready`, after the music starts and the boss-died signal is connected, call `stage_overlay.show_stage(1)` and `await get_tree().create_timer(2.5).timeout` before allowing the spawner to start. To avoid changing the spawner contract, the cleanest approach is to add a `enemy_spawner.set_process(false)` / `set_process(true)` gate around the await, or pause the spawner's internal timer; spawner currently autostarts via its `ShootTimer` etc., so verify the right gate during implementation.
- Effect: the player sees a "STAGE 1" overlay for the same duration they see "STAGE 2" and "STAGE 3", then play begins.

### Deferred — not in this PRD

- Extracting stage-progression into a `StageProgression` deep module reusable across levels. Belongs in the upcoming `LevelBase` PRD; doing it here would expand scope.

## Testing Decisions

- **No automated tests** for this PRD. The project has no test framework today (no GUT, no `tests/` directory), and adding one is itself a foundation decision being tracked as a separate follow-up issue.
- Each change is verified by ear / by eye in the Godot editor:
  - **Audio**: trigger a screen-clearing bomb (Player's bomb mechanic) in Level 1; the mix must not audibly squash, music must not duck noticeably, and individual explosions remain identifiable.
  - **Stage 1 banner**: load Level 1, observe "STAGE 1" overlay appears with the same fade-in/hold/fade-out timing as the existing Stage 2/3 transitions, and that no enemies spawn during the banner.
  - **Stage indexing**: clear Stage 1 → boss appears → kill it → "STAGE 2" appears and the correct boss for stage index 1 spawns. Repeat through Stage 3 and LEVEL CLEAR.
- A good test for this PRD's changes (if a framework existed later) would assert observable behaviour: `play_sfx` called 10× with the same stream within one frame results in ≤ 4 active players; `_ready` triggers `show_stage(1)` exactly once; `reset_for_stage` is called with 0, 1, 2 in order.

## Out of Scope

- Threat-tier projectile sprite rewire (separate PRD).
- Hybrid scripted-intro + procedural-body difficulty model (separate PRD; ADR 0002).
- `LevelBase.tscn` scene inheritance refactor (separate PRD).
- Hand-authored scrolling backgrounds, deprecation of `MovingLandBackground` (separate PRD; ADR 0003).
- Level Select polish (lock icons, per-level best score) — separate PRD.
- Adding a test framework — tracked as separate issue.
- Sidechain ducking, compressor on the SFX bus, mastering polish beyond the limiter retune.

## Further Notes

- Relevant ADRs: none directly bind this PRD, but [ADR 0002](../adr/0002-hybrid-stage-difficulty.md) explains why the stage concept is foundational (so getting the banner and indexing right now pays off later).
- Audience reference: [target audience memory](../../.claude/memory/project_ocelot_target_audience.md) — Stage 1 banner is partly an accessibility fix; the non-gamer playtester had no cue that combat was about to begin.
- All three fixes are independently shippable — if one is harder than expected during implementation, the other two should still ship.
