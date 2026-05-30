extends PickupBase

# +1 life. Fall / magnet / despawn live in PickupBase.

func _apply(_player: Node2D) -> void:
	GameManager.add_life()
