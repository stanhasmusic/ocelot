# Ocelot

A 2D top-down scrolling shooter for mobile (540×960, Godot 4.5.1). This glossary defines the in-game vocabulary used to talk about encounters, threats, and visual readability.

## Language

**Threat tier**:
The behavioural class of an enemy projectile — what the player has to *do* to dodge it. Colour-coded for readability at a glance.
_Avoid_: Difficulty, level (those refer to the encounter, not the projectile).

**Straight tier** (blue):
A projectile that travels on a fixed vector with no targeting. Predictable — dodged by stepping aside.

**Aimed tier** (orange):
A projectile fired toward the player's position at the moment of firing. Punishes standing still — dodged by movement.

**Pattern tier** (purple):
A projectile that's part of a multi-shot pattern (fan, spread, homing). Reserved for bosses and rare elites — dodged by reading the pattern.

**Player shot** (yellow/white):
Any projectile fired by the player. Visually distinct from all enemy tiers so ownership is never ambiguous.

**Level**:
The player-facing unit shown on Level Select (e.g. "Desert", "Space"). One level contains a fixed number of stages and a final boss.

**Stage**:
An internal escalation within a level. Each stage ends with its own boss fight; clearing the last stage clears the level. Currently 3 stages per level.

**Stage intro**:
The first ~30–45 seconds of every stage. Hand-authored timeline of spawns that teaches the stage's new enemy or pattern before procedural spawning takes over. Also where the "STAGE N" banner shows.

**Procedural body**:
The portion of a stage after the intro, where enemies are drawn from a weighted spawn table with knobs for rate and difficulty scaling.

**Encounter**:
A sequence of enemy spawns culminating in a boss. One per stage; ends when the stage boss dies.

## Relationships

- A **level** contains N **stages** (currently 3); clearing the last stage clears the level
- A **stage** is one **stage intro** followed by one **procedural body**, ending in a boss
- Every **enemy projectile** belongs to exactly one **threat tier**
- A **threat tier** maps to exactly one colour (blue / orange / purple)
- **Player shots** never share a colour with any **threat tier**
- An **encounter** may use projectiles from any combination of tiers; pattern-tier is boss-gated

## Example dialogue

> **Dev:** "I'm adding a new turret enemy that leads the player by 30°. What sprite does its bullet use?"
> **Designer:** "It's leading the player, so it's **aimed tier** — orange. Doesn't matter what the turret looks like; the bullet colour is decided by behaviour, not by the shooter."

## Flagged ambiguities

- "Bullet" was used both for any projectile and for the player's basic shot. Resolved: **projectile** is the umbrella term; **player shot** is specifically the player's. Rocket, fan, shell, etc. are all projectiles.
