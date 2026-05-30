extends PickupBase

# Currency pickup (PRD-06). Closes the PRD-05 loop: an enemy's `drop_coins`
# hook spawns this with the archetype's `coin_value`, and collecting it banks
# that into the run total via the `GameManager.add_coins` seam. The currency
# store, persistence, and economy balancing are PRD-07 / PRD-11; here a coin
# just drops and is collected.

@export var coin_value: int = 1


func _apply(_player: Node2D) -> void:
	GameManager.add_coins(coin_value)
