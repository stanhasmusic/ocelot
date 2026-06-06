extends GutTest

# Guards the per-archetype threat-tier declarations (PRD-05). The stage director
# and projectile tinting both trust each enemy scene to declare its
# `primary_threat_tier`; this asserts every firing archetype carries the tier its
# fire behaviour implies. Reads the tier from the packed scene state the same way
# SpawnDirector does — no combat is instantiated.

var _expected := {
	"res://actors/Tank.tscn": ThreatTier.Tier.AIMED,
	"res://actors/Ship.tscn": ThreatTier.Tier.AIMED,
	"res://actors/Fighter.tscn": ThreatTier.Tier.STRAIGHT,
	"res://actors/Helicopter.tscn": ThreatTier.Tier.AIMED,
	"res://actors/EliteEscort.tscn": ThreatTier.Tier.AIMED,
	"res://actors/RocketLauncher.tscn": ThreatTier.Tier.AIMED,
	"res://actors/Bomber.tscn": ThreatTier.Tier.PATTERN,
	"res://actors/AceFighter.tscn": ThreatTier.Tier.PATTERN,
	"res://actors/Interceptor.tscn": ThreatTier.Tier.PATTERN,
}


func _declared_tier(path: String) -> int:
	var scene: PackedScene = load(path)
	var state: SceneState = scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == "primary_threat_tier":
			return int(state.get_node_property_value(0, i))
	return ThreatTier.Tier.STRAIGHT


func test_archetypes_declare_their_expected_threat_tier() -> void:
	for path in _expected:
		assert_eq(_declared_tier(path), int(_expected[path]), path)
