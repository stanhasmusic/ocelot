extends GutTest

# Guards the de-fragilised aimed classifier (PRD-04). The director used to decide
# "is this enemy aimed?" by string-matching "Tank"/"Ship" in the scene path — which
# silently breaks the moment PRD-05 adds an aimed enemy with a different name. The
# director now reads the enemy's declared `primary_threat_tier` straight from the
# packed scene state (no combat instantiated). These tests pack enemies whose names
# deliberately contradict their tier, proving the filename no longer decides.

const EnemyScript := preload("res://actors/Enemy.gd")


func _packed_enemy(tier: int, node_name: String) -> PackedScene:
	var enemy: Area2D = EnemyScript.new()
	enemy.name = node_name
	enemy.primary_threat_tier = tier
	var packed := PackedScene.new()
	packed.pack(enemy)
	enemy.free()
	return packed


func test_aimed_tier_is_aimed_even_when_not_named_tank_or_ship() -> void:
	var director := SpawnDirector.new()
	var scene := _packed_enemy(ThreatTier.Tier.AIMED, "Harmless")
	assert_true(director._is_aimed_scene(scene), "declared AIMED tier classifies as aimed")
	director.free()


func test_straight_tier_is_not_aimed_even_when_named_tank() -> void:
	var director := SpawnDirector.new()
	var scene := _packed_enemy(ThreatTier.Tier.STRAIGHT, "Tank")
	assert_false(director._is_aimed_scene(scene), "filename no longer forces an aimed classification")
	director.free()
