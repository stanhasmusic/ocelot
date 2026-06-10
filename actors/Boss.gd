extends Node2D

# The Boss root (PRD-12) — the canonical (and, since PRD-14, only) boss base.
# Composes a boss from BossPart children, builds a BossState brain from them,
# routes part hits through the core gate, drives each living part's fire via
# FirePattern (geometry) + AutoFireClock (cadence) behind a telegraph wind-up,
# re-tunes the survivors on every phase change, and on core death awards score
# and runs the death. Reports the existing on_boss_* signals as one monotonic
# aggregate bar. A mini-boss is the same scene with a single core-only part.
#
# Retrying from a stage checkpoint respawns a fresh Boss node, which rebuilds a
# fresh BossState — so a failed attempt resets cleanly with no extra plumbing.

@export_group("Movement")
@export var sway_speed: float = 1.2      # horizontal sine frequency
@export var sway_amplitude: float = 120.0  # horizontal sway in px about the spawn x
@export var vertical_speed: float = 18.0  # slow descent until settled
@export var settle_y: float = 170.0      # stop descending at this y

@export_group("Identity")
## Named bosses (the level's set-piece climax) swap the background to the boss
## arena on spawn (PRD-14) and, later, hard-swap to boss music (PRD-16).
## Mini-bosses leave this false: they fight over the parked strip, no music swap,
## but still report the aggregate health bar. The one reusable named/mini split.
@export var is_named_boss: bool = false

@export_group("Reward")
@export var defeat_score: int = 5000
@export var weakpoint_score: int = 250   # small bonus per weak-point peeled

@export_group("Phases")
## Fire-interval multiplier applied to surviving parts per phase (index = phase-1,
## clamped). Lower = faster fire, i.e. escalation. Length is independent of the
## weak-point count; the last entry is reused for any further phases.
@export var phase_fire_scale: Array[float] = [1.0, 0.8, 0.6]

@export_group("Death")
@export var explosion_scene: PackedScene

var _state: BossState
var _parts: Array = []          # BossPart nodes
var _clocks: Dictionary = {}    # part name -> AutoFireClock
var _telegraph: Dictionary = {}  # part name -> remaining wind-up seconds (>0 = winding up)
var _time: float = 0.0
var _start_x: float = 0.0
var _defeated: bool = false
var _player: Node2D = null


func _ready() -> void:
	_start_x = position.x
	_player = get_tree().get_first_node_in_group("Player")
	_state = BossState.new()
	for child in get_children():
		if child is BossPart:
			_parts.append(child)
			child.bind_boss(self)
			_state.add_part(child.name, child.max_hp, child.is_core, child.armor)
			_clocks[child.name] = AutoFireClock.new(child.fire_interval)
			_telegraph[child.name] = 0.0
	GameManager.report_boss_spawned(_state.aggregate_hp()["max"], is_named_boss)
	_apply_phase(_state.current_phase())


func _physics_process(delta: float) -> void:
	_time += delta
	if position.y < settle_y:
		position.y += vertical_speed * delta
	position.x = _start_x + sin(_time * sway_speed) * sway_amplitude
	_aim_turrets()
	_process_fire(delta)


# Route a part hit through the gate. Caps single-hit damage (parity with the
# prototype) so a bomb's big AoE can't one-shot a part. A no-op result means the
# hit was shrugged off (a gated core or a dead part) — no feedback beyond the
# projectile vanishing.
func route_damage(part_name: StringName, amount: int) -> void:
	if _defeated:
		return
	var before_phase: int = _state.current_phase()
	var result: Dictionary = _state.apply_damage(part_name, mini(amount, 10))
	if not result["ok"]:
		return
	_emit_health()
	var part: BossPart = _find_part(part_name)
	if part:
		if result["destroyed"]:
			part.on_destroyed()
			if not part.is_core:
				GameManager.add_score(weakpoint_score)
		else:
			part.on_damaged(result["current_hp"])
	var after_phase: int = _state.current_phase()
	if after_phase != before_phase:
		_apply_phase(after_phase)
	if _state.is_defeated():
		_die()


