# PRD: Threat-tier projectile sprite rewire

## Problem Statement

Projectile sprites in Ocelot don't currently encode any consistent meaning. The player sees the same blue bullet fired by themselves and by enemies, the same blue bullet fired in straight lines and in aimed lines, and the boss's signature attack rendering as a near-black shape that looks more like a missing sprite than an intentional weapon. There is no visual rule that tells the player "this is mine," "this is dodgeable by stepping aside," or "this is leading me."

Two concrete symptoms:

1. **Ownership ambiguity.** `PlayerBullet` and `EnemyBullet` share the same blue sprite, so in dense combat the player can't immediately tell which projectiles came from them.
2. **Boss fan-attack reads as a bug.** `BossL3`'s fan attack uses `TurretBullet`, which is wired to an unintended atlas region of `ground_units.png` — a dark shadow shape, not a bullet. The single most-visible attack in the game looks broken.

A subtler symptom: as more enemies are added (the (B) side of the foundation goal), each new enemy type contributes a new projectile with no convention to follow, so visual drift compounds.

## Solution

Adopt the threat-tier colour convention defined in ADR 0001: enemy projectiles are coloured by **how the player must dodge them**, not by who fired them. Player projectiles get a distinct ownership colour that never collides with any enemy tier. Concretely:

- **Player** = yellow (modulated from the existing blue bullet sprite)
- **Straight tier** = blue (`bullet_2_blue`) — predictable line shots
- **Aimed tier** = orange (`bullet_2_orange`) — projectiles directed at the player at fire time
- **Pattern tier** = purple (`bullet_2_purple`, `rocket_purple`) — spreads, fans, homing — reserved for bosses and elite enemies

Audit the existing 8 projectile scenes, classify each by behaviour, and rewire any whose sprite contradicts its tier. Most scenes are already correctly coloured — the rewire is small and surgical (3 scenes), but it establishes the convention as the visible rule going forward.

## User Stories

1. As a player, I want my own bullets to look visibly different from enemy bullets, so that I can immediately tell which projectiles on screen are threats.
2. As a player, when I see a blue enemy bullet, I want to know it will travel in a straight line, so that I can dodge it by stepping aside without watching it.
3. As a player, when I see an orange enemy bullet, I want to know it was aimed at where I was, so that I learn to keep moving instead of standing still.
4. As a player, when I see a purple enemy bullet, I want to know I'm facing something more dangerous than a regular grunt, so that I read the moment as "pay attention."
5. As a player fighting the third boss, I want its signature fan attack to look like real projectiles, so that the encounter feels designed rather than broken.
6. As a player, I want the visual rule to be consistent across all levels, so that the lesson I learn in Level 1 still applies in Level 3.
7. As a player encountering a new enemy type for the first time, I want its bullet colour to tell me how to dodge it before I've had to learn the enemy, so that the game teaches itself.
8. As a developer adding a new enemy, I want a documented rule for which sprite to use, so that I don't have to invent the answer on the fly.
9. As a developer adding a new boss, I want pattern-tier (purple) projectiles to be available as a class, so that bosses feel mechanically distinct from grunts at a glance.
10. As a developer reviewing a pull request, I want the projectile colour convention to be auditable from the scene file alone, so that I can spot a tier violation without running the game.

## Implementation Decisions

### Scenes that need editing

Three projectile scenes have sprites that contradict their behaviour and must be rewired:

- **`PlayerBullet`** — currently uses the same blue sprite as enemy straight-tier. Differentiation strategy is to **modulate the sprite to yellow** (`Color.YELLOW` on the `Sprite2D.modulate` property) rather than introduce a new asset. This is the lowest-cost path to ownership clarity: zero new art, instant visual distinction, easy to revert or swap to a dedicated asset later.
- **`TankBullet`** — currently uses the blue (straight-tier) sprite, but the projectile is direction-aimed by the tank's turret rotation. Swap to `bullet_2_orange`.
- **`TurretBullet`** — currently uses an unintended atlas region of `ground_units.png` (a dark shadow shape). Replace the texture reference with `bullet_2_orange`, removing the `AtlasTexture` sub-resource and the `ground_units.png` `ext_resource`. Existing `rotation` and `CollisionShape2D` stay as-is; the visible silhouette will change but the hit-box won't.

