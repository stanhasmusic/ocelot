extends Node2D

# Temporary escort spawned by the player while the "wingman" topping is live
# (PRD-06). It eases toward an offset beside the player and auto-fires upward
# on its own clock, adding to the player's volume of fire. The player frees it
# when the effect expires. Fire geometry goes through PRD-05's FirePattern so
# the escort aims the same way enemies do.

@export var bullet_scene: PackedScene
@export var fire_interval: float = 0.35
@export var follow_offset: Vector2 = Vector2(64.0, 24.0)
@export var follow_lerp: float = 8.0

var _player: Node2D
var _fire_clock: AutoFireClock


func _ready() -> void:
	_fire_clock = AutoFireClock.new(fire_interval)


# Bind the escort to its owner. Falls back to the player's bullet scene so the
# wingman fires the same round the player does unless overridden.
func setup(player: Node2D, player_bullet_scene: PackedScene) -> void:
	_player = player
	if bullet_scene == null:
		bullet_scene = player_bullet_scene


func _physics_process(delta: float) -> void:
	if is_instance_valid(_player):
		var target: Vector2 = _player.global_position + follow_offset
		global_position = global_position.lerp(target, clampf(follow_lerp * delta, 0.0, 1.0))
	for _i in _fire_clock.tick(delta):
		_fire()


func _fire() -> void:
	if bullet_scene == null:
		return
	var bullet: Node = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = global_position
	bullet.direction = FirePattern.aimed_direction(global_position, global_position + Vector2.UP)
