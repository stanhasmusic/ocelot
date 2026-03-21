extends "res://actors/Enemy.gd"

@export var bullet_scene: PackedScene

@export var shoot_range: float = 600.0

@onready var turret: Sprite2D = $Turret
# shoot_timer is inherited from Enemy.gd
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound

var player: Node2D

func _ready() -> void:
	# Clean up the timer created by Enemy.gd since we use the node in the scene
	if shoot_timer:
		shoot_timer.free()
	shoot_timer = $ShootTimer
	
	shoot_timer.wait_time = fire_rate
	shoot_timer.start()
	
	# Try to find player
	player = get_tree().get_first_node_in_group("Player")

func _physics_process(delta: float) -> void:
	# Basic movement from Enemy.gd
	super._physics_process(delta)
	
	# Turret Tracking
	if is_instance_valid(player):
		var dir = global_position.direction_to(player.global_position)
		# Assuming the Gun sprite points UP by default.
		# look_at aligns the node's +X axis with the target.
		# If sprite is UP (+Y is down in Godot, but Sprite UP is usually -Y local), 
		# We want the sprite's UP to face the player.
		# simpler: get angle, add 90 degrees (PI/2) if sprite points UP
		turret.global_rotation = dir.angle() + PI/2

func _on_shoot_timer_timeout() -> void:
	if is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= shoot_range:
			shoot()

func shoot() -> void:
	if bullet_scene:
		var b = bullet_scene.instantiate()
		
		# Bullet usually moves in its +X direction or +Y?
		# EnemyBullet.gd:
		#	func _physics_process(delta):
		#		position += transform.x * speed * delta (Standard)
		#       OR position.y += speed * delta (Vertical only)
		
		# Let's check EnemyBullet.gd to be sure how it moves!
		
		get_parent().add_child(b)
		
		# Spawning at Tip
		var direction = Vector2.UP.rotated(turret.global_rotation)
		b.global_position = turret.global_position + (direction * 40)
		
		# If bullet moves by its rotation, we set rotation.
		# If bullet moves down strictly, this won't work well for a turret.
		# We likely need a "TrackingBullet" or set the EnemyBullet direction.
		
		# Assuming standard bullet behavior (moves along forward vector)
		b.rotation = turret.global_rotation
		# Actually, let's verify EnemyBullet.gd first before finalizing this logic.
		
		if shoot_sound:
			shoot_sound.play()
