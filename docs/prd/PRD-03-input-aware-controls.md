# PRD-03 — Input-aware controls

> **Published as [issue #28](https://github.com/stanhasmusic/ocelot/issues/28)** (`ready-for-agent`) — the tracker is canonical.
> Phase 2 slice. Implements the full auto-swapping control layer from
> [[0006-input-aware-controls-shared-difficulty]]. Depends on **PRD-01 / issue #26** (which
> establishes the positional `PlayerMovement` module + the preserved velocity branch). Canonical
> design lives in `CONTEXT.md` and `docs/adr/0006-input-aware-controls-shared-difficulty.md`.
>
> **Grounding note:** today `actors/Player.gd` hard-codes *both* schemes simultaneously — keyboard/
> gamepad velocity (`Input.get_vector` → `velocity = direction * SPEED`) *and* a touch virtual
> joystick (left half moves, right half shoots), with manual hold-to-shoot. There is **no device
> detection and no mode switching** — both input paths are always live at once. PRD-01 splits these
> into a positional branch (mouse/touch) and a velocity branch (pad/kbd). This PRD adds the layer
> that **picks the right branch automatically based on the active device** and adds the per-input
> assist knobs the shared difficulty curve relies on.

## Problem Statement

As a player, the controls don't adapt to how I'm actually playing. On PC I might be on a controller
one minute and mouse-and-keyboard the next, but the game can't tell — it tries to honour every input
at once, which is mushy and confusing. And because mobile (touch) and PC (controller) are physically
very different, a single difficulty tuning either makes the precise input trivial or makes the
imprecise input unfair. I want the game to notice what I'm holding and feel right for *that*, without
me opening a menu.

## Solution

The game watches my input and **auto-swaps the control scheme to match the device I just used**:
touch or mouse → positional drag-to-move with auto-fire; gamepad or keyboard → velocity stick/dpad
movement with auto-fire. Picking up the controller mid-game seamlessly swaps the scheme (and the
on-screen prompt glyphs) with no menu. Difficulty stays a **single shared curve** for everyone, but
each input gets its own **assist knobs** (aim/snap help, pickup magnet radius, hitbox forgiveness)
so the imprecise inputs (touch, stick) get exactly enough help to be fair against the same enemy
patterns the precise inputs (mouse) face. Mouse remains the tuning proxy for eventual touch feel.

## User Stories

