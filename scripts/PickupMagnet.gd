class_name PickupMagnet
extends RefCounted

# Pure pickup steering (PRD-03 magnet assist). Within `radius` of the player a
# pickup's straight fall is blended with a pull toward the player so imprecise
# inputs (stick / touch) are not punished for loose positioning. `radius <= 0`
# disables the magnet entirely -> today's straight fall, the mouse-proxy default.
#
# Returns the position *delta* to add this frame; node side stays a thin
# `position += PickupMagnet.step(...)`.

static func step(
	current: Vector2,
	player: Vector2,
	fall_speed: float,
	radius: float,
	delta: float,
	pull_factor: float = 6.0
) -> Vector2:
	var fall: Vector2 = Vector2(0.0, max(fall_speed, 0.0) * max(delta, 0.0))
	if radius <= 0.0:
		return fall
	var to_player: Vector2 = player - current
	var dist: float = to_player.length()
	if dist > radius or dist <= 0.001:
		return fall
	# Strength ramps 0 at the edge of the radius to 1 at the player.
	var strength: float = 1.0 - (dist / radius)
	var attract: Vector2 = (to_player.normalized()
			* max(fall_speed, 0.0) * pull_factor * strength * max(delta, 0.0))
	return fall + attract
