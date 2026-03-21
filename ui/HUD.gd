extends CanvasLayer

func _ready() -> void:
	# Initialize text
	$Control/ScoreLabel.text = str(GameManager.score)
	
	# Connect signal
	GameManager.on_score_updated.connect(_update_score_label)

func _update_score_label(new_score: int) -> void:
	$Control/ScoreLabel.text = str(new_score)
