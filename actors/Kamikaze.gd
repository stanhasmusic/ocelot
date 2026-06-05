extends "res://actors/Enemy.gd"

# A Kamikaze wing member (PRD-13). Its identity is "the body is the weapon": it
# NEVER fires (projectile_scene stays null). It slides into a formation slot,
# holds, then — when the coordinator arms it — telegraphs and commits a single
# straight suicide dive locked to the player's position at the commit instant.
# One dive, no looping; off-bottom (or any screen exit) despawns it for free.
#
# Built on Enemy.gd: HP, hit-flash, explosion, coin-drop and the off-screen
# despawn are all inherited. This script overrides only the movement and the
# commit guard.
#
# Invuln-on-commit, bomb-exempt: once committed, `_on_area_entered` is guarded so
# player bullets pass through, but `take_damage` is left unguarded so the bomb
# (which calls it directly on the "Enemies" group) still vaporises the plane.
# Contact with the player stays live throughout (the inherited `_on_body_entered`
# deals 1 damage and the plane dies on impact).

enum Phase { ENTER, HOLD, TELEGRAPH, DIVE }

# Members spawn this far above the screen top and slide down into their slot, so
# the wing reads as descending in from off the top. Not a feel knob.
const ENTRY_MARGIN: float = 90.0

var is_committed: bool = false

var _phase: Phase = Phase.ENTER
var _slot_pos: Vector2 = Vector2.ZERO
var _entry_speed: float = 180.0
var _telegraph_seconds: float = 1.0
var _dive_speed: float = 320.0
var _dive_accel: float = 260.0
var _telegraph_elapsed: float = 0.0
var _dive_dir: Vector2 = Vector2.DOWN
var _dive_current_speed: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	super._ready()  # no shoot_timer: projectile_scene is null
	_player = get_tree().get_first_node_in_group("Player")


# Called by the KamikazeWing coordinator right after add_child: copies the feel
# knobs in and parks the member off the top above its target slot.
func configure(tunables: KamikazeWingTunables, slot_pos: Vector2) -> void:
	_slot_pos = slot_pos
	_entry_speed = tunables.entry_speed
	_telegraph_seconds = tunables.telegraph_seconds
	_dive_speed = tunables.dive_speed
	_dive_accel = tunables.dive_accel
	hp = tunables.member_hp
	coin_value = tunables.member_coin_value
	projectile_scene = null  # belt-and-braces: the body is the weapon
	global_position = Vector2(slot_pos.x, -ENTRY_MARGIN)


# True once the member has reached its slot — the coordinator waits for the whole
# wing to form before it starts the commit clock.
func is_in_formation() -> bool:
	return _phase != Phase.ENTER


# Begin the telegraph; the dive commits on its own `_telegraph_seconds` later, so
# the coordinator only has to arm each member in turn to stagger the commits.
func arm() -> void:
	if is_dead or _phase == Phase.DIVE:
		return
	_phase = Phase.TELEGRAPH
	_telegraph_elapsed = 0.0
	_show_telegraph()


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.ENTER:
			var to_slot: Vector2 = _slot_pos - global_position
			var step: float = _entry_speed * delta
			if to_slot.length() <= step:
				global_position = _slot_pos
				_phase = Phase.HOLD
			else:
				global_position += to_slot.normalized() * step
		Phase.HOLD:
			pass
		Phase.TELEGRAPH:
			_telegraph_elapsed += delta
			if _telegraph_elapsed >= _telegraph_seconds:
				_commit()
		Phase.DIVE:
			_dive_current_speed += _dive_accel * delta
			global_position += _dive_dir * _dive_current_speed * delta


# Lock the dive line to the player's position NOW (not at spawn), via the
# already-tested FirePattern.aimed_direction, and accelerate down it. From here
# the plane is invulnerable to shots but still clearable by the bomb.
func _commit() -> void:
	is_committed = true
	_phase = Phase.DIVE
	_dive_current_speed = _dive_speed
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player")
	var target: Vector2 = global_position + Vector2.DOWN * 200.0
	if is_instance_valid(_player):
		target = _player.global_position
	_dive_dir = FirePattern.aimed_direction(global_position, target)
	if _body:
		# Body art faces up at rotation 0 (down at PI, like every enemy sprite), so
		# the nose points along the dive line at angle + PI/2.
		_body.rotation = _dive_dir.angle() + PI / 2.0


# Player bullets pass through a committed plane (the "kill it now or dodge it"
# decision). `take_damage` itself stays unguarded so the bomb still clears it.
func _on_area_entered(area: Area2D) -> void:
	if is_committed:
		return
	super._on_area_entered(area)


# Functional placeholder tell (parity with Boss._show_tell): the body banks and
# brightens toward yellow over the telegraph. Dive trails / crash juice are PRD-20.
func _show_telegraph() -> void:
	if not _body:
		return
	var bank: float = _body.rotation + 0.4
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_body, "modulate", Color(1.7, 1.7, 0.5, 1.0), _telegraph_seconds * 0.6)
	t.tween_property(_body, "rotation", bank, _telegraph_seconds * 0.6)