1. As a player on a controller, I want the game to detect my gamepad and use stick/dpad velocity movement, so it feels native to the pad.
2. As a player on mouse + keyboard, I want the game to use positional drag-to-move on the mouse, so the plane goes exactly where I point.
3. As a player who switches from keyboard to controller mid-run, I want the scheme to swap the instant I use the new device, so I never have to open a menu.
4. As a mobile player, I want touch to use the same positional drag model as the mouse, so the feel I tuned on PC carries to my phone.
5. As a player, I want the swap to be debounced so a stray input (a controller's resting stick drift, an accidental key) doesn't flip the scheme under me.
6. As a player, I want on-screen prompts/glyphs to match my active device (keyboard key vs gamepad button vs touch button), so instructions are never wrong.
7. As a controller player, I want a tunable aim/snap assist so threading dense fire is fair on a stick, without trivialising it.
8. As a touch player, I want a tunable pickup-magnet radius so coins/pickups drift toward me, since precise positioning is harder with a thumb.
9. As a less-precise-input player, I want a tunable hitbox-forgiveness value so near-misses that *look* like misses don't kill me, keeping the shared difficulty fair.
10. As the developer, I want one shared difficulty curve plus per-input assist values, so I tune enemies once and only adjust assists per device.
11. As the developer, I want device detection isolated from the player node, so I can unit-test "which scheme should be active given this input event" deterministically.
12. As the developer, I want the assist values to live in a tunable resource, so I can iterate device fairness without touching code.
13. As a mobile player, I want on-screen action buttons (bomb, and any gadget) that appear only in touch mode, so I can use abilities without a keyboard.
14. As a player, I want auto-fire to remain always-on in every scheme, so swapping devices never changes whether I'm shooting. *(Established in PRD-01.)*
15. As a player, I want my movement clamped to the screen in every scheme, so no device lets me fly off-edge. *(Established in PRD-01.)*
16. As the developer, I want this layer to sit *on top of* the PRD-01 movement branches as pure addition, so landing it can't regress the controller path the user playtests on.
17. As a player, I want a sensible default scheme at level start (the last-used device, falling back to mouse/touch), so the game is controllable from frame one.

## Implementation Decisions

- **Device detection is a deep, pure module.** Extract an **`InputScheme` resolver** that, given a
  stream of input-event *kinds* (mouse-move/click, touch, joypad-motion/button, key) and the
  current active scheme, returns the scheme that should be active — with **debounce/hysteresis** so
  noise (stick drift below a deadzone, a single stray event) doesn't flip modes. Interface shape:
  ```
  resolve(active_scheme, event_kind, magnitude, now) -> scheme   # POSITIONAL | VELOCITY
  ```
  No node or `Input` singleton dependency — it's fed event *kinds* so it can be tested with plain
  data. `Player.gd` (or a thin `InputRouter` child) feeds real events in and applies the returned
  scheme by choosing the PRD-01 branch.
- **Two schemes, mapped to the PRD-01 branches:** `POSITIONAL` (mouse/touch → target point →
  `PlayerMovement.next_position`) and `VELOCITY` (pad/kbd → existing `Input.get_vector` velocity
  path). This PRD does **not** re-implement movement — it *selects* between the branches PRD-01
  already built.
- **Assist knobs live in a resource.** Extend the tunables (or add a sibling `InputAssistTunables`)
  with per-scheme values: `aim_snap_strength` (velocity/stick), `pickup_magnet_radius` (all, biggest
  on touch), `hitbox_forgiveness` (shrinks the effective player hurtbox for imprecise inputs). One
  shared difficulty curve elsewhere; these are the only per-device dials.
- **Pickup magnet** is implemented where pickups already live (they currently fall straight at
  100px/s): within `pickup_magnet_radius` of the player, steer toward the player. Radius `0` = today's
  behaviour, so the default for mouse can stay 0.
- **Hitbox forgiveness** adjusts the player's collision shape scale by `hitbox_forgiveness`; default
  `1.0` = unchanged. Pure data → no new collision logic, just a scale applied at scheme-select.
- **Prompt-glyph swap + touch action buttons** live in the HUD layer: the active scheme is published
  (a signal or shared state) and the HUD shows keyboard/gamepad/touch glyphs and reveals on-screen
  buttons (bomb today; gadget later) only in `POSITIONAL`-touch context. Touch-button presses route
  to the same `drop_bomb()` the keyboard path already calls.
- **Default scheme** at scene start = last-used device if known, else `POSITIONAL` (mouse/touch),
  matching the user's PC mouse-proxy workflow.
- **Replaces** the old always-both behaviour: the virtual-joystick code removed in PRD-01 is not
  reintroduced; the right-half touch-shoot region stays gone (auto-fire covers it).

## Testing Decisions

- A good test asserts **external behaviour, not implementation**: feed the resolver a sequence of
  event kinds + magnitudes + timestamps and assert the resulting scheme; never inspect internal
  timers directly.
- **`InputScheme` resolver tests:** a mouse-move while in VELOCITY swaps to POSITIONAL; a joypad
  button while in POSITIONAL swaps to VELOCITY; a sub-deadzone stick magnitude does **not** swap
  (hysteresis); two rapid conflicting events within the debounce window don't thrash; identical
  repeated events are idempotent; a cold start with no prior device returns the default scheme.
- **Assist application** is a thin data mapping (radius/scale/strength) — covered by the resolver +
  movement tests already; no separate behavioural suite needed unless the magnet steering grows
  logic, in which case test "pickup within radius moves toward player, outside radius does not."
- **Prior art:** `PlayerMovement`/`AutoFireClock` (PRD-01) and `ThreatTier`/`CheckpointState`
  (PRD-02) — same GUT `test/` layout. Add the resolver test file in that shape.

## Out of Scope

- **Per-platform export/build config** (touch build, store packaging) → **PRD-19**.
- **Real on-device phone validation** of touch feel → **PRD-19** (the standing playtest gap:
  [[project_playtest_setup]]).
- **Final assist *values*** — this PRD ships the knobs and sane defaults; dialling them to "fair" is
  a Together playtest loop, not a code deliverable.
- **Gadget action buttons beyond bomb** — the HUD button framework should accommodate them, but
  gadgets themselves are **PRD-09**.
- **Rebindable controls / options-menu input config** — not in this slice.

## Further Notes

- This is **additive over PRD-01**: if PRD-01 isn't merged, this PRD's branch-selection has nothing
  to select between. Sequence #26 first.
- The user **playtests on a controller and on mouse/kbd**, so both branches must stay first-class;
  treat the **mouse positional path as the touch proxy** and confirm the controller velocity path
  still feels right under the *same* difficulty curve (ADR-0006).
- Debounce timing is itself a feel value — expose it as a knob rather than hard-coding, so the swap
  feels instant-but-stable without a recompile.
- **Done =** picking up a controller mid-game swaps movement to velocity and flips the HUD glyphs;
  dropping to mouse swaps back to positional; stray/idle inputs don't thrash the scheme; touch shows
  on-screen action buttons; per-input assist knobs exist in a `.tres`; and the `InputScheme` resolver
  unit tests pass under GUT.
