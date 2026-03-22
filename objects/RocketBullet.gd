extends Area2D

const SPEED: float = 280.0
const TURN_SPEED: float = 1.5  # radians/sec — slow enough to dodge

var direction: Vector2 = Vector2.DOWN

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var target_dir = (player.global_position - global_position).normalized()
		direction = direction.lerp(target_dir, TURN_SPEED * delta).normalized()
	global_position += direction * SPEED * delta
	rotation = direction.angle() - PI / 2.0

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
