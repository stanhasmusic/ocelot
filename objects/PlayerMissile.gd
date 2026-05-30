extends Area2D

# Player-fired missile granted by the temporary missile topping (PRD-06).
# Homes on the nearest enemy and is explosive-tagged -- the in-run answer to
# heavy targets. The resistance / explosive-damage *math* is PRD-10; here it is
# a homing shot that deals flat `damage` and carries `is_explosive` so PRD-10
# can read the tag later.
#
# It sits off the PlayerProjectile layer and detects enemies itself (mask =
# Enemy) so the generic "any player projectile = 1 damage" path on Enemy does
# not pre-empt the missile's own, heavier hit.

const SPEED: float = 460.0
const TURN_SPEED: float = 3.0  # radians/sec

@export var damage: int = 3
@export var is_explosive: bool = true

var direction: Vector2 = Vector2.UP


func _physics_process(delta: float) -> void:
	var enemy: Node2D = _nearest_enemy()
	if enemy:
		var target_dir: Vector2 = (enemy.global_position - global_position).normalized()
		direction = direction.lerp(target_dir, TURN_SPEED * delta).normalized()
	global_position += direction * SPEED * delta
	rotation = direction.angle() + PI / 2.0
	if global_position.y < -50.0:
		queue_free()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
