extends PickupBase

# +1 bomb. Fall / magnet / despawn live in PickupBase.

func _apply(player: Node2D) -> void:
	if player.has_method("add_bomb"):
		player.add_bomb(1)
