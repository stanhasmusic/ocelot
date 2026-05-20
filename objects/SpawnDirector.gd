class_name SpawnDirector
extends Node

signal boss_threshold_reached

const SPAWN_WIDTH_OFFSET: float = 200.0
const AIMED_KEYWORDS: Array[String] = ["Tank", "Ship"]

var _config: StageConfig = null
var _stage_root: Node = null
var _timer: Timer = null
var _stage_start_score: int = 0
var _last_aimed_spawn_time: float = -INF
var _active_enemies: int = 0
var _boss_triggered: bool = false


func start(config: StageConfig, stage_root: Node) -> void:
	_config = config
	_stage_root = stage_root
	_stage_start_score = GameManager.spawn_score
	_last_aimed_spawn_time = -INF
	_active_enemies = 0
	_boss_triggered = false
	GameManager.on_spawn_score_updated.connect(_on_score_updated)
	_timer = Timer.new()
	_timer.wait_time = config.spawn_interval_start
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_timer.start()


func stop() -> void:
	if GameManager.on_spawn_score_updated.is_connected(_on_score_updated):
		GameManager.on_spawn_score_updated.disconnect(_on_score_updated)
	if _timer:
		_timer.stop()
		_timer.queue_free()
		_timer = null
	_config = null
	_stage_root = null


func _on_score_updated(score: int) -> void:
	if _config == null or _boss_triggered:
		return
	var stage_score: int = score - _stage_start_score
	if stage_score >= _config.boss_score_threshold:
		_boss_triggered = true
		boss_threshold_reached.emit()
		return
	var t: float = clampf(float(stage_score) / float(_config.boss_score_threshold), 0.0, 1.0)
	if _timer:
		_timer.wait_time = lerpf(_config.spawn_interval_start, _config.spawn_interval_end, t)


func _on_timer_timeout() -> void:
	if _config == null or _stage_root == null or _boss_triggered:
		return
	if _active_enemies >= _config.max_concurrent_enemies:
		return
	var scene: PackedScene = _pick_weighted()
	if scene == null:
		return
	if _config.min_gap_between_aimed_shots > 0.0 and _is_aimed_scene(scene):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_aimed_spawn_time < _config.min_gap_between_aimed_shots:
			return
		_last_aimed_spawn_time = now
	_spawn(scene)


func _spawn(scene: PackedScene) -> void:
	var enemy: Node = scene.instantiate()
	var parent_x: float = get_parent().global_position.x
	var spawn_x: float = parent_x + randf_range(-SPAWN_WIDTH_OFFSET, SPAWN_WIDTH_OFFSET)
	var spawn_y: float = get_parent().global_position.y
	enemy.global_position = Vector2(spawn_x, spawn_y)
	_active_enemies += 1
	enemy.tree_exited.connect(func(): _active_enemies -= 1)
	_stage_root.add_child(enemy)


func _pick_weighted() -> PackedScene:
	if _config.enemy_scenes.is_empty():
		return null
	var total: float = 0.0
	for w: float in _config.enemy_weights:
		total += w
	if total <= 0.0:
		return _config.enemy_scenes.pick_random()
	var r: float = randf() * total
	var cumulative: float = 0.0
	for i: int in _config.enemy_scenes.size():
		var w: float = _config.enemy_weights[i] if i < _config.enemy_weights.size() else 1.0
		cumulative += w
		if r <= cumulative:
			return _config.enemy_scenes[i]
	return _config.enemy_scenes[-1]


func _is_aimed_scene(scene: PackedScene) -> bool:
	var path: String = scene.resource_path
	for keyword: String in AIMED_KEYWORDS:
		if keyword in path:
			return true
	return false
