extends CharacterBody2D

signal shoot_projectile

@export var tunables: PlayerTunables = preload("res://resources/PlayerTunables.tres")
@export var assist_tunables: InputAssistTunables = preload(
	"res://resources/InputAssistTunables.tres"
)
@export var bullet_scene: PackedScene
@export var missile_scene: PackedScene = preload("res://objects/PlayerMissile.tscn")
@export var wingman_scene: PackedScene = preload("res://actors/Wingman.tscn")
@export var fire_swap_count: int = 5
@export var fire_swap_arc_deg: float = 60.0
@export var max_hp: int = 4
@export var hit_shake_strength: float = 8.0
@export var shoot_sfx: AudioStream = load("res://assets/audio/Sound Effects/SFMG1.wav")
@export var bomb_sfx: AudioStream = load("res://assets/audio/Sound Effects/newexpl3.wav")
@export var death_sfx: AudioStream = load("res://assets/audio/Sound Effects/explcls1.wav")

var current_hp: int
var weapon_level: int = 0
var is_invincible: bool = false
var bomb_count: int = 3

# Permanent Hangar floors (PRD-08), read once at level start and re-applied on
# respawn. Guns seeds weapon_level (never below this floor); Armour sets max_hp;
# Engine scales top speed on both control branches; Bombs sets stock + blast.
var _guns_floor: int = 0
var _max_speed: float
var _bomb_blast_mult: float = 1.0

# Equipped gadget loadout (PRD-09), cached once at level start beside the tier
# read — the Hangar is the only place it changes, and only between levels, so
# there is no live re-equip. Each gadget below is a thin behaviour gated on
# membership in this list.
var _equipped: Array = []
var _spotter_overlay: Node2D
# Flare cooldown clock (counts down to 0 = ready).
var _flare_cooldown_remaining: float = 0.0
# Auto-Repair clocks: time since the last hit (its out-of-combat grace) and the
# accumulator that fires one heal tick every interval once past the grace.
var _time_since_damage: float = 0.0
var _repair_accum: float = 0.0
var _default_iframe_time: float = 1.5

var _input_source: int = InputScheme.DEFAULT_SCHEME
var _positional_target: Vector2 = Vector2.ZERO
var _touch_id: int = -1
var _fire_clock: AutoFireClock
var _scheme_resolver: InputScheme
# Live temporary toppings (fire-swap / wingman / missile) layered over the
# permanent loadout (PRD-06). The stack only ever *adds*; on expiry fire/escort
# return to today's `weapon_level` floor, never below it.
var _effects: TemporaryEffectStack
var _wingman: Node2D

func _ready() -> void:
	add_to_group("Player")
	_apply_hangar_tiers()
	current_hp = max_hp
	update_player_sprite()
	_positional_target = global_position
	_fire_clock = AutoFireClock.new(tunables.fire_interval)
	_effects = TemporaryEffectStack.new()
	_scheme_resolver = InputScheme.new(
		assist_tunables.stick_deadzone, assist_tunables.swap_debounce_seconds
	)
	_input_source = GameManager.input_scheme
	_apply_hitbox_forgiveness(_input_source)
	GameManager.report_bomb_count(bomb_count)
	if has_node("InvincibilityTimer"):
		_default_iframe_time = $InvincibilityTimer.wait_time
	_apply_gadgets()

# Cache the equipped loadout once (PRD-09) and stand up any gadget that needs a
# live node (Spotter's overlay). The rest are checked inline by membership.
func _apply_gadgets() -> void:
	_equipped = GameManager.equipped_loadout.duplicate()
	if _has_gadget("spotter"):
		_spotter_overlay = SpotterOverlay.new()
		_spotter_overlay.setup(self, GameManager.GADGET_CATALOG.spotter_lead)
		get_tree().root.add_child(_spotter_overlay)

func _has_gadget(id: String) -> bool:
	return _equipped.has(id)

# Read the permanent Hangar tiers once (PRD-08): Guns floor → weapon_level,
# Armour → max_hp, Engine → effective top speed (both branches), Bombs → stock
# + blast. Buying is impossible mid-level, so there is no live re-apply; respawn
# re-applies the same floors.
func _apply_hangar_tiers() -> void:
	var t: HangarTunables = GameManager.HANGAR_TUNABLES
	_guns_floor = HangarUpgrades.guns_floor(GameManager.tier("guns"))
	weapon_level = _guns_floor
	max_hp = HangarUpgrades.max_hp_for(GameManager.tier("armour"), t)
	_max_speed = tunables.max_speed * GameManager.speed_multiplier()
	bomb_count = HangarUpgrades.bomb_max_for(GameManager.tier("bombs"), t)
	_bomb_blast_mult = HangarUpgrades.bomb_blast_mult_for(GameManager.tier("bombs"), t)

