extends Area2D

const SPEED: float = 300.0

# Aimed naval fire — colour comes from the threat-tier palette (ADR 0001).
@export var threat_tier: ThreatTier.Tier = ThreatTier.Tier.AIMED

func _ready() -> void:
	ThreatTier.apply_to_sprite(get_node_or_null("Sprite2D"), threat_tier)

func _physics_process(delta: float) -> void:
	# Moves in the direction it is rotated (Vector2.UP rotated)
	position += Vector2.UP.rotated(rotation) * SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
