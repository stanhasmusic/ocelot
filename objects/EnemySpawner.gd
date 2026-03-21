extends Node2D

@export var enemy_scene: PackedScene
@export var ship_scene: PackedScene
@export var truck_scene: PackedScene
@export var boss_scene: PackedScene
@export var spawn_width_offset: float = 200.0

var boss_spawned: bool = false

func _ready() -> void:
	GameManager.on_score_updated.connect(_on_score_updated)

func _on_score_updated(score: int) -> void:
	if score >= 2000 and not boss_spawned:
		call_deferred("spawn_boss")


func spawn_boss() -> void:
	if not boss_scene: return
	
	boss_spawned = true
	$Timer.stop() # Stop spawning normal enemies
	
	var boss = boss_scene.instantiate()
	boss.global_position = Vector2(270, -100) # Top Center
	get_tree().current_scene.add_child(boss)
	
	# Optional: Screen Shake or Warning?

func _on_timer_timeout() -> void:
	if boss_spawned: return # Ensure no enemies if boss is active logic overlap
	
	var potential_enemies: Array[PackedScene] = []
	if enemy_scene: potential_enemies.append(enemy_scene)
	if ship_scene: potential_enemies.append(ship_scene)
	if truck_scene: potential_enemies.append(truck_scene)
	
	if potential_enemies.is_empty():
		print("Error: No Enemy Scenes assigned in Spawner")
		return
		
	var chosen_scene = potential_enemies.pick_random()
		
	var enemy = chosen_scene.instantiate()
	
	# Determine spawn position
	var random_x = randf_range(-spawn_width_offset, spawn_width_offset)
	var spawn_pos = global_position
	spawn_pos.x += random_x
	
	enemy.global_position = spawn_pos
	
	# Add to main scene, not as child of spawner
	get_tree().current_scene.add_child(enemy)
