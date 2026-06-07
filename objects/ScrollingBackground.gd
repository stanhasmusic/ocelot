extends CanvasLayer

const VIEWPORT_WIDTH: float = 540.0
const VIEWPORT_HEIGHT: float = 960.0

@export var level_background: LevelBackground

var _stage_index: int = 0
var _boss_mode: bool = false
var _scroll_offset: float = 0.0
var _scroll_speed: float = 100.0

@onready var _strip: TextureRect = $Strip
@onready var _arena: TextureRect = $Arena


func _ready() -> void:
	layer = -100
	_arena.visible = false
	if level_background and level_background.boss_arena_texture:
		_arena.texture = level_background.boss_arena_texture
	GameManager.on_boss_spawned.connect(_on_boss_spawned)
	GameManager.on_boss_died.connect(_on_boss_died)
	var node: Node = get_parent()
	while node != null and not node.has_signal("stage_started"):
		node = node.get_parent()
	if node != null:
		node.stage_started.connect(set_stage)
	set_stage(0)


func set_stage(stage_index: int) -> void:
	_stage_index = stage_index
	_boss_mode = false
	_arena.visible = false
	_strip.visible = true
	_scroll_offset = 0.0
	var sb := _get_stage_background(stage_index)
	if sb == null:
		return
	_strip.texture = sb.strip_texture
	_scroll_speed = sb.scroll_speed
	_update_strip_position()


func _get_stage_background(idx: int) -> StageBackground:
	if level_background == null:
		return null
	var arr := level_background.stage_backgrounds
	if arr.is_empty():
		return null
	if idx >= arr.size():
		push_warning("ScrollingBackground: fewer stage_backgrounds than stages; reusing last.")
		return arr[arr.size() - 1]
	return arr[idx]


func _process(delta: float) -> void:
	if _boss_mode or _strip.texture == null:
		return
	var max_offset: float = _max_scroll_offset()
	if _scroll_offset < max_offset:
		_scroll_offset = min(max_offset, _scroll_offset + _scroll_speed * delta)
		_update_strip_position()


func _max_scroll_offset() -> float:
	if _strip.texture == null:
		return 0.0
	return max(0.0, _strip.texture.get_height() - VIEWPORT_HEIGHT)


# The strip starts with its BOTTOM 960px on screen and pans up the image toward
# the top, so world content scrolls DOWNWARD on screen — the player flies "north"
# (same feel as MovingLandBackground). The strip parks on its TOP 960px: that
# final frame (e.g. the fortress shore) is the pre-boss / late-body backdrop.
func _update_strip_position() -> void:
	_strip.position = Vector2(0, _scroll_offset - _max_scroll_offset())


# Only the named boss (PRD-14) swaps to the arena; mini-bosses fight over the
# parked strip and leave the scrolling world in place. `is_named` defaults false
# so a mini-boss spawn just freezes the scroll without the arena cut.
func _on_boss_spawned(_max_hp: int, is_named: bool = false) -> void:
	_boss_mode = true
	if is_named and level_background and level_background.boss_arena_texture:
		_arena.texture = level_background.boss_arena_texture
		_arena.visible = true
		_strip.visible = false


func _on_boss_died() -> void:
	pass
