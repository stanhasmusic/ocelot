extends Control

var _advanced: bool = false

func _ready() -> void:
	var stars = GameManager.last_level_stars
	var star_text = ""
	for i in range(3):
		star_text += "★" if i < stars else "☆"
	$StarsLabel.text = star_text

	$CenterContainer/VBoxContainer/ScoreLabel.text = "SCORE: " + str(GameManager.score)
	$CenterContainer/VBoxContainer/BestLabel.text = "BEST: " + str(GameManager.high_score)

	# Terminal coins→score cash-out (PRD-11): only the final level cashes the
	# wallet out, and only show the line when something actually converted. The
	# bonus is already folded into the SCORE above; this calls it out.
	var cashout_label = $CenterContainer/VBoxContainer/CashoutLabel
	if GameManager.last_coin_cashout > 0:
		cashout_label.text = "COINS CASHED OUT: +" + str(GameManager.last_coin_cashout)
		cashout_label.visible = true

	if GameManager.last_level_new_record:
		var label = $CenterContainer/VBoxContainer/NewRecordLabel
		label.visible = true
		var tween = create_tween().set_loops()
		tween.tween_property(label, "modulate:a", 0.3, 0.5)
		tween.tween_property(label, "modulate:a", 1.0, 0.5)

	# A non-final level routes to the Hangar (the spend beat) before the next
	# level; the final level has no Hangar after it (PRD-08).
	var next_button = $CenterContainer/VBoxContainer/ButtonRow/NextLevelButton
	if GameManager.next_level.is_empty():
		next_button.visible = false
	else:
		next_button.text = "TO HANGAR"

	$CenterContainer/VBoxContainer/ButtonRow/PlayAgainButton.pressed.connect(_on_play_again)
	$CenterContainer/VBoxContainer/ButtonRow/NextLevelButton.pressed.connect(_on_next_level)
	$CenterContainer/VBoxContainer/MainMenuRow/MainMenuButton.pressed.connect(_on_main_menu)
	$ConfirmDialog.confirmed.connect(_on_main_menu_confirmed)
	$ConfirmDialog.canceled.connect(_on_main_menu_canceled)

	# Give initial focus for keyboard/controller navigation
	if not GameManager.next_level.is_empty():
		$CenterContainer/VBoxContainer/ButtonRow/NextLevelButton.grab_focus()
	else:
		$CenterContainer/VBoxContainer/ButtonRow/PlayAgainButton.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_next_level()

func _on_play_again() -> void:
	if _advanced:
		return
	_advanced = true
	# Replaying an already-cleared level banks no coins — the first-clear gate in
	# GameManager.level_complete() handles that, so [Play Again] is farm-safe (PRD-11).
	GameManager.reset_score()
	GameManager.reset_lives()
	get_tree().change_scene_to_file(GameManager.current_level)

func _on_main_menu() -> void:
	if _advanced:
		return
	$ConfirmDialog.popup_centered()
	$ConfirmDialog.get_ok_button().grab_focus()

func _on_main_menu_confirmed() -> void:
	_advanced = true
	GameManager.reset_score()
	GameManager.reset_lives()
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _on_main_menu_canceled() -> void:
	$CenterContainer/VBoxContainer/MainMenuRow/MainMenuButton.grab_focus()

func _on_next_level() -> void:
	if _advanced:
		return
	if GameManager.next_level.is_empty():
		# Campaign cleared — back to the menu (LevelSelect retired in PRD-07).
		_advanced = true
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
		return
	_advanced = true
	# Spend the run's coins before deploying to the next level (PRD-08).
	get_tree().change_scene_to_file("res://ui/Hangar.tscn")
