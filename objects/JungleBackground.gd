extends Node2D

@export var scroll_speed: float = 100.0

var ground_atlas = preload("res://assets/sprites/ground_tilesest/ground.png")
var tree_textures: Array = [
	preload("res://assets/sprites/trees/tree_01.png"),
	preload("res://assets/sprites/trees/tree_02.png"),
	preload("res://assets/sprites/trees/tree_03.png"),
	preload("res://assets/sprites/trees/tree_04.png"),
	preload("res://assets/sprites/trees/tree_05.png"),
	preload("res://assets/sprites/trees/tree_06.png"),
	preload("res://assets/sprites/trees/tree_07.png"),
	preload("res://assets/sprites/trees/tree_08.png"),
]

const TILE_SIZE = 128
const COLUMNS = 5
const SCREEN_H: float = 960.0
const GRASS_TILE = Rect2(0, 128, 128, 128)
const TREE_CHANCE = 0.20

var active_rows: Array[Node2D] = []

func _ready() -> void:
	var y = -200.0
	while y <= SCREEN_H + TILE_SIZE:
		_spawn_row(y)
		y += TILE_SIZE - 2

func _process(delta: float) -> void:
	for row in active_rows:
		row.position.y += scroll_speed * delta
	if not active_rows.is_empty():
		var top = active_rows[0]
		if top.position.y > -TILE_SIZE + TILE_SIZE * 0.1:
			_spawn_row(top.position.y - (TILE_SIZE - 2))
	if not active_rows.is_empty():
		var bot = active_rows[active_rows.size() - 1]
		if bot.position.y > SCREEN_H + TILE_SIZE:
			active_rows.pop_back()
			bot.queue_free()

func _spawn_row(visual_y: float) -> void:
	var row = Node2D.new()
	row.position.y = visual_y
	add_child(row)
	move_child(row, 0)
	active_rows.insert(0, row)
	_generate_row(row)

func _generate_row(row: Node2D) -> void:
	for col in range(COLUMNS):
		var x_pos = col * TILE_SIZE - 50
		var ground = Sprite2D.new()
		ground.texture = ground_atlas
		ground.region_enabled = true
		ground.region_rect = GRASS_TILE
		ground.centered = false
		ground.position.x = x_pos
		row.add_child(ground)
		if randf() < TREE_CHANCE:
			var tree = Sprite2D.new()
			tree.texture = tree_textures.pick_random()
			tree.position = Vector2(x_pos + randf_range(20, 108), randf_range(20, 108))
			tree.scale = Vector2.ONE * randf_range(0.9, 1.4)
			row.add_child(tree)
