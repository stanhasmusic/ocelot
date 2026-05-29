extends GutTest

const TIERS := [ThreatTier.Tier.STRAIGHT, ThreatTier.Tier.AIMED, ThreatTier.Tier.PATTERN]


func test_every_tier_maps_to_a_color() -> void:
	for tier in TIERS:
		var color := ThreatTier.tier_to_color(tier)
		# A mapped tier must not fall through to the WHITE default.
		assert_ne(color, Color.WHITE, "tier %d should have a dedicated colour" % tier)


func test_tier_colors_are_mutually_distinct() -> void:
	var seen: Array[Color] = []
	for tier in TIERS:
		var color := ThreatTier.tier_to_color(tier)
		assert_false(color in seen, "tier %d colour must be unique" % tier)
		seen.append(color)


func test_unknown_tier_falls_back_to_white() -> void:
	assert_eq(ThreatTier.tier_to_color(999), Color.WHITE, "unknown tier returns the WHITE default")


func test_labels_are_distinct_and_named() -> void:
	assert_eq(ThreatTier.tier_to_label(ThreatTier.Tier.STRAIGHT), "STRAIGHT")
	assert_eq(ThreatTier.tier_to_label(ThreatTier.Tier.AIMED), "AIMED")
	assert_eq(ThreatTier.tier_to_label(ThreatTier.Tier.PATTERN), "PATTERN")


func test_unknown_tier_label_is_unknown() -> void:
	assert_eq(ThreatTier.tier_to_label(999), "UNKNOWN")


func test_apply_to_sprite_sets_modulate() -> void:
	var sprite := Sprite2D.new()
	var expected := ThreatTier.tier_to_color(ThreatTier.Tier.AIMED)
	ThreatTier.apply_to_sprite(sprite, ThreatTier.Tier.AIMED)
	assert_eq(sprite.modulate, expected, "sprite tinted to tier colour")
	sprite.free()


func test_apply_to_sprite_null_is_safe() -> void:
	# Must not crash when the sprite reference is missing.
	ThreatTier.apply_to_sprite(null, ThreatTier.Tier.STRAIGHT)
	assert_true(true, "applying to a null sprite is a no-op")
