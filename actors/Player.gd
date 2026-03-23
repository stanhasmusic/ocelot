extends CharacterBody2D

signal shoot_projectile

const SPEED: float = 400.0
const FIRE_RATE: float = 0.15
const JOYSTICK_RADIUS: float = 80.0
const JOYSTICK_DEAD_ZONE: float = 10.0

@export var bullet_scene: PackedScene
@export var max_hp: int = 4
@export var hit_shake_strength: float = 8.0
@export var shoot_sfx: AudioStream = load("res://assets/audio/Sound Effects/SFMG1.wav")
@export var bomb_sfx: AudioStream = load("res://assets/audio/Sound Effects/newexpl3.wav")
@export var death_sfx: AudioStream = load("res://assets/audio/Sound Effects/explcls1.wav")

var can_shoot: bool = true
var shoot_timer: float = 0.0

var current_hp: int
var weapon_level: int = 0
var is_invincible: bool = false
var bomb_count: int = 3

# Touch control state
var _touch_move_id: int = -1
var _touch_move_origin: Vector2 = Vector2.ZERO
var _touch_move_pos: Vector2 = Vector2.ZERO
var _touch_shoot_id: int = -1

func _ready() -> void:
	add_to_group("Player")
	current_hp = max_hp
	update_player_sprite()
	_setup_missing_inputs()
	GameManager.report_bomb_count(bomb_count)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var half_w: float = get_viewport_rect().size.x * 0.5
		if event.pressed:
			if event.position.x < half_w:
				# Left half — movement joystick
				if _touch_move_id == -1:
					_touch_move_id = event.index
					_touch_move_origin = event.position
					_touch_move_pos = event.position
			else:
				# Right half — shoot
				if _touch_shoot_id == -1:
					_touch_shoot_id = event.index
		else:
			if event.index == _touch_move_id:
				_touch_move_id = -1
			if event.index == _touch_shoot_id:
				_touch_shoot_id = -1
	elif event is InputEventScreenDrag:
		if event.index == _touch_move_id:
			_touch_move_pos = event.position

func _physics_process(delta: float) -> void:
	# Cooldown
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

	# Movement — keyboard/gamepad or touch joystick
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _touch_move_id != -1:
		var offset = _touch_move_pos - _touch_move_origin
		if offset.length() > JOYSTICK_DEAD_ZONE:
			direction = (offset / JOYSTICK_RADIUS).limit_length(1.0)
		else:
			direction = Vector2.ZERO
	velocity = direction * SPEED
	move_and_slide()

	# Clamp
	var viewport_rect = get_viewport_rect()
	position.x = clamp(position.x, 0, viewport_rect.size.x)
	position.y = clamp(position.y, 0, viewport_rect.size.y)

	# Shooting — keyboard/gamepad or right-half touch
	if Input.is_action_pressed("shoot") or _touch_shoot_id != -1:
		shoot()

	# Bomb — keyboard/gamepad (touch handled by HUD button)
	if Input.is_action_just_pressed("bomb"):
		drop_bomb()

func shoot() -> void:
	if not can_shoot: return

	if bullet_scene:
		# Lvl 0: Center only
		# Lvl 1: Left + Right
		# Lvl 2: Left + Center + Right
		# Lvl 3: Left + Center + Right + 2 diagonal
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
			_: # 3 and above
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
		can_shoot = false
		shoot_timer = FIRE_RATE
	else:
		print("Error: Bullet Scene not assigned in Player.gd")

func drop_bomb() -> void:
	if bomb_count > 0:
		bomb_count -= 1
		GameManager.report_bomb_count(bomb_count)
		detonate_bomb()

func detonate_bomb() -> void:
	print("Bomb Detonated!")
	SoundManager.play_sfx(bomb_sfx)
	# Visual Flash
	if has_node("BombFlashLayer/ColorRect"):
		var rect = $BombFlashLayer/ColorRect
		rect.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(rect, "modulate:a", 0.0, 0.5)
	
	var tree = get_tree()
	if not tree:
		return
	var screen = get_viewport_rect()
	# Kill on-screen Enemies
	for enemy in tree.get_nodes_in_group("Enemies"):
		if screen.has_point(enemy.global_position):
			enemy.take_damage(100)
	# Clear on-screen Projectiles
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
	# Current Logic: d0 = Full Health, d(max-current) = damage
	var damage_index = max_hp - current_hp
	# Ensure clamped
	damage_index = clampi(damage_index, 0, 4)
	
	var path = "res://assets/sprites/p38_sprites/P38_lvl_" + str(weapon_level) + "_d" + str(damage_index) + ".png"
	
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
	# Visual feedback
	modulate.a = 0.5
	# Start Timer (Assumed node name InvincibilityTimer)
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
	start_invincibility()

func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	modulate.a = 1.0

# --- Self Healing Inputs ---
func _setup_missing_inputs() -> void:
	if InputMap.has_action("move_left"): return

	print("Input Actions missing. setting up defaults...")
	
	var add_input = func(action: String, key_primary, key_alt, joy_button):
		if not InputMap.has_action(action): InputMap.add_action(action)
		if key_primary:
			var k1 = InputEventKey.new()
			k1.keycode = key_primary
			InputMap.action_add_event(action, k1)
		if key_alt:
			var k2 = InputEventKey.new()
			k2.keycode = key_alt
			InputMap.action_add_event(action, k2)
		if joy_button != null:
			var j = InputEventJoypadButton.new()
			j.button_index = joy_button
			InputMap.action_add_event(action, j)

	add_input.call("move_left", KEY_A, KEY_LEFT, JOY_BUTTON_DPAD_LEFT)
	add_input.call("move_right", KEY_D, KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT)
	add_input.call("move_up", KEY_W, KEY_UP, JOY_BUTTON_DPAD_UP)
	add_input.call("move_down", KEY_S, KEY_DOWN, JOY_BUTTON_DPAD_DOWN)
	
	var add_axis = func(action, axis, val):
		var a = InputEventJoypadMotion.new()
		a.axis = axis
		a.axis_value = val
		InputMap.action_add_event(action, a)

	add_axis.call("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_axis.call("move_right", JOY_AXIS_LEFT_X, 1.0)
	add_axis.call("move_up", JOY_AXIS_LEFT_Y, -1.0)
	add_axis.call("move_down", JOY_AXIS_LEFT_Y, 1.0)
	
	if not InputMap.has_action("shoot"): InputMap.add_action("shoot")
	var space = InputEventKey.new()
	space.keycode = KEY_SPACE
	InputMap.action_add_event("shoot", space)
	var r_trig = InputEventJoypadMotion.new()
	r_trig.axis = JOY_AXIS_TRIGGER_RIGHT
	r_trig.axis_value = 1.0
	InputMap.action_add_event("shoot", r_trig)
	
	add_input.call("bomb", KEY_ALT, null, JOY_BUTTON_A)
