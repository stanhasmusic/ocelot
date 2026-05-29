extends CharacterBody2D

signal shoot_projectile

enum InputSource { POSITIONAL, VELOCITY }

const STICK_DEADZONE: float = 0.2

@export var tunables: PlayerTunables = preload("res://resources/PlayerTunables.tres")
@export var bullet_scene: PackedScene
@export var max_hp: int = 4
@export var hit_shake_strength: float = 8.0
@export var shoot_sfx: AudioStream = load("res://assets/audio/Sound Effects/SFMG1.wav")
@export var bomb_sfx: AudioStream = load("res://assets/audio/Sound Effects/newexpl3.wav")
@export var death_sfx: AudioStream = load("res://assets/audio/Sound Effects/explcls1.wav")

var current_hp: int
var weapon_level: int = 0
var is_invincible: bool = false
var bomb_count: int = 3

var _input_source: int = InputSource.POSITIONAL
var _positional_target: Vector2 = Vector2.ZERO
var _touch_id: int = -1
var _fire_clock: AutoFireClock

func _ready() -> void:
	add_to_group("Player")
	current_hp = max_hp
	update_player_sprite()
	_positional_target = global_position
	_fire_clock = AutoFireClock.new(tunables.fire_interval)
	GameManager.report_bomb_count(bomb_count)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_input_source = InputSource.POSITIONAL
		_positional_target = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			_input_source = InputSource.POSITIONAL
			if _touch_id == -1:
				_touch_id = event.index
				_positional_target = event.position + tunables.finger_offset
		else:
			if event.index == _touch_id:
				_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == _touch_id:
			_input_source = InputSource.POSITIONAL
			_positional_target = event.position + tunables.finger_offset
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > STICK_DEADZONE:
			_input_source = InputSource.VELOCITY
	elif event is InputEventJoypadButton and event.pressed:
		_input_source = InputSource.VELOCITY
	elif event is InputEventKey and event.pressed:
		if (event.is_action("move_left") or event.is_action("move_right")
				or event.is_action("move_up") or event.is_action("move_down")):
			_input_source = InputSource.VELOCITY

	if event.is_action_pressed("bomb"):
		drop_bomb()

func _physics_process(delta: float) -> void:
	var vp_rect: Rect2 = get_viewport_rect()

	if _input_source == InputSource.VELOCITY:
		var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = direction * tunables.max_speed
		move_and_slide()
		position.x = clampf(position.x, vp_rect.position.x, vp_rect.position.x + vp_rect.size.x)
		position.y = clampf(position.y, vp_rect.position.y, vp_rect.position.y + vp_rect.size.y)
	else:
		velocity = Vector2.ZERO
		global_position = PlayerMovement.next_position(
			global_position,
			_positional_target,
			tunables.max_speed,
			tunables.follow_lerp,
			delta,
			vp_rect
		)

	var volleys: int = _fire_clock.tick(delta)
	for i in volleys:
		_fire()

func _fire() -> void:
	if not bullet_scene:
		return
	var bullets: Array = []
	match weapon_level:
		0:
			bullets.append({"pos": $MuzzleCenter.global_position, "dir": Vector2.UP})
		1:
			bullets.append({"pos": $MuzzleLeft.global_position, "dir": Vector2.UP})
			bullets.append({"pos": $MuzzleRight.global_position, "dir": Vector2.UP})
		2:
			bullets.append({"pos": $MuzzleLeft.global_position, "dir": Vector2.UP})
			bullets.append({"pos": $MuzzleCenter.global_position, "dir": Vector2.UP})
			bullets.append({"pos": $MuzzleRight.global_position, "dir": Vector2.UP})
		_:
			bullets.append({"pos": $MuzzleLeft.global_position, "dir": Vector2.UP})
			bullets.append({"pos": $MuzzleCenter.global_position, "dir": Vector2.UP})
			bullets.append({"pos": $MuzzleRight.global_position, "dir": Vector2.UP})
			bullets.append({"pos": $MuzzleDiagLeft.global_position, "dir": Vector2(-0.3, -1.0).normalized()})
			bullets.append({"pos": $MuzzleDiagRight.global_position, "dir": Vector2(0.3, -1.0).normalized()})
	for entry in bullets:
		var b = bullet_scene.instantiate()
		get_tree().root.add_child(b)
		b.global_position = entry["pos"]
		b.direction = entry["dir"]
	shoot_projectile.emit()
	SoundManager.play_sfx(shoot_sfx)

