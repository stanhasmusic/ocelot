extends PickupBase

# Temporary fire-pattern swap topping (PRD-06). For `duration` seconds the
# player's fire becomes a wide spread instead of its permanent loadout, then
# reverts to the floor. Layering / expiry is owned by the player's
# TemporaryEffectStack; this pickup just grants the effect.

const EFFECT_ID: String = "fire_swap"

@export var duration: float = 8.0


func _apply(player: Node2D) -> void:
	if player.has_method("grant_temporary_effect"):
		player.grant_temporary_effect(EFFECT_ID, duration)
