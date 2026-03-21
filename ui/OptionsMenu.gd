extends Control

@onready var master_slider = $VBoxContainer/MasterRow/HSlider
@onready var music_slider = $VBoxContainer/MusicRow/HSlider
@onready var sfx_slider = $VBoxContainer/SFXRow/HSlider
@onready var back_button = $VBoxContainer/BackButton

func _ready() -> void:
	# Initialize sliders from GameManager
	master_slider.value = GameManager.master_volume
	music_slider.value = GameManager.music_volume
	sfx_slider.value = GameManager.sfx_volume
	
	# Connect signals
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_master_changed(value: float) -> void:
	GameManager.update_volume(0, value)

func _on_music_changed(value: float) -> void:
	GameManager.update_volume(1, value)

func _on_sfx_changed(value: float) -> void:
	GameManager.update_volume(2, value)

func _on_back_pressed() -> void:
	# Signal parent to close, or just hide self?
	# Since this is likely inside a container managed by parent, we might want to emit a signal.
	# But for now, let's rely on the parent's logic to hide this container via the stored back button reference in parent logic.
	# Actually, the parent script (MainMenu/PauseMenu) usually connects to the back button of the options menu.
	# But if we put the logic here, we can make it self-contained.
	# Let's emit a signal 'request_close'
	pass # Logic is handled by Parent connecting to button directly in current architecture.
