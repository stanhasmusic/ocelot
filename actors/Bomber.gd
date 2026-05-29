extends "res://actors/Enemy.gd"

func _on_shoot_timer_timeout() -> void:
	if not projectile_scene:
		return
	# 5-bullet wide spread (1.0 rad end to end) fanned about straight-down.
	for dir in FirePattern.spread_directions(Vector2.DOWN, 5, 1.0):
		var b = projectile_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(0, 30)
		b.rotation = dir.angle()
