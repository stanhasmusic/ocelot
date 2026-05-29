extends "res://actors/Enemy.gd"

func _on_shoot_timer_timeout() -> void:
	if not projectile_scene:
		return
	# 3-bullet spread (0.6 rad end to end) fanned about straight-down.
	for dir in FirePattern.spread_directions(Vector2.DOWN, 3, 0.6):
		var b = projectile_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(0, 20)
		b.rotation = dir.angle()
