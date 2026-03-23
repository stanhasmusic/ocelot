extends "res://actors/Boss.gd"

# Level 3 boss: tri-phase escalation.
# Phase 1 (>66% HP): single shot.
# Phase 2 (33-66% HP): rotating 3-arm spiral.
# Phase 3 (<33% HP): targeted shots at player + homing rockets every 3s, descent stops.

@export var rocket_scene: PackedScene

const ROCKET_INTERVAL: float = 3.0
var _rocket_timer: float = 0.0

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if not is_dead and _phase == 2 and current_hp <= max_hp / 3:
		_phase = 3
		if has_node("ShootTimer"):
			$ShootTimer.wait_time = 0.4

func _physics_process(delta: float) -> void:
	time_alive += delta
	if _phase < 3:
		position.y += vertical_speed * delta
	position.x += sin(time_alive * speed) * magnitude
	if _phase == 3:
		_rocket_timer += delta
		if _rocket_timer >= ROCKET_INTERVAL:
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
			# 3-arm rotating spiral — base angle rotates with time
			var base_angle = fmod(time_alive * 2.0, TAU)
			for i in range(3):
				var b = fan_bullet_scene.instantiate()
				get_parent().add_child(b)
				b.global_position = $Muzzle.global_position
				b.rotation = base_angle + (TAU / 3.0) * i
		3:
			# Targeted shot aimed at player
			var player = get_tree().get_first_node_in_group("Player")
			var aim = Vector2.DOWN
			if player:
				aim = (player.global_position - $Muzzle.global_position).normalized()
			var b = fan_bullet_scene.instantiate()
			get_parent().add_child(b)
			b.global_position = $Muzzle.global_position
			b.rotation = aim.angle()
