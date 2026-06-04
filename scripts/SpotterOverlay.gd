class_name SpotterOverlay
extends Node2D

# Spotter gadget, first pass (PRD-09): an inbound-aimed-fire indicator and
# nothing more. It draws a small reticle on any enemy projectile whose trajectory
# will bring it close to the player within the look-ahead window, so the player
# can read which rounds are actually coming for them. The enemy-highlight +
# weak-point/phase reveal is the PRD-12 upgrade (#34) — deliberately out of scope.
#
# Lives in world space as a child of the scene root (like the Wingman), holding a
# reference to the player. Velocity is estimated from each round's per-frame
# displacement, so it works for any projectile script without coupling to it.

# A round counts as "aimed at me" if its closest approach to the player over the
# look-ahead window falls within this radius (px).
const THREAT_RADIUS: float = 44.0
const RETICLE_RADIUS: float = 16.0
const RETICLE_COLOR: Color = Color(1.0, 0.25, 0.2, 0.9)

var _player: Node2D
var _lead: float = 0.6
# instance_id -> last frame's global_position, to estimate each round's velocity.
var _prev_positions: Dictionary = {}
# Positions flagged inbound this frame; recomputed each _process, drawn in _draw.
var _threats: Array = []


func setup(player: Node2D, lead: float) -> void:
	_player = player
	_lead = lead


func _process(_delta: float) -> void:
	# The overlay outlives nothing: if the player is gone (level change / death
	# with no respawn), retire ourselves.
	if not is_instance_valid(_player):
		queue_free()
		return

	var player_pos: Vector2 = _player.global_position
	var current: Dictionary = {}
	_threats.clear()
	for bullet in get_tree().get_nodes_in_group("EnemyProjectiles"):
		var id: int = bullet.get_instance_id()
		var pos: Vector2 = bullet.global_position
		current[id] = pos
		var velocity: Vector2 = pos - _prev_positions.get(id, pos)  # per-frame step
		if _is_inbound(pos, velocity, player_pos):
			_threats.append(pos)
	_prev_positions = current  # naturally drops despawned rounds
	queue_redraw()


func _draw() -> void:
	for pos in _threats:
		draw_arc(pos, RETICLE_RADIUS, 0.0, TAU, 20, RETICLE_COLOR, 2.0)


# True when the round's closest approach to the player, projected forward over
# the look-ahead window, lands within THREAT_RADIUS. A round moving away (or
# stationary) closes no distance, so it is never flagged.
func _is_inbound(pos: Vector2, velocity: Vector2, player_pos: Vector2) -> bool:
	if velocity.length_squared() < 0.0001:
		return false
	var rel: Vector2 = pos - player_pos
	# Closest-approach time of a point moving at `velocity`, in per-frame steps;
	# `_lead` is seconds, so the horizon is lead * ~60 frames.
	var horizon: float = _lead * 60.0
	var t: float = clampf(-rel.dot(velocity) / velocity.length_squared(), 0.0, horizon)
	var closest: Vector2 = rel + velocity * t
	return closest.length() <= THREAT_RADIUS
