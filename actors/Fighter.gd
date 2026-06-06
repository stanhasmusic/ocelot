extends "res://actors/Enemy.gd"

# Strafer (PRD-14): the campaign's blue tier-0 teaching enemy. Weaves laterally
# while firing STRAIGHT down (the base Enemy fire) — the lesson is "dodge by not
# standing in the lane." Distinct from its former twin Helicopter, which stays
# the orange aimed flyer. No fire override: the inherited straight-down volley is
# exactly the STRAIGHT-tier behaviour, so the bullet's blue comes from the scene.

var time_alive: float = 0.0


func _physics_process(delta: float) -> void:
	time_alive += delta
	super._physics_process(delta)
	position.x += sin(time_alive * 2.5) * 70.0 * delta
