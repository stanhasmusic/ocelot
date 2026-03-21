extends "res://actors/Enemy.gd"

@export var shoot_range: float = 500.0

@onready var turret: Sprite2D = $Turret

@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var body_sprite: Sprite2D = $Sprite2D

var player: Node2D

func _ready() -> void:
	# Parent creates shoot_timer based on fire_rate.
	# We want to override using our fire_rate.
	fire_rate = 1.5 # Reset default if needed, or rely on export
	super._ready() # Parent adds the timer and sets wait_time = fire_rate
	
	# If we want to ensure it uses the parent's timer logic:
	if shoot_timer:
		shoot_timer.timeout.disconnect(_on_shoot_timer_timeout) # Disconnect parent's listener?
		shoot_timer.timeout.connect(_on_shoot_timer_timeout) # Reconnect to ours?
		# Actually, overriden function _on_shoot_timer_timeout is called automatically if connected.
		# But parent connects it in its _ready.
		pass
		
	player = get_tree().get_first_node_in_group("Player")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if is_instance_valid(player):
		var dir = global_position.direction_to(player.global_position)
		# Turret tracking
		turret.global_rotation = dir.angle() + PI/2 + PI

func _on_shoot_timer_timeout() -> void:
	if is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= shoot_range:
			shoot()

func shoot() -> void:
	if projectile_scene:
		var b = projectile_scene.instantiate()
		get_parent().add_child(b)
		
		# Spawn at Turret tip (approx 20px off center)
		# NOTE: Turret is visually rotated 180 degrees offset from vector to player.
		# So "Down" (relative to turret) is towards player.
		var direction = Vector2.UP.rotated(turret.global_rotation + PI)
		b.global_position = turret.global_position + (direction * 20)
		b.rotation = turret.global_rotation + PI
		
		if shoot_sound:
			shoot_sound.play()

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	# Check HP for damage visual?
	# We only have 3 HP usually.
	# Let's just flash white for now (handled by shader usually, or we can mod color)
	
	# If we want to switch to destroyed sprite on death, Enemy.gd handles die().
	# But maybe we want a "damaged" state?
	pass
