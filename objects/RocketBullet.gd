extends Area2D

const SPEED: float = 280.0
const TURN_SPEED: float = 1.5  # radians/sec — slow enough to dodge
const HOMING_DURATION: float = 1.5  # seconds of lock-on before it commits to a heading
const MAX_LIFETIME: float = 6.0  # hard despawn failsafe, regardless of screen position

# Homing fire — colour comes from the threat-tier palette (ADR 0001).
@export var threat_tier: ThreatTier.Tier = ThreatTier.Tier.PATTERN

var direction: Vector2 = Vector2.DOWN
var _age: float = 0.0

func _ready() -> void:
	ThreatTier.apply_to_sprite(get_node_or_null("Sprite2D"), threat_tier)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= MAX_LIFETIME:
		queue_free()
		return
	# Home only for the opening window, then commit to the current heading and
	# fly straight — a dodged missile leaves the screen instead of orbiting the
	# player forever (the screen-exit notifier then frees it).
	if _age < HOMING_DURATION:
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			var target_dir = (player.global_position - global_position).normalized()
			direction = direction.lerp(target_dir, TURN_SPEED * delta).normalized()
	global_position += direction * SPEED * delta
	rotation = direction.angle() - PI / 2.0

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
