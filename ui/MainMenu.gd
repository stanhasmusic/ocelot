extends Control

@export var menu_music: AudioStream

@onready var main_container = $MainContainer
@onready var options_container = $OptionsContainer

# Buttons - Using paths based on the planned hierarchy
@onready var play_button = $MainContainer/VBoxContainer/PlayButton
@onready var options_button = $MainContainer/VBoxContainer/OptionsButton
@onready var quit_button = $MainContainer/VBoxContainer/QuitButton
@onready var back_button = $OptionsContainer/OptionsMenu/VBoxContainer/BackButton
@onready var high_score_label = $MainContainer/VBoxContainer/HighScoreLabel

func _ready() -> void:
	# Connect Signals
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Audio
	if menu_music:
		SoundManager.play_music(menu_music)
	
	# High Score
	if GameManager.high_score > 0:
		high_score_label.text = "High Score: " + str(GameManager.high_score)
	else:
		high_score_label.text = "High Score: 0"
		
	# Initial Focus (Target Play Button for Controller/Keyboard)
	play_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if options_container.visible:
			_on_back_pressed()

func _on_play_pressed() -> void:
	GameManager.reset_score()
	GameManager.reset_lives()
	get_tree().change_scene_to_file("res://scenes/Level01.tscn")

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
