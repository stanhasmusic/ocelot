class_name ThreatTier
extends RefCounted

# Single source of truth for the threat-tier visual language (ADR 0001).
#
# A projectile's *behaviour* determines its tier, and the tier determines its
# colour — never the firing enemy. The same three colours mean the same three
# things everywhere, so the language is learnable once and never lies:
#   STRAIGHT (blue)  — fixed heading; dodge by not standing in the lane.
#   AIMED   (orange) — fired at the player's position; keep moving.
#   PATTERN (purple) — spread / homing / bursts; read and thread.
#
# Pure mapping: no node, Input, or Engine dependencies; safe to unit-test.
# Re-skinning or a colour-blind palette is a one-place change here.

enum Tier { STRAIGHT, AIMED, PATTERN }

const _TIER_COLORS: Dictionary = {
	Tier.STRAIGHT: Color(0.35, 0.6, 1.0),  # blue
	Tier.AIMED: Color(1.0, 0.55, 0.1),  # orange
	Tier.PATTERN: Color(0.72, 0.38, 1.0),  # purple
}

const _TIER_LABELS: Dictionary = {
	Tier.STRAIGHT: "STRAIGHT",
	Tier.AIMED: "AIMED",
	Tier.PATTERN: "PATTERN",
}


static func tier_to_color(tier: int) -> Color:
	return _TIER_COLORS.get(tier, Color.WHITE)


static func tier_to_label(tier: int) -> String:
	return _TIER_LABELS.get(tier, "UNKNOWN")


# Convenience for projectile scripts: tint a sprite by its declared tier so the
# colour comes from this module rather than being embedded per-scene.
static func apply_to_sprite(sprite: CanvasItem, tier: int) -> void:
	if sprite:
		sprite.modulate = tier_to_color(tier)
