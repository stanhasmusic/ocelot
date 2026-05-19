# PRD: LevelBase scene inheritance

## Problem Statement

Every level scene (`Level01.tscn`, `Level03.tscn`, `LevelLand.tscn`) duplicates the same set of fixed children — `Player`, `Camera2D`, `EnemySpawner`, `HUD`, `PauseMenu`, `StageOverlay` — even though the script driving them is already shared (`Level01.gd`). The duplication is purely at the scene-tree level.

Concrete consequences:

1. **Every HUD / pause / overlay change is a three-place edit.** Adding a new HUD element, fixing a pause-menu bug, or changing the camera position means touching `Level01.tscn`, `Level03.tscn` and `LevelLand.tscn` identically. Easy to miss one.
2. **Adding a new level is a copy-paste job.** The (A) goal of "more levels" inherits all of this duplication — Level 4 would start by copying Level 3's scene tree and swapping art, which is exactly the kind of work that fossilises bugs.
3. **The script is named after one of its instances.** `scripts/Level01.gd` runs `Level01`, `Level03` and `LevelLand` — the name lies about what it is, which is the universal level controller.
4. **The next foundation PRD (#8 / #9, hybrid difficulty) wants a single target.** When `Array[StageConfig]` lands, it should live on one script file driving all levels, not in three scene-tree duplicates.

## Solution

Introduce a `LevelBase.tscn` + `LevelBase.gd` pair that owns all the universal furniture once. Each per-level scene becomes an **inherited scene** from `LevelBase.tscn`, overriding only what's actually per-level: the background scene, the music stream, and the existing `EnemySpawner` Inspector exports.

Background is the one non-trivial bit. Godot scene inheritance handles property overrides cleanly but is awkward when the inherited node is itself an instance of a different scene per child. So the background is wired script-side: `LevelBase` has a `BackgroundSlot` placeholder `Node2D` and a `background_scene: PackedScene` export; on `_ready` the base instantiates `background_scene` as a child of the slot.

After this PRD: `Level01.tscn`, `Level03.tscn` and `LevelLand.tscn` are thin inherited scenes. Each is essentially a `.tscn` containing "I inherit from `LevelBase`, my background is X, my music is Y, my spawner pool is Z." All HUD / camera / pause / overlay changes happen once, in `LevelBase.tscn`.

## User Stories

1. As a developer, I want to fix a HUD bug in one place, so that the fix propagates to every existing level without three identical edits.
2. As a developer, I want to add a new level by creating a new inherited scene and choosing a background and music, so that adding Level 4 doesn't start with copying Level 3's entire node tree.
3. As a developer reviewing a PR that touches `LevelBase`, I want to be confident the change affects every level identically, so that I don't have to grep three scene files to verify consistency.
4. As a developer working on the hybrid difficulty system (#9), I want a single script file (`LevelBase.gd`) to add `Array[StageConfig]` to, so that the stage configuration substrate lands in one place rather than being duplicated across per-level scripts.
5. As a developer reading the script that runs levels, I want its name to describe what it is, so that I don't have to know historical accident to find it.
6. As a player, I want every level to behave consistently with respect to pause, HUD updates, and stage banners, so that the game's interaction model doesn't subtly differ between levels.
7. As a developer adding a new universal feature later (e.g. a "lives remaining" display, a "press to use bomb" hint, an end-of-stage score callout), I want one place to add it that automatically applies to every level.
8. As a designer (future), I want per-level differences to be visible as a short list of Inspector overrides on the level's scene, so that "what makes Level 3 different from Level 1" is a glance at a property panel rather than a scene-tree diff.

## Implementation Decisions

### `LevelBase.tscn` structure

Root `Node2D` named `LevelBase`. Fixed children, all currently present in every level today:

- `BackgroundSlot` — empty `Node2D`. Background scenes are instantiated as children of this at runtime by `LevelBase.gd`. No instance attached in the base.
- `Player` — instance of `actors/Player.tscn`, positioned at the current `(270, 850)`.
- `Camera2D` — at the current `(270, 480)`.
- `EnemySpawner` — instance of `objects/EnemySpawner.tscn`, positioned at the current `(270, -50)`. Its Inspector exports (enemy scenes, boss scenes, HP arrays, etc.) are left at defaults in the base; per-level scenes override these via scene-inheritance property overrides. When #9 lands, this surface area collapses and only `Array[StageConfig]` is overridden per level.
- `HUD` — instance of `ui/HUD.tscn`.
- `PauseMenu` — instance of `ui/PauseMenu.tscn`.
- `StageOverlay` — instance of `objects/StageOverlay.tscn`.

The script attached to the root is `scripts/LevelBase.gd`.

### `LevelBase.gd`

Rename of `scripts/Level01.gd`. Same stage-progression logic. New surface:

- `@export var background_scene: PackedScene` — the per-level background. May be null only during base-scene authoring; per-level scenes must set it.
- `@export var level_music: AudioStream` — unchanged from today.
- In `_ready`, after the existing music + signal-wiring code, instantiate `background_scene` and `add_child` it to `BackgroundSlot`. If `background_scene` is null, log a warning (the level will run, just with no backdrop).

Stage state (`current_stage` / `stage_index` per #5), `TOTAL_STAGES`, `_on_boss_died`, `_start_stage_transition`, `_input` for pause — all unchanged in behaviour; just relocated and renamed.

### Per-level scene migration

`Level01.tscn`, `Level03.tscn` and `LevelLand.tscn` are each replaced by inherited scenes from `LevelBase.tscn`. Each sets, via scene-inheritance overrides:

- `background_scene` (the per-level `PackedScene`: `Background.tscn`, `JungleBackground.tscn`, `MovingLandBackground.tscn` respectively — the last is still consumed in this PRD; ADR 0003's deprecation lands in the next PRD)
- `level_music` (the per-level audio stream)
- Any `EnemySpawner` Inspector overrides that currently differ per level (today: enemy pools, boss scenes, stage intervals, HP arrays)
- Any per-level background property overrides currently present in the scene (e.g. `LevelLand.tscn` sets `sand_bias = 1.1`, `show_road = false`, `water_columns = [0, 4]` on its background — these move to the inherited scene's override of `BackgroundSlot`'s child once the background is instantiated; if scene inheritance can't express overrides on a runtime-instantiated child, the per-level scene attaches an inline child script or sets the properties in an `_ready` hook on the level's own script extension)

All three migrated scenes preserve their existing `uid://` strings where possible so the rest of the project's references don't break.

### Background property overrides — fallback plan

Scene inheritance can't override properties on nodes that don't exist at base-author time. `LevelLand.tscn`'s per-instance background tweaks (`sand_bias`, `show_road`, `water_columns`) are the immediate test case. Two acceptable approaches; implementer picks:

- **Inline configuration export**: add `@export var background_overrides: Dictionary = {}` on `LevelBase.gd`; after instantiating the background, apply each `key, value` pair via `set()`. Per-level scenes set the dictionary in the Inspector.
- **Per-level extension script**: if the level needs custom logic, the per-level scene attaches a small script that `extends "res://scripts/LevelBase.gd"` and overrides `_configure_background(bg)`. `LevelBase` calls this hook after instantiation.

Both are fine; the first is preferred for purity (no per-level scripts), the second is fine if it turns out exports get noisy. This is a low-stakes call — easy to revisit.

### What stays out of LevelBase

- `EnemySpawner` stays a *child* of `LevelBase`, not absorbed into it. The spawner is its own scene and node with its own responsibilities; collapsing it into the base would couple unrelated concerns.
- Music playback stays driven by `LevelBase.gd` via `SoundManager.play_music`, unchanged. No bus or audio routing change in this PRD.

### Renames and file moves

- `scripts/Level01.gd` → `scripts/LevelBase.gd`. Update the `ext_resource path` in each inherited scene.
- `scripts/Level01.gd.uid` (if Godot generated one) is regenerated or carried through; verify project still opens cleanly.

## Testing Decisions

- **No automated tests.** Same rationale as PRDs #1 and #8 — no test framework yet (issue #2 open). The failure modes here (background doesn't appear, HUD missing, pause broken on some level, scene-inheritance override not applied) are all visible in 60 seconds of editor playtest per level.
- **Manual verification checklist** for the implementing agent:
  - Load Level 1 from the main menu — background appears, player moves, enemies spawn, HUD shows score, pause works, stage banner appears, can reach LEVEL CLEAR.
  - Repeat for Level 3 and LevelLand — identical structural behaviour, only background and music differ.
  - Open `LevelBase.tscn` in the editor and make a trivial change to `HUD` (e.g. move a label one pixel); reload all three levels — the change is present in every one.
  - Open one of the inherited level scenes; verify the per-level overrides are visible as Inspector overrides (yellow markers) on `background_scene` and `level_music`.
  - LevelLand's background-specific properties (`sand_bias`, `show_road`, `water_columns`) still take effect — sand-biased ground, no road, water columns at the expected positions.

## Out of Scope

- Deprecating `MovingLandBackground` / `JungleBackground` / `Background` and replacing them with hand-authored scrolling backgrounds. That's the next PRD (ADR 0003).
- Introducing `Array[StageConfig]` on `LevelBase.gd`. That belongs to PRD #8 / slice #9 — this PRD lays the ground but does not pre-empt.
- Per-level HUD variation (e.g. a level-specific objective indicator). When that need arises it can either be a hook on `LevelBase.gd` or per-level scene additions; out of scope here.
- Level Select polish (lock icons, per-level best score) — separate PRD.
- Renaming the three level scenes (e.g. `LevelLand.tscn` → `Level02.tscn` for naming consistency). The existing names are kept to minimise UID churn; revisit if it becomes friction.
- Refactoring `EnemySpawner` itself — outside this PRD's scope.

## Further Notes

- This PRD has no ADR — it's a structural refactor with no architectural surprise. The choice of "script-driven background slot" over "scene-inheritance node replacement" is a Godot-mechanics call, not a domain decision.
- Sequencing relative to PRD #8 / slice #9: this PRD ships first. When slice #9 lands, its work simplifies because it has one target (`LevelBase.gd`) rather than three. Slice #9's PRD body assumes per-level scripts; in practice it will modify `LevelBase.gd` once. No re-issue needed — the implementer can adapt at merge time.
- Sequencing relative to ADR 0003 (hand-authored backgrounds): this PRD ships first. The backgrounds PRD will modify only what the `background_scene` slot points at — `LevelBase.tscn` itself is not affected.
- The "background_overrides" dictionary fallback is deliberately the cheapest possible escape hatch — if it gets used heavily, it's a smell that the background system itself needs more structured per-instance configuration. Flag in the backgrounds PRD if so.
