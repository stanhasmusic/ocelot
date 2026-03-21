extends "res://actors/Enemy.gd"

@onready var path_follow: PathFollow2D = get_parent() as PathFollow2D

var turret_sprite: Sprite2D

# Use the directional bullet for the turret
var turret_bullet_scene = preload("res://objects/TurretBullet.tscn")

func _ready() -> void:
	turret_sprite = get_node_or_null("TurretSprite")
	
	if turret_sprite:
		# Set our custom projectile for the Enemy.gd logic (though we override shooting anyway)
		projectile_scene = turret_bullet_scene
	
	super._ready() # Initialize timer

func _physics_process(delta: float) -> void:
	# Movement
	if path_follow:
		path_follow.progress += speed * delta
	else:
		super._physics_process(delta)
	
	# Turret Aiming
	aim_turret()

func aim_turret() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and turret_sprite:
		turret_sprite.look_at(player.global_position)
		# Assuming sprite points RIGHT by default.
		# If sprite points UP, we need to adjust rotation by -90 deg (-PI/2)
		# tank1_dualgun.png seems to face UP in the sheet?
		# Checked ground_units.png... usually top-down sprites face UP.
		# If look_at aligns +X (Right) to target, and sprite faces UP (+Y in texture space? No -Y is up in Godot but texture is usually drawn UP).
		# Let's adjust + 90 degrees if it looks wrong.
		# Actually usually easier to just `rotation += PI/2`.
		turret_sprite.rotation += PI / 2

func _on_shoot_timer_timeout() -> void:
	if !projectile_scene: return
	
	var bullet = projectile_scene.instantiate()
	get_parent().add_child(bullet) # Add to same container (Level)
	
	# Spawn at Turret position
	bullet.global_position = turret_sprite.global_position
	
	# Align bullet with Turret rotation
	# Note: Turret rotation is adjusted for sprite, so true "aim" is turret_sprite.global_rotation - correction?
	# Or just `look_at` target again for bullet?
	# Simpler:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		bullet.look_at(player.global_position)
	else:
		# Fallback to turret rotation (corrected)
		bullet.global_rotation = turret_sprite.global_rotation - PI/2
