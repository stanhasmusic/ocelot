extends Node

signal on_score_updated(new_score: int)
signal on_spawn_score_updated(spawn_score: int)
signal on_combo_changed(new_multiplier: int)
signal on_boss_health_changed(current: int, max_hp: int)
signal on_boss_spawned(max_hp: int)
signal on_boss_died
signal on_lives_changed(new_lives: int)
signal on_bomb_count_changed(new_count: int)

const SAVE_PATH: String = "user://savegame.tres"

var score: int = 0
var spawn_score: int = 0
var combo_count: int = 0
var high_score: int = 0
var level_stars: Dictionary = {}
var last_level_stars: int = 0
var last_level_new_record: bool = false
var _level_start_lives: int = 3
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var unlocked_level: int = 1
var current_level: String = "res://scenes/Level01.tscn"
var next_level: String = ""
var lives: int = 3

const LEVELS: Array[String] = [
	"res://scenes/Level01.tscn",
	"res://scenes/LevelLand.tscn",
	"res://scenes/Level03.tscn",
]

func _ready() -> void:
	# Ensure audio buses are loaded (Project Settings bug workaround)
	if AudioServer.bus_count <= 1:
		var bus_layout_path = "res://resources/default_bus_layout.tres"
		if ResourceLoader.exists(bus_layout_path):
			AudioServer.set_bus_layout(load(bus_layout_path))
			print("Forced reload of default_bus_layout.tres")

	setup_inputs()
	load_data()
	
	# Apply loaded volumes
	update_volume(0, master_volume)
	update_volume(1, music_volume)
	update_volume(2, sfx_volume)

func update_volume(bus_index: int, value: float) -> void:
	# Update internal var
	match bus_index:
		0: master_volume = value
		1: music_volume = value
		2: sfx_volume = value
	
	# Apply to AudioServer
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	save_data() # Auto-save settings

func setup_inputs() -> void:
	# Define Actions and Events

	
	# Let's use the robust helper method approach directly here for clarity
	_map_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_map_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_map_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_map_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	
	_map_action("shoot", [KEY_SPACE], [], [JOY_AXIS_TRIGGER_RIGHT])
	_map_action("bomb", [KEY_ALT], [JOY_BUTTON_X]) # Xbox X is usually bomb? User said A for confirm. Let's start with defaults.
	# User Request: A for Confirm (ui_accept).
	# Previously Bomb was Alt/A. This conflicts.
	# Let's move Bomb to X (Xbox) / Square (PS) / Key Alt.
	_map_action("bomb", [KEY_ALT], [JOY_BUTTON_X])
	
	_map_action("ui_accept", [KEY_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_map_action("ui_cancel", [KEY_ESCAPE], [JOY_BUTTON_B])
	_map_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	
	# Axis Mappings for Movement (Sticks)
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)

func _map_action(action: String, keys: Array, buttons: Array, axes: Array = []) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	
	for k in keys:
		var e = InputEventKey.new()
		e.keycode = k
		if not InputMap.action_has_event(action, e): InputMap.action_add_event(action, e)
		
	for b in buttons:
		var e = InputEventJoypadButton.new()
		e.button_index = b
		if not InputMap.action_has_event(action, e): InputMap.action_add_event(action, e)

	for a in axes:
		var e = InputEventJoypadMotion.new()
		e.axis = a
		e.axis_value = 1.0
		if not InputMap.action_has_event(action, e): InputMap.action_add_event(action, e)

func _add_axis(action: String, axis: int, val: float) -> void:
	var e = InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = val
	if not InputMap.action_has_event(action, e): InputMap.action_add_event(action, e)

func get_multiplier() -> int:
	return clampi(1 + combo_count / 5, 1, 5)

func add_score(points: int) -> void:
	combo_count += 1
	spawn_score += points
	score += points * get_multiplier()
	on_score_updated.emit(score)
	on_spawn_score_updated.emit(spawn_score)
	on_combo_changed.emit(get_multiplier())

func reset_combo() -> void:
	combo_count = 0
	on_combo_changed.emit(1)

func reset_score() -> void:
	score = 0
	spawn_score = 0
	reset_combo()
	on_score_updated.emit(score)

func reset_lives() -> void:
	lives = 3
	_level_start_lives = 3
	on_lives_changed.emit(lives)

func add_life() -> void:
	lives += 1
	on_lives_changed.emit(lives)

func level_complete() -> void:
	current_level = get_tree().current_scene.scene_file_path
	var idx = LEVELS.find(current_level)
	if idx >= 0 and idx + 1 < LEVELS.size():
		next_level = LEVELS[idx + 1]
		unlocked_level = max(unlocked_level, idx + 2) # 1-based
	else:
		next_level = ""

	# Star rating: 3 = no lives lost, 2 = lost 1, 1 = lost 2+
	var lives_lost = _level_start_lives - lives
	last_level_stars = clampi(3 - lives_lost, 1, 3)

	# Persist best star count per level
	if idx >= 0:
		var key = str(idx)
		level_stars[key] = max(level_stars.get(key, 0), last_level_stars)

	# New record check
	last_level_new_record = score > high_score
	if last_level_new_record:
		high_score = score

	save_data()
	get_tree().call_deferred("change_scene_to_file", "res://ui/LevelComplete.tscn")

func game_over() -> void:
	if score > high_score:
		high_score = score
		save_data()
	current_level = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file("res://ui/GameOver.tscn")

func save_data() -> void:
	var save_game = SaveGame.new()
	save_game.high_score = high_score
	save_game.master_volume = master_volume
	save_game.music_volume = music_volume
	save_game.sfx_volume = sfx_volume
	save_game.unlocked_level = unlocked_level
	save_game.level_stars = level_stars
	ResourceSaver.save(save_game, SAVE_PATH)

func load_data() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		var save_game = load(SAVE_PATH) as SaveGame
		if save_game:
			high_score = save_game.high_score
			master_volume = save_game.master_volume
			music_volume = save_game.music_volume
			sfx_volume = save_game.sfx_volume
			unlocked_level = save_game.unlocked_level
			level_stars = save_game.level_stars
		else:
			print("Error loading save data. File may be corrupted or script path changed. Creating new save.")
			save_data()
	else:
		save_data() # Create initial save if none exists

func report_boss_spawned(max_hp: int) -> void:
	on_boss_spawned.emit(max_hp)

func report_boss_health(current: int, max_hp: int) -> void:
	on_boss_health_changed.emit(current, max_hp)

func report_boss_died() -> void:
	on_boss_died.emit()

func report_bomb_count(count: int) -> void:
	on_bomb_count_changed.emit(count)
