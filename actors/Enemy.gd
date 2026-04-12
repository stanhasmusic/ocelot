extends Area2D

@export var speed: float = 150.0
@export var score_value: int = 100
@export var explosion_scene: PackedScene
@export var loot_pool: Array[PackedScene] = []
@export var projectile_scene: PackedScene
@export var fire_rate: float = 2.0
@export var destroyed_texture: Texture2D

@onready var shoot_timer: Timer = Timer.new()
@onready var _body: Sprite2D = $Body

@export var hp: int = 1
var is_dead: bool = false

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
	if loot_pool.is_empty() or randf() >= 0.22:
		return
	var pickup_scene = loot_pool.pick_random()
	# Bombs get an extra 50% filter to roughly halve their drop rate
	if "Bomb" in pickup_scene.resource_path and randf() >= 0.5:
		return
	var pickup = pickup_scene.instantiate()
	pickup.global_position = global_position
	get_parent().call_deferred("add_child", pickup)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
