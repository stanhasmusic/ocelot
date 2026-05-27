# PRD-17 — Onboarding / FTUE

> **Published as [issue #43](https://github.com/stanhasmusic/ocelot/issues/43)** — the tracker is canonical.
> Phase 5 slice. Implements the onboarding model decided in
> [[0013-invisible-onboarding-no-tutorial]]. Canonical design lives in `CONTEXT.md` and that ADR.
>
> **Grounding note:** this PRD is *design-complete but build-gated*. It depends on a playable core
> loop plus the things it teaches — threat tiers (**PRD-02 / #27**), the bomb (**PRD-06 / #31**),
> input-aware controls (**PRD-03 / #28**), and the Level-1 content that hosts it (**PRD-14 / #37**).
> None of those are merged yet. What #43 delivers *now* is the **teaching spec** (the L1S1 beat-sheet
> + hint rules below); the "validated with a non-gamer" acceptance criterion is gated on a real phone
> build and so closes alongside **PRD-19 / #44**. Grilled 2026-05-26.

## Problem Statement

As a non-gamer picking this up for the first time, I don't read manuals and I don't want a tutorial
that makes me sit through a lesson before I can play. I need to *understand* how to move, how to
shoot, what the bomb does, and what the coloured incoming fire means — within my first minute — purely
by playing. If I'm confused, I want a nudge exactly when I'm stuck, not a wall of tooltips. And it has
to feel like an arcade game I can jump straight into, including the second and tenth time I start a
new run — not a tutorial I'm forced to replay. This is the make-or-break experience for the
noob/mid-tier audience the game is for.

## Solution

Onboarding is **invisible**: the first stage of Level 1 (Pacific Beachhead) is *authored* to teach
through the order and spacing of what it spawns, and a thin layer of **self-suppressing contextual
hints** catches the player only when they demonstrably need help. Auto-fire means shooting teaches
itself; drag-to-move is intuitive; the bomb is taught by a designed, survivable swarm that makes the
on-screen button irresistible. The threat-tier **colour language** (blue = step aside, orange = keep
moving) is taught by clean contrast — a lone blue **Straight-tier** shooter, then an orange
**Aimed-tier** shot that punishes the spot blue made feel safe — with a one-line failure-hint as the
safety net. There is **no tutorial level, no popups, and no first-run flag**: competence suppresses
the hints, so veterans are never nagged and there is no onboarding state to reset on **New Game**.

## User Stories

1. As a first-time player, I want to start moving and shooting immediately, so the game feels like an arcade jump-in, not a lesson.
2. As a confused newcomer, I want a "DRAG TO MOVE" nudge to appear *only* if I haven't moved in the first couple of seconds, so I'm helped exactly when stuck and never otherwise.
3. As a player, I want auto-fire on from frame one, so I never have to be taught to shoot.
4. As a newcomer, I want the first enemy to fire predictable blue **Straight-tier** shots down a clear lane, so "step aside to dodge" is self-evident.
5. As a newcomer, I want an orange **Aimed-tier** shot introduced right after, so I feel the difference: standing still where blue was safe now tags me.
6. As a player who got tagged standing still, I want a brief "keep moving — orange aims at you" hint to fire *only then*, so the colour rule is stated exactly when I failed to read it — and never if I dodged it.
7. As a newcomer, I want a survivable swarm that makes me want to use the bomb, with the on-screen **Bomb** ("PUSH TO JETT") button pulsing, so I discover the bomb by needing it.
8. As a hoarder of consumables, I want a bomb pickup dropped just before that swarm, so spending my first bomb feels free and I actually learn what it does.
9. As a returning player starting a New Game, I want none of the explicit hints to reappear (because I just play), so onboarding never feels like a forced replay.
10. As a player on a controller or keyboard, I want the hints phrased for *my* device (stick/key prompts, not "drag" or an on-screen button), so instructions are never wrong.
11. As a player who swaps device mid-intro, I want the prompts to re-render in the new scheme, so I never see a stale "tap" instruction on a controller.
12. As the developer, I want the FTUE to add *no* new difficulty system — just an authoring spec for the L1S1 intro — so there's no first-run curve to maintain.
13. As the developer, I want the FTUE to own *no* glyph logic — it consumes PRD-03's active scheme — so teaching prompts stay correct for free as controls evolve.
14. As the developer, I want a non-gamer to validate comprehension hands-off on a real phone, so I know the teaching actually lands on the target audience and the target platform.

## Implementation Decisions

- **The deliverable is a beat-sheet, not a subsystem.** FTUE is an authoring spec for the **Level-1
  Stage-1 stage intro** (built by [[PRD-14]] / #37), plus a small set of hint rules. The canonical beats:

  | Beat | ~Time | What spawns / happens | What it teaches | Hint (failure-triggered) |
  |------|-------|------------------------|-----------------|---------------------------|
  | 1 | 0–2s | empty sky, player free to fly | move (drag) + auto-fire | "DRAG TO MOVE" if no movement by ~2s |
  | 2 | 2–12s | one **Strafer**, blue Straight-tier down a telegraphed lane | blue = step aside | — (positive: killing it) |
  | 3 | 12–25s | one **Aimed-tier** shot (Diver or Emplacement) leading the player | orange = keep moving | "keep moving — orange aims at you" if hit while still |
  | 4 | 25–40s | bomb pickup, then a survivable swarm; **Bomb** button pulses | bomb = panic button | (heavy-damage nudge if swarm survived un-bombed) |
  | (later) | stage 1 mini-boss | a single heavy with a weak-point | weak-points | — |

- **Hints are self-suppressing and behavioural.** Each hint has a *need* trigger (no-move timeout,
  hit-while-stationary, swarm-survived-without-bomb) and shows briefly, then fades. No hint is
  scripted to a timestamp; a competent player trips none of them. **No persistent onboarding flag** —
  behaviour is the suppression signal ([[0013-invisible-onboarding-no-tutorial]]).
- **Hint strings are keyed by control scheme.** FTUE asks the HUD for PRD-03's published active scheme
  and selects the right string/glyph (drag vs stick vs touch-button). It performs **no device
  detection of its own** and re-renders if the scheme swaps mid-intro.
- **Bomb teaching is active and gifted.** The swarm in beat 4 is tuned survivable even un-bombed (the
  lesson must not be punished by death), and a bomb pickup precedes it so the first spend is free. The
  pulse targets the on-screen JETT button in touch mode, or shows the key/button glyph otherwise. The
  bomb icon on the button carries the meaning — hint text uses **"Bomb"** (vocabulary unchanged;
  "Jettison" is button flavour).
- **Colour teaching is contrast + failure-hint, blue/orange only.** Purple (Pattern-tier) is
  boss/Elite-gated and taught later in the City level — explicitly out of scope here.
- **No new difficulty machinery.** Easing = the Level-1 tier-0 onramp
  ([[0010-absolute-difficulty-curve-with-hangar-catchup]]) + the sparse beat spacing above, which also
  absorbs the reduced dodge space from the cockpit-bezel HUD (see issue #40). No first-run curve.

## Testing Decisions

- **Hint trigger/suppression is the testable logic.** A good test feeds the hint controller a stream
  of player-state events (moved? hit-while-stationary? swarm-survived-un-bombed?) + timestamps and
  asserts which hint (if any) fires — never inspects internal timers. Cases: no movement by the
  timeout → move-hint; movement before timeout → no hint; hit by aimed while stationary → colour-hint;
  hit by aimed while moving → no hint; idempotent repeats; a scheme swap re-keys the string.
- **Two-pass HITL validation** (own validation):
  - **Pass 1 — PC mouse-proxy (early, you can run it):** validates teaching *logic* — do hints fire on
    the right failures, does blue→orange→swarm read, does the JETT pulse land. Catches logic bugs
    cheaply. Godot mouse↔touch emulation is acceptable here.
  - **Pass 2 — real-phone non-gamer (gated on PRD-19 / #44):** validates touch *feel + comprehension*
    hands-off (no coaching). Watch: time-to-first-dodge, did they ever bomb, did they form "orange =
    move," did they bounce. Godot touch-emulation is **not** sufficient — thumb occlusion and
    drag-to-move precision only surface on a device ([[project-playtest-setup]]).

## Out of Scope

- **The Level-1 stage content itself** (spawn tables, the mini-boss, the Kamikaze-wing signature) →
  **PRD-14 / #37.** This PRD only specifies the *teaching constraints* on that intro.
- **Teaching purple / Pattern-tier** → the City level (Elites), a later content PRD.
- **HUD art, the cockpit bezel, the damage gauge, action-button layout** → **PRD-18 / #40** (notes
  parked there).
- **Touch build + on-device validation harness** → **PRD-19 / #44.** This PRD's Pass-2 sign-off rides
  on it.
- **Accessibility (colour-blind palette, shape-redundancy)** → deferred per
  [[0012-player-fire-is-a-visual-class-outside-the-threat-palette]]; likely a future-project concern.

## Further Notes

- This is **design-complete now, build-gated later.** Nothing here can be implemented until the loop
  it teaches exists (#27, #31, #28, #37). Treat the beat-sheet as the contract PRD-14 builds against.
- The single biggest risk is the **touch validation gap**: the system is for non-gamers on touch, but
  the developer playtests on PC. The two-pass plan exists specifically to stop a PC mouse-proxy from
  lulling us into signing off touch feel that hasn't been felt on glass. **Done is not done until
  Pass 2.**
- **Done =** the L1S1 intro teaches move → blue-dodge → orange-dodge → bomb in order; each hint fires
  only on its failure trigger and never for a competent player; hints are correctly phrased for the
  active control scheme; no onboarding state is persisted; hint-controller unit tests pass; Pass 1
  validates on PC; and Pass 2 (with PRD-19) confirms a non-gamer learns the four things hands-off on a
  real phone.