### Scenes that need verification only (no expected change)

- **`EnemyBullet`** — straight-down trajectory, blue sprite. Tier-correct.
- **`ShipBullet`** — direction-aimed, orange sprite. Tier-correct.
- **`InterceptorBullet`** — direction-aimed (uses `TurretBullet.gd` script), orange sprite. Tier-correct.
- **`BomberBullet`** — fired as a 5-bullet spread by `Bomber.gd`, purple sprite. Pattern-tier; tier-correct because the spread mechanic qualifies as pattern even though the bomber is not a boss.
- **`RocketBullet`** — homing, purple sprite. Pattern-tier; tier-correct.

Each of these gets a brief look during implementation to confirm nothing has drifted; no edits expected.

### What is not changing

- No script logic. All edits are scene/resource edits.
- No new projectile scripts, no new shared base class, no `tier` annotation on scripts. ADR 0001 + asset-naming convention is the source of truth at this scale (8 projectile types).
- No new art assets. The `bullet_2_blue/orange/purple` assets already exist in `assets/sprites/aircrafts2/` and cover the convention; the player's yellow comes from a modulate, not a new file.
- Animated bullet frames (`bullet_blue/orange/purple0000-0004.png`) remain unused. They're a candidate for future polish (e.g. animated pattern-tier projectiles for boss attacks) but not part of this PRD.

### Modules touched

This PRD modifies three Godot scene files and edits no scripts. There is no deep module to extract: 8 projectile types is below the threshold where a shared `ProjectileBase` or `ProjectileTier` resource would pay off. The convention is enforced socially (ADR + review) rather than structurally (code) at this scale; if the projectile count grows past ~15 the calculus changes and a tier resource becomes worth proposing.

## Testing Decisions

- **No automated tests.** Same rationale as PRD #1: the project has no test framework, and this PRD is asset/scene rewiring — the failure modes (wrong colour, broken sprite reference, accidentally swapped collision shape) are all visible in 60 seconds of editor playtest.
- **Manual verification checklist** for the implementing agent / reviewer:
  - Play Level 1; player bullets are visibly yellow, distinct from any enemy bullet.
  - Spawn a Tank (or trigger one in Level 1); its turret bullets are orange, not blue.
  - Reach `BossL3` (currently triggers at score threshold); the fan attack shows orange bullets, not the previous shadow shape.
  - No projectile scene shows a missing-sprite placeholder or broken AtlasTexture reference.
- **Good test (if a framework existed)** would assert the externally observable fact: each projectile scene's sprite texture matches its declared tier colour. The internal mechanism (modulate vs different file) is implementation detail.

## Out of Scope

- Adding new projectile scripts, refactoring projectile inheritance, or introducing a shared base class.
- Tier annotation on projectile scripts (deferred — premature at 8 types).
- Using the unused animated bullet frames (`bullet_*0000-0004.png`) — separate polish PRD if/when wanted.
- Muzzle flashes, impact effects, projectile trails, particle systems (separate visual-polish PRD).
- Repainting the player sprite to a yellow theme (this PRD only changes the player's *projectile* colour, not the ship).
- Audio cues per projectile tier (separate audio-design PRD).
- The dedicated player-bullet asset that might replace the yellow modulate later — that's a future swap if the modulate looks bad in playtest.

## Further Notes

- Anchored in [ADR 0001](../adr/0001-projectile-colour-by-threat-tier.md). The PRD's job is to apply the ADR to existing scenes; the ADR's job is to be the rule new scenes follow.
- Glossary terms used (from `CONTEXT.md`): **threat tier**, **straight tier**, **aimed tier**, **pattern tier**, **player shot**, **projectile**.
- The boss fan-attack fix (in `TurretBullet`) is the single highest-visibility change in this PRD — it's the bug that prompted the original conversation. Worth playtesting that encounter specifically.
- If the yellow modulate reads as "too cheap" or clashes with the player ship's existing palette, the fallback is a dedicated player-bullet asset. Defer that decision until after a playtest.
- Bomber is the only non-boss enemy using pattern tier, justified by its 5-bullet spread mechanic in `Bomber.gd`. If more grunts get pattern attacks, ADR 0001's "pattern-tier is boss-gated except for true elites" rule will need re-examination — flag in code review of any such addition.
