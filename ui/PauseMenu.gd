extends CanvasLayer

@onready var main_container = $Control/CenterContainer/VBoxContainer
@onready var options_container = $Control/CenterContainer/OptionsContainer
@onready var resume_button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var options_button = $Control/CenterContainer/VBoxContainer/OptionsButton
@onready var quit_button = $Control/CenterContainer/VBoxContainer/QuitButton
@onready var back_button = $Control/CenterContainer/OptionsContainer/OptionsMenu/VBoxContainer/BackButton

func _ready() -> void:
	visible = false
	
	resume_button.pressed.connect(unpause)
	options_button.pressed.connect(open_options)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(close_options)

func pause() -> void:
	get_tree().paused = true
	visible = true
	main_container.visible = true
	options_container.visible = false
	resume_button.grab_focus()

func unpause() -> void:
	get_tree().paused = false
	visible = false

func open_options() -> void:
	main_container.visible = false
	options_container.visible = true
	back_button.grab_focus()

func close_options() -> void:
	options_container.visible = false
	main_container.visible = true
	options_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("ui_cancel"):
		if options_container.visible:
			close_options()
		else:
			unpause()

func _on_quit_pressed() -> void:
	unpause()
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
