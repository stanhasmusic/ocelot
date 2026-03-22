extends Control

func _ready() -> void:
	$CenterContainer/VBoxContainer/ScoreLabel.text = "SCORE: " + str(GameManager.score)
	$CenterContainer/VBoxContainer/RetryButton.pressed.connect(_on_retry_pressed)
	$CenterContainer/VBoxContainer/MenuButton.pressed.connect(_on_menu_pressed)
	$CenterContainer/VBoxContainer/RetryButton.grab_focus()

func _on_retry_pressed() -> void:
	var level = GameManager.current_level
	GameManager.reset_score()
	GameManager.reset_lives()
	get_tree().change_scene_to_file(level)

func _on_menu_pressed() -> void:
	GameManager.reset_score()
	GameManager.reset_lives()
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
