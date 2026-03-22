extends CanvasLayer

func _ready() -> void:
	$Control/ScoreLabel.text = str(GameManager.score)
	$Control/LivesLabel.text = "\u2665 " + str(GameManager.lives)
	GameManager.on_score_updated.connect(_update_score_label)
	GameManager.on_lives_changed.connect(_update_lives_label)

func _update_score_label(new_score: int) -> void:
	$Control/ScoreLabel.text = str(new_score)

func _update_lives_label(new_lives: int) -> void:
	$Control/LivesLabel.text = "\u2665 " + str(new_lives)