# Translate a raw event into its device kind (+ stick magnitude), keeping the
# positional target fresh, then let the pure InputScheme resolver decide the
# movement branch. Device kind is published immediately (cosmetic, for HUD
# glyphs); the gameplay scheme is debounced so a stray event cannot thrash it.
func _unhandled_input(event: InputEvent) -> void:
	var kind: int = -1
	var magnitude: float = 1.0

	if event is InputEventMouseMotion:
		kind = InputScheme.EventKind.MOUSE
		_positional_target = event.position
	elif event is InputEventMouseButton and event.pressed:
		kind = InputScheme.EventKind.MOUSE
		_positional_target = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			kind = InputScheme.EventKind.TOUCH
			if _touch_id == -1:
				_touch_id = event.index
				_positional_target = event.position + tunables.finger_offset
		else:
			if event.index == _touch_id:
				_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == _touch_id:
			kind = InputScheme.EventKind.TOUCH
			_positional_target = event.position + tunables.finger_offset
	elif event is InputEventJoypadMotion:
		kind = InputScheme.EventKind.JOYPAD
		magnitude = absf(event.axis_value)
	elif event is InputEventJoypadButton and event.pressed:
		kind = InputScheme.EventKind.JOYPAD
	elif event is InputEventKey and event.pressed:
		if (event.is_action("move_left") or event.is_action("move_right")
				or event.is_action("move_up") or event.is_action("move_down")):
			kind = InputScheme.EventKind.KEY

	if kind != -1:
		# A sub-deadzone stick wobble is not a deliberate device touch.
		if not (kind == InputScheme.EventKind.JOYPAD
				and magnitude < assist_tunables.stick_deadzone):
			GameManager.report_input_device(kind)
		var now: float = Time.get_ticks_msec() / 1000.0
		var resolved: int = _scheme_resolver.resolve(_input_source, kind, magnitude, now)
		if resolved != _input_source:
			_set_scheme(resolved)

	if event.is_action_pressed("bomb"):
		drop_bomb()

func _set_scheme(scheme: int) -> void:
	_input_source = scheme
	_apply_hitbox_forgiveness(scheme)
	GameManager.report_input_scheme(scheme)

func _apply_hitbox_forgiveness(scheme: int) -> void:
	if has_node("CollisionShape2D"):
		$CollisionShape2D.scale = Vector2.ONE * assist_tunables.hitbox_forgiveness(scheme)

# Current pickup-magnet radius for the active scheme; pickups query this so the
# magnet honours the per-input assist knob (PRD-03). The Coin Magnet gadget
# (PRD-09) widens it by a flat bonus while equipped.
func current_magnet_radius() -> float:
	var radius: float = assist_tunables.magnet_radius(_input_source)
	if _has_gadget("coin_magnet"):
		radius += GameManager.GADGET_CATALOG.magnet_bonus_px
	return radius

func _physics_process(delta: float) -> void:
	var vp_rect: Rect2 = get_viewport_rect()

	if _input_source == InputScheme.Scheme.VELOCITY:
		var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = direction * _max_speed
		move_and_slide()
		position.x = clampf(position.x, vp_rect.position.x, vp_rect.position.x + vp_rect.size.x)
		position.y = clampf(position.y, vp_rect.position.y, vp_rect.position.y + vp_rect.size.y)
	else:
		velocity = Vector2.ZERO
		global_position = PlayerMovement.next_position(
			global_position,
			_positional_target,
			_max_speed,
			tunables.follow_lerp,
			delta,
			vp_rect
		)

	_effects.tick(delta)
	_update_wingman()
	_tick_gadgets(delta)

	var volleys: int = _fire_clock.tick(delta)
	for i in volleys:
		_fire()

func _fire() -> void:
	if not bullet_scene:
		return
	var bullets: Array = []
	if _effects.is_active("fire_swap"):
		# Temporary topping: a wide spread from the centre muzzle, computed the
		# same way enemies fan their fire (PRD-05 FirePattern).
		var fan: Array[Vector2] = FirePattern.spread_directions(
			Vector2.UP, fire_swap_count, deg_to_rad(fire_swap_arc_deg)
		)
		for dir in fan:
			bullets.append({"pos": $MuzzleCenter.global_position, "dir": dir})
		_emit_volley(bullets)
		return
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
	_emit_volley(bullets)

# Spawn a volley of player rounds, plus a homing missile while the missile
# topping is live, then announce the shot. Shared by the permanent loadout and
# the fire-swap topping so both fire one way.
func _emit_volley(bullets: Array) -> void:
	for entry in bullets:
		var b = bullet_scene.instantiate()
		get_tree().root.add_child(b)
		b.global_position = entry["pos"]
		b.direction = entry["dir"]
	if _effects.is_active("missile"):
		_fire_missile()
	shoot_projectile.emit()
	SoundManager.play_sfx(shoot_sfx)

func _fire_missile() -> void:
	if not missile_scene:
		return
	var missile = missile_scene.instantiate()
	get_tree().root.add_child(missile)
	missile.global_position = $MuzzleCenter.global_position

