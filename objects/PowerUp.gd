extends PickupBase

# Weapon level +1. Fall / magnet / despawn live in PickupBase.

func _apply(player: Node2D) -> void:
	if player.has_method("power_up_weapon"):
		player.power_up_weapon()


func _pickup_sfx() -> AudioStream:
	return preload("res://assets/audio/Sound Effects/ammorefill.wav")
