extends Area2D

@export var speed: float = 150.0
@export var score_value: int = 100
@export var explosion_scene: PackedScene
@export var powerup_scene: PackedScene
@export var projectile_scene: PackedScene
@export var fire_rate: float = 2.0

@onready var shoot_timer: Timer = Timer.new()

@export var hp: int = 1

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
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	drop_loot()
	spawn_explosion()
	GameManager.add_score(score_value)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
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
	if randf() < 0.3 and powerup_scene:
		var pickup = powerup_scene.instantiate()
		pickup.global_position = global_position
		get_parent().call_deferred("add_child", pickup)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
