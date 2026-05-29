extends Area2D

@export var speed: float = 150.0
@export var score_value: int = 100
@export var explosion_scene: PackedScene
@export var loot_pool: Array[PackedScene] = []
@export var projectile_scene: PackedScene
@export var fire_rate: float = 2.0
@export var destroyed_texture: Texture2D

@export var hp: int = 1

# Declared primary threat tier (PRD-04 classifier contract; PRD-05 sets it per
# archetype). The stage director reads this from the packed scene to decide
# whether the enemy counts as "aimed" for the anti-frustration spacing rule —
# data, not the scene filename. Default STRAIGHT = not aimed.
@export var primary_threat_tier: ThreatTier.Tier = ThreatTier.Tier.STRAIGHT

# Coin drop (PRD-05). Currency the metagame spends; separate from the power-up
# `loot_pool` so the two are tuned independently. `coin_value` is per-archetype
# data; `coin_scene` is delivered in PRD-06 — until then the hook is a no-op.
@export var coin_value: int = 0
@export var coin_scene: PackedScene

var is_dead: bool = false

@onready var shoot_timer: Timer = Timer.new()
@onready var _body: Sprite2D = get_node_or_null("Body")

func _ready() -> void:
	if projectile_scene:
		add_child(shoot_timer)
		shoot_timer.wait_time = fire_rate
		shoot_timer.timeout.connect(_on_shoot_timer_timeout)
		shoot_timer.start()

func _physics_process(delta: float) -> void:
	global_position.y += speed * delta

func _on_shoot_timer_timeout() -> void:
	if projectile_scene:
		var bullet = projectile_scene.instantiate()
		get_parent().add_child(bullet)
		# Spawn offset slightly down
		bullet.global_position = global_position + Vector2(0, 30)
		# EnemyBullet handles its own movement (downwards)

func _on_area_entered(area: Area2D) -> void:
	# Assume mask 2 ensures only PlayerProjectile hits this.
	take_damage(1)

	# Destroy Bullet
	area.queue_free()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	_flash_hit()
	hp -= amount
	if hp <= 0:
		is_dead = true
		die()

func _flash_hit() -> void:
	if not _body: return
	var t = create_tween()
	t.tween_property(_body, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.0)
	t.tween_property(_body, "modulate", Color.WHITE, 0.15)

func die() -> void:
	drop_loot()
	drop_coins()
	spawn_explosion()
	GameManager.add_score(score_value)
	if destroyed_texture and _body:
		_body.texture = destroyed_texture
		shoot_timer.stop()
		await get_tree().create_timer(0.25).timeout
		if is_instance_valid(self): queue_free()
	else:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if is_dead: return
	if body.has_method("take_damage"):
		body.take_damage(1)
		spawn_explosion()
		queue_free()

func spawn_explosion() -> void:
	if explosion_scene:
		var expl = explosion_scene.instantiate()
		expl.global_position = global_position
		get_parent().add_child(expl)

func drop_loot() -> void:
	# The 22%-drop / half-rate-bomb rule now lives in the pure EnemyLoot helper;
	# the node just rolls the dice and spawns the result.
	var pickup_scene := EnemyLoot.loot_roll(loot_pool, randf(), randf(), randf())
	if pickup_scene == null:
		return
	var pickup = pickup_scene.instantiate()
	pickup.global_position = global_position
	get_parent().call_deferred("add_child", pickup)

# PRD-05 coin-drop hook. The coin pickup scene arrives in PRD-06; until then
# `coin_scene` is unset and this is a no-op. Kept separate from drop_loot so the
# currency source and the power-up pool tune independently.
func drop_coins() -> void:
	if coin_scene == null or coin_value <= 0:
		return
	var coin = coin_scene.instantiate()
	if "coin_value" in coin:
		coin.coin_value = coin_value
	coin.global_position = global_position
	get_parent().call_deferred("add_child", coin)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
