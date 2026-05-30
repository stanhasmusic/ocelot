extends PickupBase

# Temporary wingman topping (PRD-06). For `duration` seconds an escort flies
# with the player and adds fire. The escort node is spawned/retired by the
# player while the effect is live; this pickup just grants it. Layering /
# expiry is the player's TemporaryEffectStack.

const EFFECT_ID: String = "wingman"

@export var duration: float = 12.0


func _apply(player: Node2D) -> void:
	if player.has_method("grant_temporary_effect"):
		player.grant_temporary_effect(EFFECT_ID, duration)
