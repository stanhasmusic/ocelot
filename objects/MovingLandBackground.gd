extends Node2D

@export var scroll_speed: float = 100.0

# Atlas Textures
var ground_atlas = preload("res://assets/sprites/ground_tilesest/ground.png")
var decor_atlas = preload("res://assets/sprites/ground_tilesest/decor.png")
var buildings_atlas = preload("res://assets/sprites/buildings/buildings.png")

# Regions (Approximate from JSONs, in a real app might parse JSON)
# Ground 128x128
const TILE_SIZE = 128
# Biome Constants
const BIOME_SAND = 0
const BIOME_GRASS = 1
var column_biomes: Array[int] = []

# Ground Regions Split
const SAND_REGIONS = [
	Rect2(0, 0, 128, 128), # Sand
	Rect2(0, 896, 128, 128) # beach_tm_03
]
const GRASS_REGIONS = [
	Rect2(0, 128, 128, 128), # Grass
	Rect2(2, 36, 128, 128), # Grass 02
	Rect2(238, 68, 128, 128) # Grass 01
]

# Roads (Vertical)
const ROAD_REGIONS = [
	Rect2(234, 532, 64, 128), # road_1
	Rect2(430, 608, 64, 128), # road_2
	Rect2(234, 402, 100, 128), # road_asphalt_clean_vert
	Rect2(132, 296, 100, 128)  # road_asphalt_damaged_to_clean_vert
]

# Decor (Rocks, bushes)
const DECOR_REGIONS = [
	Rect2(36, 936, 64, 64), # rock_1
	Rect2(36, 870, 64, 64), # rock_2
	Rect2(102, 820, 64, 64), # bush_1
	Rect2(368, 182, 128, 128) # bush_big
]

# Buildings
const BUILDING_REGIONS = [
	Rect2(276, 440, 120, 114), # house_1c
	Rect2(630, 478, 84, 80),   # house_1d
	Rect2(476, 320, 88, 91)    # house_2c
]

var active_rows: Array[Node2D] = []
var next_spawn_y: float = 0.0
var screen_height: float = 960.0 # Approx
var road_x_index: int = 2 # Column index for road (0-4)
const COLUMNS = 5 # Screen width approx 540 / 128 ~ 4.2. Let's say 5 columns of 128px = 640px wide covers it.

var noise: FastNoiseLite
var next_top_map_y: float = 0.0

func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.015 # Smooth patches
	
	# Fill screen + buffer. 
	# Start Top (-200) to Bottom. 
	# MapY aligns with visual Y initially.
	var y = -200.0
	while y <= screen_height + TILE_SIZE:
		spawn_row(y, y, false) # visual_y, map_y, at_top
		y += TILE_SIZE
	
	# The next row to spawn at Top will be at -200 - TILE_SIZE
	next_top_map_y = -200.0 - TILE_SIZE

func _process(delta: float) -> void:
	var move_amount = scroll_speed * delta
	for row in active_rows:
		row.position.y += move_amount
	
	if not active_rows.is_empty():
		var top_row = active_rows[0]
		if top_row.position.y > -TILE_SIZE + (TILE_SIZE * 0.1):
			spawn_row(top_row.position.y - TILE_SIZE, next_top_map_y, true)
			next_top_map_y -= TILE_SIZE # Move map pointer UP (Negative)

	if not active_rows.is_empty():
		var bottom_row = active_rows[active_rows.size() - 1]
		if bottom_row.position.y > screen_height + TILE_SIZE:
			active_rows.pop_back()
			bottom_row.queue_free()

func spawn_row(visual_y: float, map_y: float, at_top: bool = false) -> void:
	var row_node = Node2D.new()
	row_node.position.y = visual_y
	add_child(row_node)
	
	if at_top:
		move_child(row_node, 0)
		active_rows.insert(0, row_node)
	else:
		active_rows.append(row_node)
	
	generate_row_content(row_node, map_y)

func generate_row_content(row_node: Node2D, map_y: float) -> void:
	# Pass 1: Ground Tiles (Base Layer)
	for col in range(COLUMNS):
		var x_pos = (col * TILE_SIZE) - 50
		
		# Sample 2D Noise for continuous biome patches
		var noise_val = noise.get_noise_2d(x_pos, map_y)
		
		var sprite = Sprite2D.new()
		sprite.texture = ground_atlas
		sprite.region_enabled = true
		
		# Threshold: < 0 is Sand, > 0 is Grass (Balanced)
		# Or bias slightly: < 0.2
		if noise_val < 0.2:
			sprite.region_rect = SAND_REGIONS.pick_random()
		else:
			sprite.region_rect = GRASS_REGIONS.pick_random()
			
		sprite.centered = false
		sprite.position.x = x_pos
		row_node.add_child(sprite)

	# Pass 2: Objects (Roads, Decor, Buildings)
	for col in range(COLUMNS):
		var x_pos = (col * TILE_SIZE) - 50
		var is_road = (col == road_x_index)
		
		if is_road:
			var road = Sprite2D.new()
			road.texture = ground_atlas
			road.region_enabled = true
			road.region_rect = ROAD_REGIONS.pick_random()
			road.position = Vector2(x_pos + 64, 64) 
			row_node.add_child(road)
		else:
			if randf() < 0.2:
				spawn_decor(row_node, x_pos, 0)
			elif randf() < 0.05:
				spawn_building(row_node, x_pos, 0)

func spawn_decor(parent: Node, x: float, y_offset: float) -> void:
	var d = Sprite2D.new()
	d.texture = decor_atlas
	d.region_enabled = true
	d.region_rect = DECOR_REGIONS.pick_random()
	# Clamp to center area of tile to prevent clipping
	# Tile width 128. Sprite ~64.
	# Safe range roughly 32 to 96?
	d.position = Vector2(x + randf_range(32, 96), y_offset + randf_range(32, 96))
	parent.add_child(d)

func spawn_building(parent: Node, x: float, y_offset: float) -> void:
	var b = Sprite2D.new()
	b.texture = buildings_atlas
	b.region_enabled = true
	b.region_rect = BUILDING_REGIONS.pick_random()
	b.position = Vector2(x + 64, y_offset + 64)
	parent.add_child(b)
