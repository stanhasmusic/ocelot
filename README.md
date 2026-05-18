# ocelot

2D top-down scrolling shooter built in Godot 4.5.1. mobile-first (540×960, 9:16), GL Compatibility renderer.

learning project — don't expect polish.

## what it is

classic shmup gameplay: dodge enemy fire, shoot things, pick up power-ups, fight a boss.
score-based progression with a handful of enemy types and a procedurally generated ground background.

## stack

- **engine:** Godot 4.5.1
- **language:** GDScript
- **target platforms:** Android / iOS / Web / Desktop (via Godot export templates)

## running it

open `project.godot` in Godot 4.5+. no build step, no CLI — everything runs in the editor.

## features

- 3-level weapon system + bomb mechanic
- enemy variety: ships, tanks, trains, trucks — each with tracking turrets
- boss encounter triggered at 2000 score
- procedural land background (FastNoiseLite — sand/grass biomes, road, buildings)
- music crossfading, SFX pooling
- save/load for score, high score, and unlocked levels

## status

active development. rough around the edges.
