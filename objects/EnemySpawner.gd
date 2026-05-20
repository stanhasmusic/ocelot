extends Node2D

var _config: StageConfig = null

@onready var _director: SpawnDirector = $SpawnDirector
@onready var _intro_player: StageIntroPlayer = $StageIntroPlayer


func start_stage(_stage_index: int, config: StageConfig) -> void:
	_config = config
	_director.stop()
	_intro_player.cancel()
	if config.intro_timeline != null and config.intro_timeline is StageIntroTimeline:
		_intro_player.intro_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
		_intro_player.play(config.intro_timeline, get_tree().current_scene)
	else:
		_start_procedural_body()


func _ready() -> void:
	_director.boss_threshold_reached.connect(_on_boss_threshold_reached)


func _on_intro_finished() -> void:
	_start_procedural_body()


func _start_procedural_body() -> void:
	if _config == null:
		return
	_director.start(_config, get_tree().current_scene)


func _on_boss_threshold_reached() -> void:
	_director.stop()
	_spawn_boss()


func _spawn_boss() -> void:
	if _config == null or _config.boss_scene == null:
		return
	var boss: Node = _config.boss_scene.instantiate()
	boss.max_hp = _config.boss_hp
	boss.global_position = Vector2(270, -100)
	get_tree().current_scene.add_child.call_deferred(boss)
