extends "res://actors/Boss.gd"

# Level 3 boss: tri-phase escalation.
# Phase 1 (>66% HP): single shot straight down.
# Phase 2 (33-66% HP): targeted shots at player + rockets every 3s.
# Phase 3 (<33% HP): targeted 3-shot spread + rockets every 1.5s, descent stops, faster fire.

@export var rocket_scene: PackedScene

var _rocket_timer: float = 0.0

func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_hp -= min(amount, 10)
	GameManager.report_boss_health(current_hp, max_hp)
	if _phase == 1 and current_hp <= max_hp * 2 / 3:
		_phase = 2
	elif _phase == 2 and current_hp <= max_hp / 3:
		_phase = 3
		if has_node("ShootTimer"):
			$ShootTimer.wait_time = 0.3
	if current_hp <= 0:
		is_dead = true
		die()

func _physics_process(delta: float) -> void:
	time_alive += delta
	if _phase < 3:
		position.y += vertical_speed * delta
	position.x += sin(time_alive * speed) * magnitude
	if _phase >= 2:
		_rocket_timer += delta
		var interval = 1.5 if _phase == 3 else 3.0
		if _rocket_timer >= interval:
			_rocket_timer = 0.0
			_fire_rocket()

func _fire_rocket() -> void:
	if not rocket_scene:
		return
	var r = rocket_scene.instantiate()
	get_parent().add_child(r)
	r.global_position = $Muzzle.global_position

func _on_shoot_timer_timeout() -> void:
	if not fan_bullet_scene:
		return
	match _phase:
		1:
			var b = fan_bullet_scene.instantiate()
			get_parent().add_child(b)
			b.global_position = $Muzzle.global_position
			b.rotation = PI / 2.0
		2:
			# Targeted single shot at player
			var player = get_tree().get_first_node_in_group("Player")
			var aim = Vector2.DOWN
			if player:
				aim = (player.global_position - $Muzzle.global_position).normalized()
			var b = fan_bullet_scene.instantiate()
			get_parent().add_child(b)
			b.global_position = $Muzzle.global_position
			b.rotation = aim.angle()
		3:
			# Targeted 3-shot spread centered on player
			var player = get_tree().get_first_node_in_group("Player")
			var aim = Vector2.DOWN
			if player:
				aim = (player.global_position - $Muzzle.global_position).normalized()
			var base_angle = aim.angle()
			for spread in [-0.25, 0.0, 0.25]:
				var b = fan_bullet_scene.instantiate()
				get_parent().add_child(b)
				b.global_position = $Muzzle.global_position
				b.rotation = base_angle + spread
