extends Node2D

signal stage_started(stage_index: int)

const TOTAL_STAGES: int = 3

@export var background_scene: PackedScene
@export var background_overrides: Dictionary = {}
@export var level_music: AudioStream
@export var stages: Array[StageConfig] = []

var stage_index: int = 0
var _transitioning: bool = false

@onready var pause_menu = $PauseMenu
@onready var enemy_spawner = $EnemySpawner
@onready var stage_overlay = $StageOverlay
@onready var background_slot = $BackgroundSlot


func _ready() -> void:
	_instantiate_background()
	if level_music:
		SoundManager.play_music(level_music)
	if not GameManager.on_boss_died.is_connected(_on_boss_died):
		GameManager.on_boss_died.connect(_on_boss_died)
	if GameManager.resuming:
		# Continue: re-enter at the saved checkpoint stage, keeping the loaded
		# checkpoint intact (PRD-07, Story 3). Consume the flag so advancing to
		# the next level falls back to the fresh-run path below.
		stage_index = GameManager.checkpoint.resume_point()["stage_index"]
		GameManager.resuming = false
	else:
		# Fresh run through this level: clear any prior stage progress (PRD-02).
		GameManager.reset_checkpoint()
	_start_stage_transition()


func _instantiate_background() -> void:
	if background_scene == null:
		push_warning("LevelBase: background_scene is null; no backdrop will be shown.")
		return
	var bg = background_scene.instantiate()
	background_slot.add_child(bg)
	for key in background_overrides.keys():
		bg.set(key, background_overrides[key])


func _begin_stage(idx: int) -> void:
	stage_started.emit(idx)
	# Bank the stage boundary so a mid-level death resumes here, not the level
	# start. Respawn keeps the player in-place, so the checkpoint is honoured by
	# construction; this also seeds the resume point for campaign persistence (PRD-07).
	GameManager.bank_checkpoint(idx, CheckpointState.Marker.STAGE_START)
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
