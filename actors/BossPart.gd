class_name BossPart
extends Area2D

# A single boss part (PRD-12): own hitbox, own HP, own destroyed art. The
# reusable unit a Boss is built from — a weak-point, or the one part flagged
# `is_core`. A mini-boss is one part flagged core. On a player-projectile hit it
# routes damage to the owning Boss, which consults BossState's gate before
# applying, so an un-exposed core shrugs the hit off. Fire timing/telegraph is
# owned by the Boss; this node just carries the part's fire config as data and
# swaps to destroyed art when killed.
#
# Lives in the "Enemies" group (like every other target) so the bomb AoE reaches
# it; the Boss caps incoming damage so a bomb can't one-shot a part.

@export var max_hp: int = 12
@export var armor: int = 0  # reserved (PRD-10 makes it bite); inert this PRD
@export var is_core: bool = false

@export_group("Fire")
@export var bullet_scene: PackedScene
## Seconds between volleys. <= 0 means this part never fires (e.g. an inert core).
@export var fire_interval: float = 1.4
## Visible wind-up lead before each volley actually fires. Generous = readable.
@export var telegraph_seconds: float = 0.9
@export var shot_count: int = 1
## Total fan width in radians, spread symmetrically about the base direction.
@export var spread_arc: float = 0.0
## Aim the fan at the player instead of straight down.
@export var aimed: bool = false

@export_group("Art")
## Body sprite at spawn. Set on the instance so a part can be reskinned without
## editing the BossPart.tscn template's nested Sprite2D.
@export var body_texture: Texture2D
@export var destroyed_texture: Texture2D

var current_hp: int
var is_destroyed: bool = false

var _boss: Node = null

@onready var _body: Sprite2D = get_node_or_null("Body")
@onready var _muzzle: Marker2D = get_node_or_null("Muzzle")


func _ready() -> void:
	current_hp = maxi(max_hp, 1)
	if _body and body_texture:
		_body.texture = body_texture
	area_entered.connect(_on_area_entered)


# The owning Boss registers itself so part hits can be routed through the gate.
func bind_boss(boss: Node) -> void:
	_boss = boss


func muzzle_position() -> Vector2:
	return _muzzle.global_position if _muzzle else global_position


# A player projectile (mask 2) overlapped us. Route the hit through the Boss so
# the core gate decides whether it lands, then free the projectile either way.
func _on_area_entered(area: Area2D) -> void:
	take_damage(1)
	area.queue_free()


# Bomb-AoE compatible entry point (Player.detonate_bomb calls take_damage on the
# "Enemies" group). All damage goes through the Boss → BossState gate.
func take_damage(amount: int) -> void:
	if _boss and _boss.has_method("route_damage"):
		_boss.route_damage(name, amount)


# Called back by the Boss after BossState confirms a hit landed.
func on_damaged(new_hp: int) -> void:
	current_hp = new_hp
	_flash_hit()


# Called back by the Boss when BossState reports this part destroyed.
func on_destroyed() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	current_hp = 0
	if destroyed_texture and _body:
		_body.texture = destroyed_texture
	# Stop being a hitbox once dead so the wreck doesn't soak shots.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _flash_hit() -> void:
	if not _body:
		return
	var t := create_tween()
	t.tween_property(_body, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.0)
	t.tween_property(_body, "modulate", Color.WHITE, 0.15)
