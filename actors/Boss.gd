extends Area2D



@export var max_hp: int = 50
@export var speed: float = 1.5      # Speed of sine wave
@export var magnitude: float = 2.0  # Horizontal movement range multiplier
@export var vertical_speed: float = 20.0 # Slow descent

@export var bullet_scene: PackedScene
@export var explosion_scene: PackedScene

var current_hp: int
var time_alive: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	GameManager.report_boss_spawned(max_hp)

func _on_area_entered(area: Area2D) -> void:
	# Assume mask 2 (PlayerProjectile) is the only thing hitting us in this way
	take_damage(1)
	area.queue_free()

func _physics_process(delta: float) -> void:

	time_alive += delta
	
	# Move down slowly
	position.y += vertical_speed * delta
	
	# Sine wave movement
	position.x += sin(time_alive * speed) * magnitude

func take_damage(amount: int) -> void:
	current_hp -= amount
	GameManager.report_boss_health(current_hp, max_hp)
	
	if current_hp <= 0:
		die()

func die() -> void:
	GameManager.report_boss_died()
	GameManager.add_score(5000) # Big points for boss
	
	# Big Explosion Effect (Spawn multiple)
	if explosion_scene:
		for i in range(5):
			var expl = explosion_scene.instantiate()
			get_parent().add_child(expl)
			expl.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			
	queue_free()

func _on_shoot_timer_timeout() -> void:
	if bullet_scene:
		var b = bullet_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = $Muzzle.global_position
