class_name TemporaryEffectStack
extends RefCounted

# Pure tracker for the in-run *temporary toppings* (PRD-06): the fire-pattern
# swap, the wingman, the missile. Each is a named effect that is live for a
# duration and then expires, returning the player to the permanent Hangar
# floor (never below it). The Player holds one of these, `tick`s it each frame,
# and queries `is_active` to decide its current fire / wingman state.
#
# Stacking rule: re-grabbing an effect that is already live *refreshes* its
# timer to the longer of (what remains) and (the new duration). So a pickup
# never makes you weaker (the timer can't shrink) and effects never double-
# stack into an ever-growing pile -- predictable and deterministic.
#
# Pure: no node, Input, or Engine dependencies; safe to unit-test.

# effect id (String) -> remaining seconds (float, always > 0 while stored)
var _remaining: Dictionary = {}


# Add or refresh a temporary effect. A non-positive duration is ignored so a
# bad pickup value can never register a zero-length (or negative) effect.
func add(effect: String, duration: float) -> void:
	if duration <= 0.0:
		return
	_remaining[effect] = maxf(_remaining.get(effect, 0.0), duration)


# Advance every live effect by `delta`, expiring any that hit zero. Negative
# deltas are clamped to zero so a bad frame time can't extend an effect.
func tick(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if step == 0.0:
		return
	for effect in _remaining.keys():
		var left: float = _remaining[effect] - step
		if left <= 0.0:
			_remaining.erase(effect)
		else:
			_remaining[effect] = left


func is_active(effect: String) -> bool:
	return _remaining.has(effect)


# Seconds left on an effect, or 0.0 if it is not live.
func time_left(effect: String) -> float:
	return _remaining.get(effect, 0.0)


# A live effect is "expiring" when its remaining time has dropped into the
# warning window -- the seam a HUD/blink can read to warn the player it is
# about to wear off (user story 5).
func is_expiring(effect: String, warn_window: float) -> bool:
	if not _remaining.has(effect):
		return false
	return _remaining[effect] <= warn_window


# The ids of every currently live effect.
func active() -> Array:
	return _remaining.keys()


func clear() -> void:
	_remaining.clear()
