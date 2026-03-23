extends Control

var _advanced: bool = false

func _ready() -> void:
	var stars = GameManager.last_level_stars
	var star_text = ""
	for i in range(3):
		star_text += "★" if i < stars else "☆"
	$CenterContainer/VBoxContainer/StarsLabel.text = star_text

	$CenterContainer/VBoxContainer/ScoreLabel.text = "SCORE: " + str(GameManager.score)
	$CenterContainer/VBoxContainer/BestLabel.text = "BEST: " + str(GameManager.high_score)

	if GameManager.last_level_new_record:
		var label = $CenterContainer/VBoxContainer/NewRecordLabel
		label.visible = true
		var tween = create_tween().set_loops()
		tween.tween_property(label, "modulate:a", 0.3, 0.5)
		tween.tween_property(label, "modulate:a", 1.0, 0.5)

	if GameManager.next_level.is_empty():
		$CenterContainer/VBoxContainer/ButtonRow/NextLevelButton.visible = false

	$CenterContainer/VBoxContainer/ButtonRow/PlayAgainButton.pressed.connect(_on_play_again)
	$CenterContainer/VBoxContainer/ButtonRow/NextLevelButton.pressed.connect(_on_next_level)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_next_level()

func _on_play_again() -> void:
	if _advanced:
		return
	_advanced = true
	GameManager.reset_score()
	GameManager.reset_lives()
	get_tree().change_scene_to_file(GameManager.current_level)

func _on_next_level() -> void:
	if _advanced:
		return
	if GameManager.next_level.is_empty():
		_advanced = true
		get_tree().change_scene_to_file("res://ui/LevelSelect.tscn")
		return
	_advanced = true
	get_tree().change_scene_to_file(GameManager.next_level)
