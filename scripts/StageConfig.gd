class_name StageConfig
extends Resource

@export var intro_timeline: Resource = null
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_weights: Array[float] = []
@export var spawn_interval_start: float = 1.5
@export var spawn_interval_end: float = 0.5
@export var max_concurrent_enemies: int = 6
@export var min_gap_between_aimed_shots: float = 0.0
@export var projectile_speed_mult: float = 1.0
@export var boss_scene: PackedScene
@export var boss_score_threshold: int = 3500

# Feel knobs lifted out of code (PRD-04). Defaults equal the previous hard-coded
# values so existing stages play identically until deliberately retuned.
@export var spawn_width_offset: float = 200.0
@export var boss_spawn_position: Vector2 = Vector2(270, -100)
@export var intro_tail_pad_seconds: float = 0.5
