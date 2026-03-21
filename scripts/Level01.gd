extends Node2D

@export var level_music: AudioStream

@onready var pause_menu = $PauseMenu

func _ready() -> void:
	if level_music:
		SoundManager.play_music(level_music)
	GameManager.on_boss_died.connect(_on_boss_died)

func _on_boss_died() -> void:
	GameManager.level_complete()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.pause()
