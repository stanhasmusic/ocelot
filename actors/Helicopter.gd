extends "res://actors/Enemy.gd"

var time_alive: float = 0.0
var player: Node2D

func _ready() -> void:
	super._ready()
	player = get_tree().get_first_node_in_group("Player")

func _physics_process(delta: float) -> void:
	time_alive += delta
	super._physics_process(delta)
	position.x += sin(time_alive * 2.5) * 70.0 * delta

func _on_shoot_timer_timeout() -> void:
	if not projectile_scene:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		return
	var b = projectile_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(0, 20)
	var dir = global_position.direction_to(player.global_position)
	b.rotation = dir.angle()
