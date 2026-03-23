extends "res://actors/Enemy.gd"

func _on_shoot_timer_timeout() -> void:
	if not projectile_scene:
		return
	for spread in [-0.3, 0.0, 0.3]:  # 3-bullet spread
		var b = projectile_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(0, 20)
		b.rotation = PI / 2.0 + spread
