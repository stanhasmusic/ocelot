extends PickupBase

# +2 HP. Fall / magnet / despawn live in PickupBase.

func _apply(player: Node2D) -> void:
	if player.has_method("repair_health"):
		player.repair_health(2)
