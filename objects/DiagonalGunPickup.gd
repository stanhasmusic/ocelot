extends PickupBase

# Weapon -> max (adds the diagonal guns). Fall / magnet / despawn in PickupBase.

func _apply(player: Node2D) -> void:
	if player.has_method("power_up_to_max"):
		player.power_up_to_max()
