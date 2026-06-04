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
	# A convoy Truck skips its random coin/bomb roll — the guaranteed convoy coin
	# in Enemy.drop_coins is the reward (PRD-11).
	if is_convoy:
		return
	# The weapon PowerUp retired with PRD-08 (the Guns tier owns firepower now),
	# so the Truck's loot is a coin or a bomb. Still 30% drop, no bomb-rarity
	# filter (bomb_keep_chance = 1.0).
	var drops = []
	var coin = load("res://objects/Coin.tscn")
	var bomb = load("res://objects/BombPickup.tscn")
	if coin: drops.append(coin)
	if bomb: drops.append(bomb)

	var chosen_scene := EnemyLoot.loot_roll(drops, randf(), randf(), randf(), 0.3, 1.0)
	if chosen_scene == null:
		return
	var pickup = chosen_scene.instantiate()
	pickup.global_position = global_position
	get_parent().call_deferred("add_child", pickup)
