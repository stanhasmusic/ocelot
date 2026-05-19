# PRD: Hand-authored scrolling backgrounds (Level 1 demonstrator)

## Problem Statement

Every existing background in Ocelot is procedural or static — `Background` is a solid blue `ColorRect`, `JungleBackground` is randomly-placed grass tiles and trees, `MovingLandBackground` is a noise-based ground generator. None of them can tell the player anything about *where they are in the stage*. There's no biome shift, no approaching landmark, no visual telegraph that "the boss is coming." For a noob/mid-tier audience that needs visual progress cues (per the non-gamer playtest), the background system is silent precisely when it should be informative.

Concrete consequences:

1. **Boss arrivals are surprises.** Today the boss appears because the score crosses a threshold. The player sees no environmental shift, so the encounter starts without warning.
2. **Within a stage, the background loops indistinguishably.** The player has no way to feel "I'm halfway through this stage" from the visuals alone.
3. **Stage-to-stage transitions look identical.** Stage 1 and Stage 3 of the same level are visually the same surface.
4. **The procedural systems carry real complexity** (especially `MovingLandBackground`'s noise + tile recycling) for a feature — infinite scroll — the game doesn't actually need. Finite, stage-structured levels (ADR 0002) don't benefit from procedural infinity.

## Solution

Adopt the system from ADR 0003: hand-authored scrolling backgrounds, with landmarks baked into the strip art, swapped per stage via a `LevelBackground` resource. Per-level scenes (post-PRD #12 / issue #12) plug a `ScrollingBackground` instance into `LevelBase`'s `background_scene` slot. Each level supplies a `LevelBackground.tres` with one `StageBackground` per stage and an optional `boss_arena_texture` for the held boss-fight backdrop.

This PRD ships the *system* and migrates **Level 1 (Ocean)** end-to-end as the tracer-bullet demonstrator with placeholder art. `JungleBackground` (Level 3) and `MovingLandBackground` (LevelLand) stay in place behind their current `background_scene` slots until per-level migration PRDs replace them. A final cleanup ticket deletes the procedural scripts once all three levels are migrated.

After this PRD, the foundation for "each new level needs N stage strips + a boss arena texture and is good to go" is in place, and Level 1 demonstrates the visual-pacing contract working end-to-end.

## User Stories

1. As a player, I want the background to scroll through visibly different environments as I progress through a stage, so that I feel I'm travelling somewhere rather than circling.
2. As a player, I want to see a clear visual landmark in the moments before a boss appears, so that the encounter feels telegraphed and earned rather than dropped on me.
3. As a player, I want Stage 1, Stage 2 and Stage 3 of a level to look distinct from each other, so that my sense of progression matches what I see.
4. As a player fighting a boss, I want the background to settle into a stable "arena" view, so that the visual chaos doesn't compete with the boss for attention.
5. As a player on a quiet device, I want background scroll speed to feel consistent with the play tempo, so that the world feels coherent rather than juddery.
6. As a developer adding a new level, I want to author its backgrounds by creating three PNG strips and one boss-arena texture and dropping them into a `LevelBackground` resource, so that "new level" is a content task rather than a code task.
7. As a developer, I want the background system to take its stage cues from the same source as the gameplay (`LevelBase`'s stage state), so that visuals and mechanics can't drift out of sync.
8. As a developer, I want `MovingLandBackground` to be deletable once all three levels are migrated, so that the procedural noise system stops being maintained.
9. As an artist (Stan, future Stan, or a hired contributor), I want the per-stage strip format to be a single tall PNG with landmarks baked in, so that authoring is "paint in your favourite tool" and not "configure overlay-node positions in Godot."
10. As a developer reviewing a per-level art PR, I want the change to be a `.tres` swap pointing at new PNGs, so that the diff is auditable without opening Godot.

## Implementation Decisions

### New resource types

**`StageBackground`** — a `Resource` subclass:

- `strip_texture: Texture2D` — a tall PNG sized to viewport width (540 px) by some stage length. The texture is the entire stage's visible background; landmarks (biome shifts, pre-boss telegraph, etc.) are baked into it. No required aspect ratio beyond "taller than the viewport."
- `scroll_speed: float` — pixels per second. Default 100.
- `parallax_layers: Array[ParallaxLayer]` — optional far/mid/near parallax layers, each a Godot `ParallaxLayer` with its own scroll multiplier. Default empty (no parallax). The single-layer case is the minimum viable; parallax is supported in the resource shape so it can be added per-stage without engine changes.

**`LevelBackground`** — a `Resource` subclass:

- `stage_backgrounds: Array[StageBackground]` — one entry per stage. Length should equal the level's stage count (currently 3); if it's shorter, the last entry repeats for any extra stages, with a warning logged.
- `boss_arena_texture: Texture2D` — held as the static backdrop during boss fights, after the active stage's strip has fully scrolled past the bottom of the viewport. May be null, in which case the background freezes on whatever it was showing.

### New scene + script

**`ScrollingBackground.tscn` + `ScrollingBackground.gd`** — `Node2D` with internal child for the current stage's strip (and optional parallax layers). Public surface:

- `@export var level_background: LevelBackground` — set per-level in the Inspector.
- `set_stage(stage_index: int) -> void` — called when the level transitions stages; swaps the active strip texture, resets scroll position to top.
- `on_boss_spawned() -> void` — called when the stage's boss spawns; transitions the visible backdrop to `level_background.boss_arena_texture` (immediate swap acceptable for v1; cross-fade is a depth feature).
- `on_boss_died() -> void` — called when the boss dies; either returns to scrolling (if next stage is coming) or freezes (if LEVEL CLEAR). The level handles the actual stage transition; the background just responds.

Internally: `_process(delta)` advances the strip's `position.y` by `scroll_speed * delta`. When the strip's bottom edge reaches the top of the viewport (i.e. it has fully scrolled past), the background switches to `boss_arena_texture` *or* holds on the strip's last row, depending on stage state. Parallax layers, if present, scroll at their own multipliers via Godot's built-in `ParallaxBackground` mechanism.

This module is deep: a single resource in, three lifecycle calls from `LevelBase`, no public state.

### `LevelBase` integration (no `LevelBase` changes)

The `LevelBase` from issue #12 already exposes a `background_scene: PackedScene` slot and instantiates it on `_ready`. This PRD's deliverable is a `ScrollingBackground` instance configured with a `LevelBackground.tres` and a small wiring script (or inline `_ready` lookup) that calls `set_stage`, `on_boss_spawned` and `on_boss_died` in response to `LevelBase`'s existing signal flow. The wiring lives in the per-level scene or in `ScrollingBackground.gd` (the latter is cleaner — `ScrollingBackground` finds its parent `LevelBase` in `_ready` and connects to its signals).

If `LevelBase` does not yet emit `on_boss_spawned` as a distinct signal from the existing `GameManager.on_boss_spawned` autoload, this PRD adds the signal (a one-line emit forwarded from the existing handler) — no behavioural change.

### Level 1 (Ocean) migration — the tracer

Replace Level 1's `Background.tscn` instance with a `ScrollingBackground` instance configured for the ocean. Author placeholder art:

- **Three stage strips** (one per stage), each viewport-width (540 px) × some stage length (target ~2000–3000 px each for v1). Visual content is intentionally placeholder-quality — what matters is that each strip is *visibly different from the others* and that the pre-boss region of each strip contains an obvious landmark (e.g. Stage 1's strip ends with a buoy field, Stage 2's with a row of debris, Stage 3's with a fortress silhouette). The strips communicate "different stage, different place, boss coming" — visual polish is a follow-up.
- **One boss-arena texture** — a static ocean tile suitable for repeating-fill during boss fights. Simplest: a tileable water texture matching the strips' base water palette.
- **Optional parallax layer** — if cheap, a slow-scrolling cloud layer behind the strips. If it complicates v1, skip and ship without parallax.

Result: playing Level 1 shows ocean scrolling distinctly through three stages, each ending with an obvious landmark just before its boss spawns, then settling onto the arena texture during the fight.

### Levels 2 and 3 — not touched

`LevelLand.tscn` continues to use `MovingLandBackground.tscn` in its `background_scene` slot. `Level03.tscn` continues to use `JungleBackground.tscn`. These migrations are follow-up PRDs (one per level). The procedural scripts stay in the codebase until then.

### Cleanup ticket (not in this PRD)

Once Level 2 and Level 3 are migrated to `ScrollingBackground`, a final cleanup ticket deletes `Background.gd/tscn`, `JungleBackground.gd/tscn`, `MovingLandBackground.gd/tscn` and the tree/grass atlas assets that only those scripts reference. Out of scope here.

## Testing Decisions

- **No automated tests.** Same rationale as PRDs #1, #8 and #12 — no test framework yet (issue #2 open). Failure modes (strip doesn't appear, scroll juddery, wrong strip on stage change, boss arena doesn't lock in) are all visible in editor playtest.
- **Manual verification checklist** for the implementing agent:
  - Load Level 1 from main menu — ocean Stage 1 strip scrolls smoothly from top of viewport downward.
  - Reach Stage 1 boss threshold — landmark from the end of Stage 1's strip appears just before boss spawns.
  - Boss fight — background locks onto the boss-arena texture (static or freezes on strip-end if `boss_arena_texture` is null).
  - Kill Stage 1 boss — transition to Stage 2: visibly different strip starts scrolling from top.
  - Repeat through Stage 3 and LEVEL CLEAR.
  - Level 3 (Jungle) and LevelLand still look exactly as they do today — no regression on un-migrated levels.
- **What good tests would look like** when #2 resolves: `ScrollingBackground.set_stage(i)` swaps the active texture to `level_background.stage_backgrounds[i].strip_texture`; scroll position resets to 0 on stage change; `on_boss_spawned()` swaps to `boss_arena_texture`; behaviour with `boss_arena_texture = null` does not crash. All assertable on resource state and node properties, no rendering required.

## Out of Scope

- Real polished ocean art for Level 1 — placeholder strips ship here, polish is a follow-up PRD.
- Migration of Level 3 (Jungle) and LevelLand to the new system — separate per-level PRDs.
- Deletion of `Background.gd`, `JungleBackground.gd`, `MovingLandBackground.gd` and associated tree/grass atlases — cleanup ticket after all three levels migrated.
- Cross-fade transitions between stage strips, between strip and boss-arena texture, or during LEVEL CLEAR — depth features, deferred.
- Parallax beyond the optional single back-layer on Level 1 — the resource shape supports more, but adding tuned multi-layer parallax is per-level art work, not foundation.
- Landmarks as separate overlay nodes — baked into the strip in v1. Revisit if hand-authoring proves limiting.
- Animated landmark sprites (e.g. a rotating radar dish on the fortress) — the strip system is static; animated landmarks would need an overlay-node revisit. Out of scope.
- Per-stage background music swap synchronised to stage transitions — separate audio PRD; today's per-level music persists across all stages of that level.
- Editor tooling for previewing scroll/landmark placement outside playtest — nice-to-have, not foundation.

## Further Notes

- Anchored in [ADR 0003](../adr/0003-hand-authored-backgrounds.md).
- Glossary terms used (from `CONTEXT.md`): **level**, **stage**, **encounter**.
- Sequencing: depends on issue #12 (LevelBase) being merged. The `background_scene` slot on `LevelBase` is the integration point.
- Coexistence: `ScrollingBackground` is a per-level opt-in via the `background_scene` slot. Migrated levels use it; un-migrated levels keep their procedural backgrounds. The new and old systems coexist cleanly until the cleanup ticket.
- Godot-MCP is configured for this workspace as of 2026-05-19 (see [reference memory](../../.claude/memory/reference_ocelot_godot_mcp.md)). Sessions started after that date should see MCP tools and should prefer them for the placeholder strip authoring, scene wiring, and resource creation in this PRD. Sessions started before need a restart to pick up the tools.
- The "baked landmarks in strip" call is deliberately the simpler v1. If, during Level 2 or Level 3 migration, hand-authoring landmarks into 3000-px strips becomes painful (e.g. you want to reposition a landmark to better pace the stage and that means re-exporting the PNG), promote landmarks to overlay nodes in a follow-up PRD. Don't over-engineer for that future now.
- The `LevelBase`'s "background_overrides" dictionary fallback (from PRD #12) is *not* used by `ScrollingBackground` — the background's per-instance configuration lives in `level_background: LevelBackground` exported directly on `ScrollingBackground`, not in the parent's dictionary. The fallback existed for properties on the procedural backgrounds (`sand_bias`, `show_road`, etc.) and becomes irrelevant for any level migrated to the new system.
