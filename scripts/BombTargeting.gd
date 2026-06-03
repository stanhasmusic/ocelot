class_name BombTargeting
extends RefCounted

# Pure "what does the bomb hit" decision, lifted out of `Player.detonate_bomb`
# (PRD-06). The bomb clears on-screen enemy fire and damages on-screen enemies;
# the *only* rule worth testing is "which entities count as on-screen", and
# that rule used to be an inline `screen.has_point(...)` loop inside the node,
# untestable without spawning a level. This isolates it.
#
# Parity note: uses `Rect2.has_point`, exactly like the original loop, so the
# bomb's selection is unchanged. `has_point` includes the top/left edges and
# excludes the bottom/right edges -- a point on the screen's top-left corner is
# hit, one on the bottom-right corner is not.
#
# Pure: no node, Input, or Engine dependencies; safe to unit-test.


# Indices into `positions` that fall inside `screen_rect`. Empty in -> empty out.
static func affected_by_bomb(positions: Array, screen_rect: Rect2) -> Array[int]:
	var hit: Array[int] = []
	for i in positions.size():
		if screen_rect.has_point(positions[i]):
			hit.append(i)
	return hit


# Indices into `positions` within `radius` of `center` (inclusive of the rim).
# The Flare's nearby-fire clear (PRD-09) uses this radius variant while the bomb
# keeps its whole-screen `affected_by_bomb`. Pure, like its sibling above:
# distances in, indices out. A non-positive radius hits nothing; empty in ->
# empty out.
static func within_radius(positions: Array, center: Vector2, radius: float) -> Array[int]:
	var hit: Array[int] = []
	if radius <= 0.0:
		return hit
	var radius_sq: float = radius * radius
	for i in positions.size():
		if (positions[i] as Vector2).distance_squared_to(center) <= radius_sq:
			hit.append(i)
	return hit
