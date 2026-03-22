extends Node2D

@export var enemy_scene: PackedScene
@export var ship_scene: PackedScene
@export var truck_scene: PackedScene
@export var boss_scene: PackedScene                                    # fallback single boss
@export var boss_scenes: Array[PackedScene] = []                       # one per stage (overrides boss_scene)
@export var stage_boss_hp: Array[int] = [50, 75, 100]                 # HP per stage
@export var stage_start_intervals: Array[float] = [1.5, 1.1, 0.8]    # spawn rate baseline per stage
@export var spawn_width_offset: float = 200.0
@export var boss_score_threshold: int = 2000

const MIN_INTERVAL: float = 0.5
const SCALE_SCORE_CAP: float = 1500.0

var boss_spawned: bool = false
var current_stage: int = 0   # 0-indexed
var stage_start_score: int = 0

func _ready() -> void:
	GameManager.on_score_updated.connect(_on_score_updated)

func reset_for_stage(stage_index: int) -> void:
	current_stage = stage_index
	stage_start_score = GameManager.score
	boss_spawned = false
	var start_interval = stage_start_intervals[stage_index] if stage_index < stage_start_intervals.size() else 1.5
	$Timer.wait_time = start_interval
	$Timer.start()

func _on_score_updated(score: int) -> void:
	var stage_score = score - stage_start_score
	if stage_score >= boss_score_threshold and not boss_spawned:
		call_deferred("spawn_boss")
		return
	var t = clampf(float(stage_score) / SCALE_SCORE_CAP, 0.0, 1.0)
	var start_interval = stage_start_intervals[current_stage] if current_stage < stage_start_intervals.size() else 1.5
	$Timer.wait_time = lerpf(start_interval, MIN_INTERVAL, t)

func spawn_boss() -> void:
	var scene_to_use: PackedScene
	if boss_scenes.size() > current_stage:
		scene_to_use = boss_scenes[current_stage]
	elif boss_scene:
		scene_to_use = boss_scene
	else:
		return

	boss_spawned = true
	$Timer.stop()

	var boss = scene_to_use.instantiate()
	if current_stage < stage_boss_hp.size():
		boss.max_hp = stage_boss_hp[current_stage]
	boss.global_position = Vector2(270, -100)
	get_tree().current_scene.add_child(boss)

func _on_timer_timeout() -> void:
	if boss_spawned: return

	var potential_enemies: Array[PackedScene] = []
	if enemy_scene: potential_enemies.append(enemy_scene)
	if ship_scene: potential_enemies.append(ship_scene)
	if truck_scene: potential_enemies.append(truck_scene)

	if potential_enemies.is_empty():
		print("Error: No Enemy Scenes assigned in Spawner")
		return

	var enemy = potential_enemies.pick_random().instantiate()
	var spawn_pos = global_position
	spawn_pos.x += randf_range(-spawn_width_offset, spawn_width_offset)
	enemy.global_position = spawn_pos
	get_tree().current_scene.add_child(enemy)