# Grant or refresh a temporary topping (called by the topping pickups).
func grant_temporary_effect(effect: String, duration: float) -> void:
	_effects.add(effect, duration)

# Keep the escort node in sync with the "wingman" topping: spawn one when the
# effect goes live, retire it when the effect expires.
func _update_wingman() -> void:
	if _effects.is_active("wingman"):
		if not is_instance_valid(_wingman) and wingman_scene:
			_wingman = wingman_scene.instantiate()
			get_tree().root.add_child(_wingman)
			_wingman.global_position = global_position
			_wingman.setup(self, bullet_scene)
	elif is_instance_valid(_wingman):
		_wingman.queue_free()
		_wingman = null

# Advance the time-based gadget clocks (PRD-09): the Flare cooldown counts down
# to ready, and Auto-Repair heals one tick per interval once the player has been
# undamaged for the grace window.
func _tick_gadgets(delta: float) -> void:
	if _flare_cooldown_remaining > 0.0:
		_flare_cooldown_remaining = maxf(0.0, _flare_cooldown_remaining - delta)
	if _has_gadget("auto_repair"):
		_tick_auto_repair(delta)

func _tick_auto_repair(delta: float) -> void:
	var catalog: GadgetCatalog = GameManager.GADGET_CATALOG
	_time_since_damage += delta
	if current_hp >= max_hp or _time_since_damage < catalog.auto_repair_grace:
		_repair_accum = 0.0
		return
	_repair_accum += delta
	if _repair_accum >= catalog.auto_repair_interval:
		_repair_accum -= catalog.auto_repair_interval
		repair_health(catalog.auto_repair_amount)

# Flare (PRD-09): on an otherwise-fatal hit, if equipped and off cooldown, negate
# the lethal blow — clear nearby enemy fire (radius variant of the bomb clear),
# grant brief i-frames, and start the cooldown. Returns true when it saved the
# player (so the caller skips the death). Auto-trigger only; no input.
func _try_flare(amount: int) -> bool:
	if not _has_gadget("flare") or _flare_cooldown_remaining > 0.0:
		return false
	if current_hp - amount > 0:
		return false  # not a fatal hit; take it normally
	var catalog: GadgetCatalog = GameManager.GADGET_CATALOG
	_flare_cooldown_remaining = catalog.flare_cooldown
	_time_since_damage = 0.0  # a near-death counts as combat — restart repair grace
	_repair_accum = 0.0
	_clear_fire_in_radius(catalog.flare_radius)
	_play_hit_feedback()
	start_invincibility(catalog.flare_iframes)
	return true

# Clear every enemy projectile within `radius` of the player (Flare's defensive
# pop), reusing the pure BombTargeting selection.
func _clear_fire_in_radius(radius: float) -> void:
	var tree := get_tree()
	if not tree:
		return
	var bullets: Array = tree.get_nodes_in_group("EnemyProjectiles")
	var positions: Array = []
	for bullet in bullets:
		positions.append(bullet.global_position)
	for i in BombTargeting.within_radius(positions, global_position, radius):
		bullets[i].queue_free()

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

	var enemies: Array = tree.get_nodes_in_group("Enemies")
	var enemy_positions: Array = []
	for enemy in enemies:
		enemy_positions.append(enemy.global_position)
	var bomb_damage: int = int(round(100 * _bomb_blast_mult))
	for i in BombTargeting.affected_by_bomb(enemy_positions, screen):
		enemies[i].take_damage(bomb_damage)

	var enemy_bullets: Array = tree.get_nodes_in_group("EnemyProjectiles")
	var bullet_positions: Array = []
	for bullet in enemy_bullets:
		bullet_positions.append(bullet.global_position)
	for i in BombTargeting.affected_by_bomb(bullet_positions, screen):
		enemy_bullets[i].queue_free()

func add_bomb(amount: int) -> void:
	bomb_count += amount
	GameManager.report_bomb_count(bomb_count)

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

	# Flare intercepts an otherwise-fatal hit before any HP is lost (PRD-09).
	if _try_flare(amount):
		return

	GameManager.reset_combo()
	current_hp -= amount
	_time_since_damage = 0.0  # back into combat — Auto-Repair grace restarts
	_repair_accum = 0.0
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

func start_invincibility(duration: float = -1.0) -> void:
	is_invincible = true
	modulate.a = 0.5
	if has_node("InvincibilityTimer"):
		$InvincibilityTimer.wait_time = duration if duration > 0.0 else _default_iframe_time
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
	# Back to the permanent Guns floor, never 0 (PRD-08).
	weapon_level = _guns_floor
	update_player_sprite()
	var vp = get_viewport_rect()
	position = Vector2(vp.size.x / 2.0, vp.size.y * 0.85)
	_positional_target = position
	start_invincibility()

func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	modulate.a = 1.0
