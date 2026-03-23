# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ocelot is a 2D top-down scrolling shooter game built with **Godot 4.5.1**, targeting mobile (540x960, 9:16 aspect ratio) with GL Compatibility rendering. No external build tools — it's a native Godot project.

## Development Workflow

- Open `project.godot` in Godot 4.5+ to develop and run the game
- Main entry: `res://ui/SplashScreen.tscn` → MainMenu → Level scenes
- Save data persists to `user://savegame.tres`
- Export via Godot's built-in export templates (Android/iOS/Web/Desktop)

There is no CLI build system, test runner, or lint command — all development happens inside the Godot editor.

## Architecture

### Autoloaded Singletons (`scripts/`)

- **GameManager.gd** — Central state: score, high score, volumes, unlocked levels. Handles save/load (`SaveGame` resource), programmatic input mapping, and emits signals for boss health/spawn/death and score updates. Input actions are registered here at `_ready()` — do not add them in the editor.
- **SoundManager.gd** — Music crossfading via tweens; SFX via dynamic AudioStreamPlayer pooling (new players created on demand to avoid lag).

### Physics Layers

| Layer | Name |
|-------|------|
| 1 | Player |
| 2 | PlayerProjectile |
| 3 | Enemy |
| 4 | EnemyProjectile |
| 5 | World |
| 6 | PowerUp |

### Actors (`actors/`)

- **Player.gd** — Health, movement (400 px/s, viewport-clamped), 3-level weapon system, bomb mechanic (clears all enemy projectiles + deals AoE damage), invincibility frames, dynamic sprite loading by weapon level and damage state.
- **Enemy.gd** — Base class: downward movement (150 px/s), timer-based projectile spawning, 30% power-up drop on death.
- **Boss.gd** — Sinusoidal horizontal + slow descent movement, 50 HP, 5000 score on death. Reports health to GameManager via signals.
- **Ship.gd / Tank.gd / Train.gd / Truck.gd** — Enemy specializations with player-tracking turrets. Train follows a `PathFollow2D` path.
- **EnemySpawner.gd** — Spawns random enemy mix; switches to boss encounter at 2000 score.

### Objects (`objects/`)

Projectile types: `Bullet` (player, upward 600 px/s), `EnemyBullet` (downward 300 px/s), `TurretBullet` (directional), `TankBullet`, `ShipBullet`. Also: `Explosion`, `PowerUp` (weapon level +1), `BombPickup`.

### Backgrounds (`objects/`)

- **Background.gd** — Simple parallax for the space level.
- **MovingLandBackground.gd** — Procedural ground using `FastNoiseLite`: 5 columns of 128px tiles, sand/grass biomes, road, rocks/bushes/buildings, continuous row recycling.

### UI (`ui/`)

`SplashScreen` (video) → `MainMenu` → levels. `HUD` shows score and bomb count. `PauseMenu` and `OptionsMenu` handle volume sliders (Master/Music/SFX via `GameManager.update_volume`).

### Key Signals

| Signal | Source | Purpose |
|--------|--------|---------|
| `on_score_updated(score)` | GameManager | HUD score refresh |
| `on_boss_spawned` | GameManager | Show boss health bar |
| `on_boss_health_changed(hp)` | GameManager | Update boss health bar |
| `on_boss_died` | GameManager | Hide boss health bar |
| `shoot_projectile` | Player | Emitted after each volley fires (no args) |
| `on_bomb_count_changed(count)` | Player | HUD bomb count |

### Editor Scripts (`scripts/`)

- **SetupInputs.gd** — `@tool` script; run once in editor to register input actions (normally handled by GameManager at runtime).
- **SetupExplosionResource.gd** — `@tool` script; parses JSON sprite sheet to generate `ExplosionFrames.tres`.
