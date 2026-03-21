extends Area2D

const SPEED: float = 300.0

func _physics_process(delta: float) -> void:
	position.y += SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
