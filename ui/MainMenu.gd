extends Control

@export var menu_music: AudioStream
@export var menu_music_win: AudioStream

@onready var main_container = $MainContainer
@onready var options_container = $OptionsContainer

# Buttons - Using paths based on the planned hierarchy
@onready var continue_button = $MainContainer/VBoxContainer/ContinueButton
@onready var new_game_button = $MainContainer/VBoxContainer/PlayButton
@onready var options_button = $MainContainer/VBoxContainer/OptionsButton
@onready var quit_button = $MainContainer/VBoxContainer/QuitButton
@onready var back_button = $OptionsContainer/OptionsMenu/VBoxContainer/BackButton
@onready var high_score_label = $MainContainer/VBoxContainer/HighScoreLabel
@onready var new_game_confirm = $NewGameConfirm

func _ready() -> void:
	# Connect Signals
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	new_game_confirm.confirmed.connect(_start_new_game)

	# Continue is only available with a Playthrough in progress (PRD-07).
	continue_button.disabled = not GameManager.has_playthrough

	# Audio — play v2 theme once the whole campaign has been cleared
	var all_beaten = GameManager.campaign_level > GameManager.LEVELS.size()
	var music = menu_music_win if (all_beaten and menu_music_win) else menu_music
	if music:
		SoundManager.play_music(music)

	# High Score
	if GameManager.high_score > 0:
		high_score_label.text = "High Score: " + str(GameManager.high_score)
	else:
		high_score_label.text = "High Score: 0"

	# Initial Focus — Continue if resumable, otherwise New Game
	if GameManager.has_playthrough:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if options_container.visible:
			_on_back_pressed()

func _on_continue_pressed() -> void:
	if not GameManager.has_playthrough:
		return
	var level = GameManager.continue_playthrough()
	get_tree().change_scene_to_file(level)

func _on_new_game_pressed() -> void:
	# Confirm before clobbering an in-progress Playthrough; start fresh otherwise.
	if GameManager.has_playthrough:
		new_game_confirm.popup_centered()
		new_game_confirm.get_ok_button().grab_focus()
	else:
		_start_new_game()

func _start_new_game() -> void:
	var level = GameManager.start_new_playthrough()
	get_tree().change_scene_to_file(level)

func _on_options_pressed() -> void:
	main_container.visible = false
	options_container.visible = true
	back_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	options_container.visible = false
	main_container.visible = true
	options_button.grab_focus()
