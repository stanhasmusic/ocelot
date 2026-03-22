extends Control

func _ready() -> void:
	_build_level_buttons()
	$CenterContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)

func _build_level_buttons() -> void:
	var vbox = $CenterContainer/VBoxContainer/LevelButtons
	for i in GameManager.LEVELS.size():
		var btn = Button.new()
		btn.text = "LEVEL " + str(i + 1)
		btn.add_theme_font_size_override("font_size", 32)
		btn.disabled = (i + 1 > GameManager.unlocked_level)
		var level_path = GameManager.LEVELS[i]
		btn.pressed.connect(_on_level_pressed.bind(level_path))
		vbox.add_child(btn)
	# Focus first enabled button
	for child in vbox.get_children():
		if not child.disabled:
			child.grab_focus()
			break

func _on_level_pressed(level_path: String) -> void:
	GameManager.reset_score()
	GameManager.reset_lives()
	get_tree().change_scene_to_file(level_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
