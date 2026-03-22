extends Control

const AUTO_ADVANCE_DELAY = 3.0

var _advanced: bool = false

func _ready() -> void:
	$CenterContainer/VBoxContainer/ScoreLabel.text = "SCORE: " + str(GameManager.score)
	await get_tree().create_timer(AUTO_ADVANCE_DELAY).timeout
	_advance()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()

func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	get_tree().change_scene_to_file("res://ui/LevelSelect.tscn")