# Rotate each aimed part's turret sprite to track the player (readability: the
# gun visibly points where its bullets will go). Parts with no Turret child or
# not flagged `aimed` keep their authored pose.
func _aim_turrets() -> void:
	if not is_instance_valid(_player):
		return
	for part in _parts:
		if not is_instance_valid(part) or part.is_destroyed:
			continue
		if not part.aimed:
			continue
		part.aim_turret_at(_player.global_position)


func _emit_health() -> void:
	var agg: Dictionary = _state.aggregate_hp()
	GameManager.report_boss_health(agg["current"], agg["max"])


# Drive every living part's fire behind its telegraph. A part begins a wind-up
# when its clock ticks a volley; the shot lands only when the wind-up elapses.
func _process_fire(delta: float) -> void:
	if _defeated:
		return
	for part in _parts:
		if not is_instance_valid(part) or part.is_destroyed:
			continue
		if not _state.is_alive(part.name):
			continue
		# The core stays silent until it is exposed.
		if part.is_core and not _state.is_core_exposed():
			continue
		if part.fire_interval <= 0.0:
			continue
		var key: StringName = part.name
		if _telegraph[key] > 0.0:
			_telegraph[key] -= delta
			if _telegraph[key] <= 0.0:
				_fire_part(part)
			continue
		if _clocks[key].tick(delta) > 0:
			if part.telegraph_seconds > 0.0:
				_telegraph[key] = part.telegraph_seconds
				_show_tell(part)
			else:
				_fire_part(part)


# Functional placeholder tell (PRD-12): the part brightens toward yellow over the
# wind-up, then snaps back. Telegraph juice (charge anims, muzzle build-up) is
# PRD-20.
func _show_tell(part: BossPart) -> void:
	var body: Node = part.get_node_or_null("Body")
	if body == null:
		return
	var t := create_tween()
	t.tween_property(body, "modulate", Color(1.7, 1.7, 0.4, 1.0), part.telegraph_seconds * 0.6)
	t.tween_property(body, "modulate", Color.WHITE, 0.1)


func _fire_part(part: BossPart) -> void:
	if part.bullet_scene == null:
		return
	var origin: Vector2 = part.muzzle_position()
	var base: Vector2 = Vector2.DOWN
	if part.aimed and is_instance_valid(_player):
		base = FirePattern.aimed_direction(origin, _player.global_position)
	var dirs: Array[Vector2] = FirePattern.spread_directions(
		base, maxi(part.shot_count, 1), part.spread_arc
	)
	for d in dirs:
		var b: Node = part.bullet_scene.instantiate()
		get_tree().current_scene.add_child(b)
		b.global_position = origin
		# TurretBullet (the reference bosses' projectile) travels
		# Vector2.RIGHT.rotated(rotation), so rotation = the travel angle. Also
		# set `direction` for the scripts that move by a direction vector. (An
		# always-downward bullet like EnemyBullet ignores both.)
		b.rotation = d.angle()
		if "direction" in b:
			b.direction = d


# Re-tune the surviving parts' fire for the new phase (usually escalating). New
# bosses tune the curve via `phase_fire_scale`.
func _apply_phase(phase: int) -> void:
	var fire_scale: float = 1.0
	if phase_fire_scale.size() > 0:
		fire_scale = phase_fire_scale[clampi(phase - 1, 0, phase_fire_scale.size() - 1)]
	for part in _parts:
		if not is_instance_valid(part) or part.is_destroyed:
			continue
		var clock: AutoFireClock = _clocks[part.name]
		clock.fire_interval = part.fire_interval * fire_scale if part.fire_interval > 0.0 else 0.0
		clock.reset()


func _die() -> void:
	if _defeated:
		return
	_defeated = true
	GameManager.report_boss_died()
	GameManager.add_score(defeat_score)
	if explosion_scene:
		for _i in range(6):
			var e: Node = explosion_scene.instantiate()
			get_tree().current_scene.add_child(e)
			e.global_position = global_position + Vector2(randf_range(-80, 80), randf_range(-80, 80))
	queue_free()


func _find_part(part_name: StringName) -> BossPart:
	for part in _parts:
		if part.name == part_name:
			return part
	return null
