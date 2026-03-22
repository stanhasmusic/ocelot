extends Area2D

const SPEED: float = 600.0
var direction: Vector2 = Vector2.UP

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
