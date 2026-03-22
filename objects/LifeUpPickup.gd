extends Area2D

@export var speed: float = 100.0

func _physics_process(delta: float) -> void:
	position.y += speed * delta
	if position.y > get_viewport_rect().size.y + 50:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		GameManager.add_life()
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
