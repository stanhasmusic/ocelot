extends Area2D

const SPEED: float = 400.0

func _physics_process(delta: float) -> void:
	# Move forward based on rotation (assuming 0 rotation is RIGHT, but we might need to adjust based on sprite)
	# If we use standard Godot 0 degrees = Right.
	# EnemyBullet moves Y+.
	# Let's assume we rotate this bullet to point at target.
	var direction = Vector2.RIGHT.rotated(rotation)
	position += direction * SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
