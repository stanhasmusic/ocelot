extends CanvasLayer

var _displayed_lives: int = -1

func _ready() -> void:
	_displayed_lives = GameManager.lives
	$Control/ScoreLabel.text = str(GameManager.score)
	$Control/LivesLabel.text = "LIVES: " + str(GameManager.lives)
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		$Control/BombLabel.text = "Bombs: " + str(players[0].bomb_count)
	else:
		$Control/BombLabel.text = "Bombs: 3"
	GameManager.on_score_updated.connect(_update_score_label)
	GameManager.on_lives_changed.connect(_update_lives_label)
	GameManager.on_bomb_count_changed.connect(_update_bomb_label)

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
	$Control/BombLabel.text = "Bombs: " + str(new_count)
