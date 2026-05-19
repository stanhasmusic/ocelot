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
@export var boss_hp: int = 50
@export var boss_score_threshold: int = 3500
