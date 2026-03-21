extends Node2D

@export var scroll_speed: float = 100.0
@export var train_speed: float = 150.0

@onready var path_2d: Path2D = $Path2D

var train_engine_scene = preload("res://actors/Train.tscn")
var train_car_scene = preload("res://actors/TrainCar.tscn")

const CAR_LENGTH = 190.0
const GAP = 10.0
const BUFFER_DISTANCE = 2500.0 # Extend path starts way above screen

# Track pieces definition: {region: Rect2, height: float}
# Coordinates from train.json
const TRACK_PIECES = [
	{"region": Rect2(68, 230, 64, 16), "height": 16.0}, # track_01
	{"region": Rect2(68, 212, 64, 16), "height": 16.0}, # track_02
	{"region": Rect2(68, 194, 64, 16), "height": 16.0}, # track_03
	{"region": Rect2(2, 228, 64, 16), "height": 16.0},  # track_04
	{"region": Rect2(2, 194, 64, 32), "height": 32.0}   # track_05
]

@export var texture_atlas: Texture2D # Assign in editor or load default

func _ready() -> void:
	if not texture_atlas:
		texture_atlas = preload("res://assets/sprites/Train/train.png")
	
	generate_track_visuals()
	spawn_train()

func generate_track_visuals() -> void:
	# Track spans from y = -3000 to y = 600 (based on Curve2D)
	var current_y = -3000.0
	var end_y = 600.0
	
	# Create a container for visuals if it doesn't exist (though we'll probably add it in scene)
	var visuals_container = Node2D.new()
	visuals_container.name = "TrackVisuals"
	add_child(visuals_container)
	move_child(visuals_container, 0) # Ensure it's behind everything (like the Line2D was)
	
	while current_y < end_y:
		var piece_def = TRACK_PIECES.pick_random()
		
		var sprite = Sprite2D.new()
		sprite.texture = texture_atlas
		sprite.region_enabled = true
		sprite.region_rect = piece_def["region"]
		
		# Position: Sprites are centered.
		# x = 0 (center of track)
		# y = current_y + half height
		sprite.position = Vector2(0, current_y + piece_def["height"] / 2.0)
		
		visuals_container.add_child(sprite)
		
		current_y += piece_def["height"]

func spawn_train() -> void:
	var num_cars = randi_range(3, 7)
	# Start engine effectively at the "visible start" of the track (0, -500 in old coords)
	# In new coords, this is at progress = BUFFER_DISTANCE
	var start_progress = BUFFER_DISTANCE 
	
	# Spawn Engine
	create_train_unit(train_engine_scene, start_progress)
	
	# Spawn Cars behind
	for i in range(num_cars):
		var offset = - (i + 1) * (CAR_LENGTH + GAP)
		create_train_unit(train_car_scene, start_progress + offset)

func create_train_unit(scene: PackedScene, initial_progress: float) -> void:
	var follower = PathFollow2D.new()
	path_2d.add_child(follower)
	follower.rotates = true
	follower.loop = false
	follower.progress = initial_progress
	
	var unit = scene.instantiate()
	follower.add_child(unit)
	unit.rotation = 0 # unit sprite is already rotated in scene if needed, or 0 relative to follower
	
	# Ensure unit knows its speed if it handles its own movement,
	# OR we handle movement here?
	# Currently Train.gd handles movement: `path_follow.progress += speed * delta`
	# We must ensure they all have the same speed.
	if unit.get("speed"):
		unit.speed = train_speed

func _physics_process(delta: float) -> void:
	# Move the entire track system DOwN (world scroll)
	position.y += scroll_speed * delta
	
	# Cleanup
	if global_position.y > 3000: # Increased buffer since train might be long
		queue_free()
