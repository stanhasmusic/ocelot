extends CharacterBody2D

signal shoot_projectile
signal on_bomb_count_changed(new_count: int)

const SPEED: float = 400.0
const FIRE_RATE: float = 0.15

@export var bullet_scene: PackedScene
@export var max_hp: int = 4
@export var shoot_sfx: AudioStream = load("res://assets/audio/Sound Effects/SFMG1.wav")
@export var bomb_sfx: AudioStream = load("res://assets/audio/Sound Effects/newexpl3.wav")
@export var death_sfx: AudioStream = load("res://assets/audio/Sound Effects/explcls1.wav")

var can_shoot: bool = true
var shoot_timer: float = 0.0

var current_hp: int
var weapon_level: int = 0
var is_invincible: bool = false
var bomb_count: int = 3

func _ready() -> void:
	add_to_group("Player")
	current_hp = max_hp
	update_player_sprite()
	_setup_missing_inputs()
	on_bomb_count_changed.emit(bomb_count)

func _physics_process(delta: float) -> void:
	# Cooldown
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

	# Movement
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()
	
	# Clamp
	var viewport_rect = get_viewport_rect()
	position.x = clamp(position.x, 0, viewport_rect.size.x)
	position.y = clamp(position.y, 0, viewport_rect.size.y)
	
	# Shooting
	if Input.is_action_pressed("shoot"):
		shoot()
		
	# Bomb
	if Input.is_action_just_pressed("bomb"):
		drop_bomb()

func shoot() -> void:
	if not can_shoot: return
	
	if bullet_scene:
		# Lvl 0: Center, Lvl 1: Left/Right, Lvl 2: All 3
		var spawn_positions = []
		
		match weapon_level:
			0:
				spawn_positions.append($MuzzleCenter.global_position)
			1:
				spawn_positions.append($MuzzleLeft.global_position)
				spawn_positions.append($MuzzleRight.global_position)
			_: # 2 and above
				spawn_positions.append($MuzzleLeft.global_position)
				spawn_positions.append($MuzzleCenter.global_position)
				spawn_positions.append($MuzzleRight.global_position)
		
		for pos in spawn_positions:
			var b = bullet_scene.instantiate()
			get_tree().root.add_child(b)
			b.global_position = pos
		
		shoot_projectile.emit()
		SoundManager.play_sfx(shoot_sfx)
		can_shoot = false
		shoot_timer = FIRE_RATE
	else:
		print("Error: Bullet Scene not assigned in Player.gd")

func drop_bomb() -> void:
	if bomb_count > 0:
		bomb_count -= 1
		on_bomb_count_changed.emit(bomb_count)
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
	
	# Kill Enemies
	get_tree().call_group("Enemies", "take_damage", 100)
	# Clear Projectiles
	get_tree().call_group("EnemyProjectiles", "queue_free")

func add_bomb(amount: int) -> void:
	bomb_count += amount
	on_bomb_count_changed.emit(bomb_count)

func power_up_weapon() -> void:
	if weapon_level < 2:
		weapon_level += 1
		update_player_sprite()

# --- Health & Visuals ---

func update_player_sprite() -> void:
	# Current Logic: d0 = Full Health, d(max-current) = damage
	var damage_index = max_hp - current_hp
	# Ensure clamped
	damage_index = clampi(damage_index, 0, 3) # Assuming sprites go up to d3
	
	var path = "res://assets/sprites/p38_sprites/P38_lvl_" + str(weapon_level) + "_d" + str(damage_index) + ".png"
	
	if FileAccess.file_exists(path):
		$Sprite2D.texture = load(path)
	else:
		print("Warning: Sprite not found at ", path)

func take_damage(amount: int) -> void:
	if is_invincible or current_hp <= 0:
		return
		
	current_hp -= amount
	update_player_sprite()
	
	if current_hp <= 0:
		die()
	else:
		start_invincibility()

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
