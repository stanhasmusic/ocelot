extends "res://actors/Enemy.gd"

# Truck just moves forward (down) and can be shot.
# It doesn't have a turret, so we simplify.

func _physics_process(delta: float) -> void:
	# Basic movement from Enemy.gd
	super._physics_process(delta)

func _on_body_entered(_body: Node2D) -> void:
	# Trucks are on the ground, so colliding with the flying player does nothing.
	pass

func drop_loot() -> void:
	if randf() > 0.3: return
	
	var drops = []
	var powerup = load("res://objects/PowerUp.tscn")
	var bomb = load("res://objects/BombPickup.tscn")
	
	if powerup: drops.append(powerup)
	if bomb: drops.append(bomb)
	
	if drops.is_empty(): return
	
	var chosen_scene = drops.pick_random()
	var pickup = chosen_scene.instantiate()
	pickup.global_position = global_position
	get_parent().call_deferred("add_child", pickup)
