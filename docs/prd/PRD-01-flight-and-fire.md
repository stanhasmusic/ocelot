# PRD-01 — Flight & Fire

> **Published as [issue #26](https://github.com/stanhasmusic/ocelot/issues/26)** (`ready-for-agent`) — the tracker is canonical.
> Phase 1 tracer-bullet slice. Implements the positional movement + always-on auto-fire model from
> ADR-0006 by refactoring the existing `Player`. Canonical design lives in `CONTEXT.md` and
> `docs/adr/0006-input-aware-controls-shared-difficulty.md`.

## Problem Statement

As a player, flying the plane doesn't feel the way a dodging game needs it to. On PC the plane only
responds to keyboard/gamepad directional input — there's no mouse control at all — and the movement is
velocity-based, so the plane accelerates and drifts rather than going exactly where I point. On touch I
get a virtual joystick (left half moves, right half shoots), which is mushy and hides the action under
my thumbs. And the gun only fires while I hold a button, so I'm constantly juggling moving *and*
shooting instead of focusing on not getting hit.

## Solution

Positional 1:1 drag-to-move: the plane chases the cursor (PC) or finger (mobile) toward a high speed
cap, clamped to the screen, so it goes precisely where I point. The gun auto-fires continuously, so the
only thing I manage is positioning and dodging. Mouse and touch share the positional model (mouse is
the tuning proxy for touch feel). The keyboard/gamepad velocity path is preserved as its own branch so
controller play and playtesting are unaffected. Every feel value lives in a tunable `PlayerTunables`
resource so feel can be iterated without code changes.

## User Stories

1. As a PC player, I want to move my plane by dragging with the mouse, so that I have precise, direct control.
2. As a player, I want the plane to track exactly where my cursor/finger is (1:1), so threading between threats feels precise rather than mushy.
3. As a player, I want my gun to fire automatically and continuously, so I can focus entirely on dodging and positioning.
4. As a player, I want auto-fire to begin the instant the level starts, so I'm never confused about why nothing is shooting.
5. As a mobile player, I want to drag my finger to move with the plane offset above my thumb, so my hand doesn't cover the plane or the action.
6. As a controller player, I want my existing stick/keyboard movement to keep working, so I can keep playing and playtesting on my setup.
7. As a player, I want the plane clamped to the screen, so I never push it off an edge and lose it.
8. As a player, when I stop moving the cursor, I want the plane to hold its position and not drift, so I can sit in a safe gap.
9. As a player, I want movement to feel snappy but not twitchy, so it's controllable for a newcomer.
10. As a player, I want a clear sense of forward motion from a scrolling background, so flight reads as flight.
11. As a player, I want the fire rate and movement to behave identically on slow and fast hardware, so the game is fair regardless of frame rate.
12. As the developer, I want every feel value (top speed, follow-tightness, fire interval, shot speed, scroll speed, finger offset) in a `.tres` I can edit without touching code, so my tuning loop is tight.
13. As the developer, I want the movement math isolated from Godot nodes and input events, so I can unit-test it deterministically.
14. As the developer, I want the auto-fire cadence isolated and unit-testable, so cadence regressions are caught automatically.
15. As the developer, I want input-scheme routing (mouse/touch → positional, pad/kbd → velocity) to be a thin layer over the pure modules, so the full auto-swap layer (PRD-03) is purely additive.
16. As the developer, I want player shots to despawn off-screen, so there is no projectile leak over a long run.
17. As the developer, I want the refactor to leave weapon level, HP, lives, and bomb logic untouched, so this slice stays small and low-risk.

## Implementation Decisions

- **Three new modules + a thin glue node:**
  - **`PlayerMovement`** — pure logic, no node/input dependencies. Interface (encodes the decision):
    ```
    next_position(current: Vector2, target: Vector2, max_speed: float,
                  follow_lerp: float, delta: float, bounds: Rect2) -> Vector2
    ```
    Moves `current` toward `target`, limited by `max_speed * delta` (with `follow_lerp` smoothing),
    result clamped to `bounds`. Deterministic; returns `current` unchanged when already at target.
  - **`AutoFireClock`** — pure logic. Interface:
    ```
    tick(delta: float) -> int   # number of volleys to fire this frame; carries the remainder
    ```
    Accumulates `delta` and emits one volley per `fire_interval`; returns >1 if a long frame spans
    multiple intervals and carries the leftover so cadence stays accurate over many small frames.
  - **`PlayerTunables`** — a `Resource` (`.tres`) holding `max_speed`, `follow_lerp`, `fire_interval`,
    `shot_speed`, `scroll_speed`, `finger_offset`. Prior art: `StageConfig.gd`.
  - **`Player.gd`** stays thin glue: detect the active scheme (mouse/touch → positional target =
    cursor / finger+offset; pad/kbd → existing velocity vector), delegate movement to `PlayerMovement`,
    call `AutoFireClock` each physics frame and spawn the existing `PlayerBullet` per returned volley,
    emit `shoot_projectile`.
- **Auto-fire is always on** — remove the hold-to-shoot gate. Bomb input is unchanged.
- **The velocity path is preserved** as the pad/keyboard branch (not deleted), so controller play keeps working.
- **Touch switches** from the virtual joystick to positional drag-to-move; the right-half touch-shoot
  region is removed (auto-fire makes it redundant). Touch action buttons are PRD-03/HUD scope.
- **Reuse** the existing `PlayerBullet` scene and an existing scrolling-background scene; no new art.
- No change to `weapon_level`, HP, lives, or bomb logic in this PRD.

## Testing Decisions

- This PRD **stands up the project's first test harness (GUT)**, satisfying the deferral trigger in
  ADR-0004 ("defer the test framework until the first testable module") — `PlayerMovement` and
  `AutoFireClock` are that first module.
- A good test asserts **external behavior, not implementation**: given inputs, assert the returned
  value/decision; no peeking at private state.
- **`PlayerMovement` tests:** moves toward the target; never overshoots beyond `max_speed * delta` in a
  tick; clamps against all four `bounds` edges; returns `current` (no drift, no NaN) when already at
  target; zero delta → no movement; very large delta → still clamped, no teleport past bounds.
- **`AutoFireClock` tests:** no volley before `fire_interval` elapses; exactly one at the interval;
  correct count when a single delta spans multiple intervals; remainder carried so cadence stays
  accurate across many sub-interval frames.
- **Prior art:** none — these are the first unit tests. Establish the `test/` layout + GUT config as
  the precedent for the later economy and spawn-table tests (PRD-04 / PRD-11).

## Out of Scope

- Full input auto-swap polish, per-input assist knobs (snap / pickup-magnet / hitbox forgiveness),
  touch action buttons, and prompt-glyph swapping → **PRD-03**.
- Replacing the `weapon_level` pickup-reset behavior so the Hangar Guns tier owns the plane sprite
  (ADR-0007) → a later weapon/Hangar PRD.
- **Player-shot colour:** shots should be yellow/white per `CONTEXT.md`, but the art library only ships
  blue/orange/purple (the enemy threat tiers). Recolouring or authoring a dedicated player-shot sprite
  is flagged here but **not done** in this slice.
- Real hand-authored backgrounds + landmarks (ADR-0003) → **PRD-14**; this slice uses an existing
  placeholder scroller.
- Enemies, collision/damage, difficulty balance → **PRD-02** and later.

## Further Notes

- This is a **refactor of `actors/Player.gd`**, which today uses velocity movement, a virtual joystick
  on touch, and manual hold-to-shoot. Going forward, treat the velocity logic as the pad/keyboard branch.
- Tune `PlayerTunables` on the **mouse** path — it's the proxy for eventual touch feel. The user
  playtests on a **controller**, which exercises the velocity branch, so confirm both feel acceptable
  under the single shared difficulty curve (ADR-0006).
- **Done =** plane chases the cursor crisply and clamps to screen; controller/keyboard still move the
  plane via velocity; gun auto-fires continuously from level start; shots despawn off-screen; all feel
  values are editable in the `.tres`; and `PlayerMovement` + `AutoFireClock` unit tests pass under GUT.
