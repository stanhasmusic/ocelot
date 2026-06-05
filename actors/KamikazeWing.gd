class_name KamikazeWing
extends Node2D

# The Kamikaze wing coordinator (PRD-13) — the first signature enemy, and the
# reusable pattern every later signature follows: a bespoke composite scene (this
# coordinator + members on the Enemy base), built from existing
# archetype / FirePattern / Enemy pieces, dropped into a stage as ONE
# StageIntroEvent (its spawn_position becoming the wing's anchor). No
# SignatureEnemy base class — the pattern is a documented convention (CONTEXT.md),
# not a hierarchy.
#
# On _ready it lays out the formation and computes the staggered commit schedule
# (both pure, in KamikazeChoreography), instances N members at the anchor, then:
#   1. waits for the whole wing to slide into formation,
#   2. arms each member in turn so commits land one at a time, telegraphed,
#   3. self-frees (emitting `wing_cleared`) once its last member is gone.
#
# It is NOT a boss: no on_boss_* signals, no health bar, no boss-music event, no
# progression gate. It plays over the normal stage track.

signal wing_cleared

@export var tunables: KamikazeWingTunables
@export var member_scene: PackedScene

var _members: Array = []          # member nodes (entries may go invalid as they die)
var _arm_times: Array[float] = []  # per-member: when to begin its telegraph
var _armed: Array[bool] = []
var _alive_count: int = 0
var _elapsed: float = 0.0
var _schedule_running: bool = false
var _spawned: bool = false


func _ready() -> void:
	if tunables == null:
		push_warning("KamikazeWing has no tunables; wing will not spawn.")
		return
	if member_scene == null:
		push_warning("KamikazeWing has no member_scene; wing will not spawn.")
		return
	_spawn_members()


func _spawn_members() -> void:
	var offsets: Array[Vector2] = KamikazeChoreography.member_offsets(
		tunables.count, tunables.spacing, tunables.shape
	)
	var commits: Array[float] = KamikazeChoreography.commit_times(
		tunables.count, tunables.hold_time, tunables.stagger_gap
	)
	var anchor: Vector2 = global_position
	# Members live under the stage root (our parent), not under us, so the coins
	# and explosions they spawn via get_parent() survive our self-free.
	var host: Node = get_parent()
	if host == null:
		host = self
	for i in offsets.size():
		var member: Node = member_scene.instantiate()
		host.add_child(member)
		member.configure(tunables, anchor + offsets[i])
		member.tree_exited.connect(_on_member_gone)
		_members.append(member)
		_armed.append(false)
		_arm_times.append(maxf(0.0, commits[i] - tunables.telegraph_seconds))
		_alive_count += 1
	_spawned = _alive_count > 0
	# An empty wing (mis-authored count) clears immediately rather than hanging.
	if not _spawned:
		wing_cleared.emit()
		queue_free()


func _process(delta: float) -> void:
	if not _spawned:
		return
	# Hold the commit clock until the whole surviving wing has formed up, so the
	# dives read as "descend → settle → strike" rather than firing mid-entry.
	if not _schedule_running:
		if _all_in_formation():
			_schedule_running = true
			_elapsed = 0.0
		return
	_elapsed += delta
	for i in _members.size():
		if _armed[i]:
			continue
		if _elapsed < _arm_times[i]:
			continue
		_armed[i] = true
		var member: Node = _members[i]
		if is_instance_valid(member):
			member.arm()


func _all_in_formation() -> bool:
	for member in _members:
		if is_instance_valid(member) and not member.is_in_formation():
			return false
	return true


func _on_member_gone() -> void:
	_alive_count -= 1
	if _alive_count <= 0:
		wing_cleared.emit()
		queue_free()
