extends CanvasLayer

func _ready() -> void:
	$Control/ScoreLabel.text = str(GameManager.score)
	$Control/LivesLabel.text = "\u2665 " + str(GameManager.lives)
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		$Control/BombLabel.text = "B: " + str(players[0].bomb_count)
	else:
		$Control/BombLabel.text = "\U0001F4A3 3"
	GameManager.on_score_updated.connect(_update_score_label)
	GameManager.on_lives_changed.connect(_update_lives_label)
	GameManager.on_bomb_count_changed.connect(_update_bomb_label)

func _update_score_label(new_score: int) -> void:
	$Control/ScoreLabel.text = str(new_score)

func _update_lives_label(new_lives: int) -> void:
	$Control/LivesLabel.text = "\u2665 " + str(new_lives)

func _update_bomb_label(new_count: int) -> void:
	$Control/BombLabel.text = "B: " + str(new_count)
