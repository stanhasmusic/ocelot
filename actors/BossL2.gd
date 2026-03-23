extends "res://actors/Boss.gd"

# Level 2 boss: more erratic movement, escalating spread fire.
# Phase 1: 3-bullet spread. Phase 2 (<=50% HP): 5-bullet wider spread.

func _physics_process(delta: float) -> void:
	time_alive += delta
	position.y += vertical_speed * delta
	# Primary horizontal sine + secondary vertical wobble for figure-8 feel
	position.x += sin(time_alive * speed) * magnitude
	position.y += sin(time_alive * speed * 0.7) * magnitude * 0.4

func _on_shoot_timer_timeout() -> void:
	if not fan_bullet_scene:
		return
	var count = 3 if _phase == 1 else 5
	for i in range(count):
		var offset = (i - float(count - 1) / 2.0) * 0.25
		var b = fan_bullet_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = $Muzzle.global_position
		b.rotation = PI / 2.0 + offset
