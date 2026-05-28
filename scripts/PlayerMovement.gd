class_name PlayerMovement
extends RefCounted

# Pure positional movement. No node/input/Engine dependencies; safe to unit-test.
#
# Moves `current` toward `target`, smoothed by `follow_lerp` (0..1, fraction of the
# remaining distance to close per call), limited to at most `max_speed * delta`
# per tick, and clamped to `bounds`. Returns `current` unchanged (other than the
# clamp) when already at target or when delta is zero.

static func next_position(
	current: Vector2,
	target: Vector2,
	max_speed: float,
	follow_lerp: float,
	delta: float,
	bounds: Rect2
) -> Vector2:
	var smoothing: float = clampf(follow_lerp, 0.0, 1.0)
	var desired: Vector2 = current.lerp(target, smoothing)
	var step: Vector2 = desired - current
	var max_step: float = max(max_speed, 0.0) * max(delta, 0.0)
	if step.length() > max_step:
		step = step.normalized() * max_step
	var result: Vector2 = current + step
	result.x = clampf(result.x, bounds.position.x, bounds.position.x + bounds.size.x)
	result.y = clampf(result.y, bounds.position.y, bounds.position.y + bounds.size.y)
	return result
