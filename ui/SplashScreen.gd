extends Control

@onready var video_player = $VideoStreamPlayer
@onready var next_scene = "res://ui/MainMenu.tscn"

func _ready():
	video_player.finished.connect(_on_video_finished)
	# Optional: ensure it plays immediately
	video_player.play()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			_on_video_finished()
	elif event is InputEventMouseButton and event.pressed:
		_on_video_finished()
	elif event is InputEventJoypadButton and event.pressed:
		_on_video_finished()

func _on_video_finished():
	get_tree().change_scene_to_file(next_scene)