func drop_bomb() -> void:
	if bomb_count > 0:
		bomb_count -= 1
		GameManager.report_bomb_count(bomb_count)
		detonate_bomb()

func detonate_bomb() -> void:
	print("Bomb Detonated!")
	SoundManager.play_sfx(bomb_sfx)
	if has_node("BombFlashLayer/ColorRect"):
		var rect = $BombFlashLayer/ColorRect
		rect.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(rect, "modulate:a", 0.0, 0.5)

	var tree = get_tree()
	if not tree:
		return
	var screen = get_viewport_rect()
	for enemy in tree.get_nodes_in_group("Enemies"):
		if screen.has_point(enemy.global_position):
			enemy.take_damage(100)
	for bullet in tree.get_nodes_in_group("EnemyProjectiles"):
		if screen.has_point(bullet.global_position):
			bullet.queue_free()

func add_bomb(amount: int) -> void:
	bomb_count += amount
	GameManager.report_bomb_count(bomb_count)

func power_up_weapon() -> void:
	if weapon_level < 2:
		weapon_level += 1
		update_player_sprite()

func power_up_to_max() -> void:
	weapon_level = 3
	update_player_sprite()

func repair_health(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
	update_player_sprite()

# --- Health & Visuals ---

func update_player_sprite() -> void:
	var damage_index = max_hp - current_hp
	damage_index = clampi(damage_index, 0, 4)

	var path = ("res://assets/sprites/p38_sprites/P38_lvl_"
			+ str(weapon_level) + "_d" + str(damage_index) + ".png")

	if FileAccess.file_exists(path):
		$Sprite2D.texture = load(path)
	else:
		print("Warning: Sprite not found at ", path)

func take_damage(amount: int) -> void:
	if is_invincible or current_hp <= 0:
		return

	GameManager.reset_combo()
	current_hp -= amount
	update_player_sprite()
	_play_hit_feedback()

	if current_hp <= 0:
		die()
	else:
		start_invincibility()

func _play_hit_feedback() -> void:
	if has_node("BombFlashLayer/DamageFlash"):
		var rect = $BombFlashLayer/DamageFlash
		rect.modulate.a = 0.4
		var tween = create_tween()
		tween.tween_property(rect, "modulate:a", 0.0, 0.3)

	var cam = get_tree().current_scene.get_node_or_null("Camera2D")
	if cam:
		var s: float = hit_shake_strength
		var tween = create_tween()
		tween.tween_property(cam, "offset", Vector2(s, s * 0.5), 0.05)
		tween.tween_property(cam, "offset", Vector2(-s * 0.7, -s * 0.4), 0.05)
		tween.tween_property(cam, "offset", Vector2.ZERO, 0.08)

func start_invincibility() -> void:
	is_invincible = true
	modulate.a = 0.5
	if has_node("InvincibilityTimer"):
		$InvincibilityTimer.start()

func die() -> void:
	SoundManager.play_sfx(death_sfx)
	GameManager.lives -= 1
	GameManager.on_lives_changed.emit(GameManager.lives)
	if GameManager.lives <= 0:
		GameManager.game_over()
		queue_free()
	else:
		_respawn()

func _respawn() -> void:
	current_hp = max_hp
	weapon_level = 0
	update_player_sprite()
	var vp = get_viewport_rect()
	position = Vector2(vp.size.x / 2.0, vp.size.y * 0.85)
	_positional_target = position
	start_invincibility()

func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	modulate.a = 1.0
