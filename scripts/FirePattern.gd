class_name FirePattern
extends RefCounted

# Shared fire-geometry for every enemy archetype (PRD-05).
#
# Today each spread-firing enemy hard-codes a literal angle list
# (`[-0.5, -0.25, 0, 0.25, 0.5]`) and each aimed enemy re-derives
# `direction_to(player)` inline. That means a "3-shot 30 degree fan" is
# expressed three slightly different ways and nothing is testable without
# spawning a level. These helpers compute fire one correct way everywhere.
#
# Pure: no node, Input, or Engine dependencies; safe to unit-test.


# Unit vector pointing from a source toward a target. Degenerate (same point)
# falls back to straight-down so callers never divide by zero.
static func aimed_direction(from: Vector2, to: Vector2) -> Vector2:
	var delta: Vector2 = to - from
	if delta == Vector2.ZERO:
		return Vector2.DOWN
	return delta.normalized()


# `count` unit vectors fanned symmetrically about `base_dir`, spanning `arc`
# radians end to end. `count <= 1` returns the base direction unchanged; the
# fan is centred on the base so even and odd counts both stay balanced.
static func spread_directions(base_dir: Vector2, count: int, arc: float) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	if count <= 0:
		return dirs
	var base: Vector2 = base_dir.normalized() if base_dir != Vector2.ZERO else Vector2.DOWN
	if count == 1:
		dirs.append(base)
		return dirs
	var step: float = arc / float(count - 1)
	var start: float = -arc / 2.0
	for i in count:
		dirs.append(base.rotated(start + step * i))
	return dirs
