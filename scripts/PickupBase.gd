class_name PickupBase
extends Area2D

# Shared base for every in-run pickup (PRD-06). Before this, PowerUp / Repair /
# LifeUp / Bomb / DiagonalGun each re-implemented the same fall + magnet +
# `body.name == "Player"` collect + off-screen despawn, so cadence and feel
# drifted between them and tuning meant editing five files. This owns all of
# that in one place; a concrete pickup overrides only its `_apply(player)`
# effect (and optionally `_pickup_sfx`).
#
# Magnet steering comes from PRD-03's `PickupMagnet`: within the player's
# per-input magnet radius the straight fall is blended with a pull toward the
# player; radius 0 reduces to today's straight fall.

@export var speed: float = 100.0


func _physics_process(delta: float) -> void:
	var players: Array = get_tree().get_nodes_in_group("Player")
	if players.size() > 0 and players[0].has_method("current_magnet_radius"):
		var player: Node2D = players[0]
		global_position += PickupMagnet.step(
			global_position, player.global_position, speed, player.current_magnet_radius(), delta
		)
	else:
		global_position.y += speed * delta
	if global_position.y > get_viewport_rect().size.y + 50.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_apply(body)
		var sfx: AudioStream = _pickup_sfx()
		if sfx:
			SoundManager.play_sfx(sfx)
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()


# Apply this pickup's effect to the collecting player. Override per pickup.
func _apply(_player: Node2D) -> void:
	pass


# The distinct sound this pickup plays on collect, or null for silence.
# Override per pickup so each type reads differently by ear (user story 11).
func _pickup_sfx() -> AudioStream:
	return null
