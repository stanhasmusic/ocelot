extends CanvasLayer

func show_stage(stage_num: int) -> void:
	$StageLabel.text = "STAGE " + str(stage_num)
	_play_overlay()

func show_level_clear() -> void:
	$StageLabel.text = "LEVEL CLEAR"
	_play_overlay()

func _play_overlay() -> void:
	$StageLabel.modulate.a = 0.0
	$DimRect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property($DimRect, "modulate:a", 0.5, 0.3)
	tween.parallel().tween_property($StageLabel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property($DimRect, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property($StageLabel, "modulate:a", 0.0, 0.4)
