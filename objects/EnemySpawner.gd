extends Node2D

var _config: StageConfig = null

@onready var _director: SpawnDirector = $SpawnDirector


func start_stage(_stage_index: int, config: StageConfig) -> void:
	_config = config
	_director.stop()
	_director.start(config, get_tree().current_scene)


func _ready() -> void:
	_director.boss_threshold_reached.connect(_on_boss_threshold_reached)


func _on_boss_threshold_reached() -> void:
	_director.stop()
	_spawn_boss()


func _spawn_boss() -> void:
	if _config == null or _config.boss_scene == null:
		return
	var boss: Node = _config.boss_scene.instantiate()
	boss.max_hp = _config.boss_hp
	boss.global_position = Vector2(270, -100)
	get_tree().current_scene.add_child(boss)
