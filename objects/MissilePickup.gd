extends PickupBase

# Temporary missile topping (PRD-06). For `duration` seconds each volley also
# launches an explosive-tagged homing missile -- the in-run answer to heavy
# targets. The armour / explosive-damage *interaction* is PRD-10; here the
# missile simply exists and is tagged. Grant only; layering is the player's
# TemporaryEffectStack.

const EFFECT_ID: String = "missile"

@export var duration: float = 8.0


func _apply(player: Node2D) -> void:
	if player.has_method("grant_temporary_effect"):
		player.grant_temporary_effect(EFFECT_ID, duration)
