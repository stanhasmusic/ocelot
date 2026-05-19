extends Node2D

const TOTAL_STAGES: int = 3

@export var level_music: AudioStream
@export var stages: Array[StageConfig] = []

var stage_index: int = 0
var _transitioning: bool = false

@onready var pause_menu = $PauseMenu
@onready var enemy_spawner = $EnemySpawner
@onready var stage_overlay = $StageOverlay


func _ready() -> void:
	if level_music:
		SoundManager.play_music(level_music)
	if not GameManager.on_boss_died.is_connected(_on_boss_died):
		GameManager.on_boss_died.connect(_on_boss_died)
	_begin_stage(stage_index)


func _begin_stage(idx: int) -> void:
	if idx < stages.size():
		enemy_spawner.start_stage(idx, stages[idx])


func _on_boss_died() -> void:
	if _transitioning:
		return
	_transitioning = true
	if stage_index + 1 < TOTAL_STAGES:
		stage_index += 1
		_start_stage_transition()
	else:
		stage_overlay.show_level_clear()
		await get_tree().create_timer(3.0).timeout
		GameManager.level_complete()


func _start_stage_transition() -> void:
	stage_overlay.show_stage(stage_index + 1)
	await get_tree().create_timer(2.5).timeout
	_begin_stage(stage_index)
	_transitioning = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.pause()
