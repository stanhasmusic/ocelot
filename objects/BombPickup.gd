extends Area2D

@export var speed: float = 100.0

func _physics_process(delta: float) -> void:
	var players: Array = get_tree().get_nodes_in_group("Player")
	if players.size() > 0 and players[0].has_method("current_magnet_radius"):
		var player: Node2D = players[0]
		global_position += PickupMagnet.step(
			global_position, player.global_position, speed, player.current_magnet_radius(), delta
		)
	else:
		global_position.y += speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("add_bomb"):
		body.add_bomb(1)
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
