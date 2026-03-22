extends Node2D

@export var level_music: AudioStream

@onready var pause_menu = $PauseMenu
@onready var enemy_spawner = $EnemySpawner
@onready var stage_overlay = $StageOverlay

const TOTAL_STAGES: int = 3
var current_stage: int = 1
var _transitioning: bool = false

func _ready() -> void:
	if level_music:
		SoundManager.play_music(level_music)
	if not GameManager.on_boss_died.is_connected(_on_boss_died):
		GameManager.on_boss_died.connect(_on_boss_died)

func _on_boss_died() -> void:
	if _transitioning:
		return
	_transitioning = true
	if current_stage < TOTAL_STAGES:
		current_stage += 1
		_start_stage_transition()
	else:
		stage_overlay.show_level_clear()
		await get_tree().create_timer(3.0).timeout
		GameManager.level_complete()

func _start_stage_transition() -> void:
	stage_overlay.show_stage(current_stage)
	await get_tree().create_timer(2.5).timeout
	enemy_spawner.reset_for_stage(current_stage - 1)  # spawner is 0-indexed
	_transitioning = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.pause()
