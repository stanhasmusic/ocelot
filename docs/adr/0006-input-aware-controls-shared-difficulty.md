# Controls auto-swap by input device, over a single shared difficulty curve

Movement is **drag-to-move with always-on auto-fire**. The game detects the most recently used input device (touch / mouse / gamepad / keyboard) and hot-swaps the active control scheme and on-screen UI accordingly. Two movement models exist underneath:

- **Positional 1:1** for touch and mouse — the plane chases a target point (finger/cursor) at a high speed cap. This is the canonical model and the one the difficulty is tuned against.
- **Velocity** for gamepad stick and keyboard — directional acceleration toward a snappy cap, tuned to *approximate* the positional feel.

There is **one shared difficulty curve** across all inputs. The positional-vs-velocity gap is absorbed by small per-input **assist knobs** (movement snap, pickup-magnet radius, possibly a slightly more forgiving effective hitbox on gamepad) — *not* by separate per-platform content curves.

We picked this over (a) a single movement model forced on every input (velocity-on-touch is imprecise and unfamiliar; positional-on-stick is impossible), and (b) full per-platform difficulty curves (~2× balancing work for every level, and — decisively — the user only playtests on PC controller + mouse/keyboard, so a separate touch curve would be hand-authored without ever being felt; see [[project-playtest-setup]]). The shared curve is tuned on **mouse as the touch proxy** and verified on gamepad, keeping the mobile-first target validatable on the available setup. Auto-swap detection itself is cheap and standard in Godot (branch on `InputEvent` subtype).

Consequence: the player controller needs two movement code paths behind a scheme enum, a device-detection layer that also drives prompt glyphs and touch-button visibility, and a small set of per-input assist parameters. Difficulty/spawn tuning ([[0002-hybrid-stage-difficulty]]) stays single-track. If a future level provably can't be fair on both inputs under one curve, forking a touch curve remains possible — but is deferred until a phone is in the playtest loop to justify it.
