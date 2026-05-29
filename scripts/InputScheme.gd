class_name InputScheme
extends RefCounted

# Pure input-device -> control-scheme resolver (PRD-03). No node, Input singleton,
# or Engine dependency: it is fed event *kinds* + magnitudes + timestamps so the
# swap / debounce / hysteresis policy is deterministically unit-testable.
#
# Two schemes map onto the PRD-01 movement branches:
#   POSITIONAL - mouse / touch -> chase a target point (drag-to-move)
#   VELOCITY   - gamepad stick / keyboard -> directional velocity
#
# Noise rejection:
#   - a JOYPAD event whose magnitude is below `stick_deadzone` never causes a
#     swap (resting-stick drift is not a deliberate input), and
#   - once a swap happens, a conflicting swap inside `debounce_seconds` is
#     ignored so a single stray event cannot thrash the scheme under the player.

enum Scheme { POSITIONAL, VELOCITY }
enum EventKind { MOUSE, TOUCH, JOYPAD, KEY }

const DEFAULT_SCHEME: int = Scheme.POSITIONAL

var stick_deadzone: float
var debounce_seconds: float
var _last_swap_time: float = -INF

func _init(deadzone: float = 0.2, debounce: float = 0.1) -> void:
	stick_deadzone = deadzone
	debounce_seconds = debounce

# The scheme a given device kind wants, ignoring debounce/deadzone.
static func scheme_for_kind(kind: int) -> int:
	match kind:
		EventKind.MOUSE, EventKind.TOUCH:
			return Scheme.POSITIONAL
		_:
			return Scheme.VELOCITY

# Given the currently-active scheme and an incoming event, return the scheme that
# should be active after it. Pure: the only mutated state is the debounce clock,
# and only when an actual swap is granted.
func resolve(active_scheme: int, event_kind: int, magnitude: float, now: float) -> int:
	# Sub-deadzone stick wobble is not a deliberate input -> never swaps.
	if event_kind == EventKind.JOYPAD and absf(magnitude) < stick_deadzone:
		return active_scheme
	var desired: int = scheme_for_kind(event_kind)
	if desired == active_scheme:
		return active_scheme
	# A conflicting swap too soon after the last one is rejected (anti-thrash).
	if now - _last_swap_time < debounce_seconds:
		return active_scheme
	_last_swap_time = now
	return desired
