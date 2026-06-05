extends CanvasLayer

var _displayed_lives: int = -1
var _bomb_count: int = 3

func _ready() -> void:
	_displayed_lives = GameManager.lives
	$Control/ScoreLabel.text = str(GameManager.score)
	$Control/LivesLabel.text = "LIVES: " + str(GameManager.lives)
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_bomb_count = players[0].bomb_count
	_refresh_bomb_label()
	GameManager.on_score_updated.connect(_update_score_label)
	GameManager.on_lives_changed.connect(_update_lives_label)
	GameManager.on_bomb_count_changed.connect(_update_bomb_label)
	GameManager.on_combo_changed.connect(_on_combo_changed)
	GameManager.on_input_device_changed.connect(_on_input_device_changed)
	GameManager.on_boss_spawned.connect(_on_boss_spawned)
	GameManager.on_boss_health_changed.connect(_on_boss_health_changed)
	GameManager.on_boss_died.connect(_on_boss_died)
	$Control/BombButton.pressed.connect(_on_bomb_button_pressed)
	_on_input_device_changed(GameManager.input_device)

func _update_score_label(new_score: int) -> void:
	$Control/ScoreLabel.text = str(new_score)

func _update_lives_label(new_lives: int) -> void:
	var lost = _displayed_lives > 0 and new_lives < _displayed_lives
	_displayed_lives = new_lives
	$Control/LivesLabel.text = "LIVES: " + str(new_lives)
	if lost:
		_play_life_lost_feedback()

func _play_life_lost_feedback() -> void:
	var label = $Control/LivesLabel
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)

	var popup = $Control/LifeLostLabel
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.8, 0.8)
	var ptween = create_tween()
	ptween.tween_property(popup, "modulate:a", 1.0, 0.15)
	ptween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.15)
	ptween.tween_interval(0.8)
	ptween.tween_property(popup, "modulate:a", 0.0, 0.3)

func _update_bomb_label(new_count: int) -> void:
	_bomb_count = new_count
	_refresh_bomb_label()

# Bomb label = device-appropriate input prompt + current count, kept in one place
# so the count update and the device-glyph swap never overwrite each other.
func _refresh_bomb_label() -> void:
	var prompt: String
	match GameManager.input_device:
		InputScheme.EventKind.JOYPAD:
			prompt = "Bombs (X): "
		InputScheme.EventKind.TOUCH:
			prompt = "Bombs: "
		_:
			prompt = "Bombs (ALT): "
	$Control/BombLabel.text = prompt + str(_bomb_count)

func _on_combo_changed(m: int) -> void:
	var label = $Control/ComboLabel
	if m <= 1:
		var t = create_tween()
		t.tween_property(label, "modulate:a", 0.0, 0.25)
	else:
		label.text = "x" + str(m)
		label.modulate.a = 1.0
		label.scale = Vector2(0.8, 0.8)
		var t = create_tween()
		t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12)

# PRD-03: on-screen action buttons appear only in touch mode; the bomb prompt
# glyph follows the active device so instructions are never wrong.
func _on_input_device_changed(_device: int) -> void:
	var is_touch: bool = GameManager.input_device == InputScheme.EventKind.TOUCH
	$Control/BombButton.visible = is_touch
	$Control/BombButton.text = "BOMB" if is_touch else ""
	_refresh_bomb_label()

func _on_bomb_button_pressed() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		players[0].drop_bomb()

# Boss health bar (PRD-12): minimal functional hookup to the existing BossBar.
# One monotonic aggregate that shows on spawn, drains on every change, hides on
# death. Segmented/tinted visuals + per-weak-point pips are PRD-18.
func _on_boss_spawned(max_hp: int) -> void:
	var bar = $Control/BossBar
	bar.max_value = max_hp
	bar.value = max_hp
	bar.visible = true

func _on_boss_health_changed(current: int, _max_hp: int) -> void:
	$Control/BossBar.value = current

func _on_boss_died() -> void:
	$Control/BossBar.visible = false
