class_name SpawnDirector
extends Node

signal boss_threshold_reached

var _config: StageConfig = null
var _stage_root: Node = null
var _timer: Timer = null
var _stage_start_score: int = 0
var _last_aimed_spawn_time: float = -INF
var _active_enemies: int = 0
var _boss_triggered: bool = false
var _aimed_cache: Dictionary = {}


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
	if SpawnPlan.boss_should_fire(stage_score, _config.boss_score_threshold, _boss_triggered):
		_boss_triggered = true
		boss_threshold_reached.emit()
		return
	if _timer:
		_timer.wait_time = SpawnPlan.spawn_interval(
			_config.spawn_interval_start,
			_config.spawn_interval_end,
			stage_score,
			_config.boss_score_threshold
		)


func _on_timer_timeout() -> void:
	if _config == null or _stage_root == null or _boss_triggered:
		return
	if not SpawnPlan.can_spawn(_active_enemies, _config.max_concurrent_enemies):
		return
	var scene: PackedScene = _pick_weighted()
	if scene == null:
		return
	if _config.min_gap_between_aimed_shots > 0.0 and _is_aimed_scene(scene):
		var now: float = Time.get_ticks_msec() / 1000.0
		if SpawnPlan.aimed_blocked(now, _last_aimed_spawn_time, _config.min_gap_between_aimed_shots):
			scene = _pick_weighted_non_aimed()
			if scene == null:
				return
		else:
			_last_aimed_spawn_time = now
	_spawn(scene)


func _spawn(scene: PackedScene) -> void:
	var enemy: Node = scene.instantiate()
	var parent_x: float = get_parent().global_position.x
	var offset: float = _config.spawn_width_offset
	var spawn_x: float = parent_x + randf_range(-offset, offset)
	var spawn_y: float = get_parent().global_position.y
	enemy.global_position = Vector2(spawn_x, spawn_y)
	_active_enemies += 1
	enemy.tree_exited.connect(func(): _active_enemies -= 1)
	_stage_root.add_child(enemy)


func _aligned_weights(scenes: Array[PackedScene]) -> Array[float]:
	var weights: Array[float] = []
	for i: int in scenes.size():
		weights.append(_config.enemy_weights[i] if i < _config.enemy_weights.size() else 1.0)
	return weights


func _pick_weighted() -> PackedScene:
	if _config.enemy_scenes.is_empty():
		return null
	var idx: int = SpawnPlan.weighted_index(_aligned_weights(_config.enemy_scenes), randf())
	if idx < 0:
		return null
	return _config.enemy_scenes[idx]


func _pick_weighted_non_aimed() -> PackedScene:
	var non_aimed: Array[PackedScene] = []
	var weights: Array[float] = []
	var all_weights: Array[float] = _aligned_weights(_config.enemy_scenes)
	for i: int in _config.enemy_scenes.size():
		var s: PackedScene = _config.enemy_scenes[i]
		if not _is_aimed_scene(s):
			non_aimed.append(s)
			weights.append(all_weights[i])
	if non_aimed.is_empty():
		return null
	var idx: int = SpawnPlan.weighted_index(weights, randf())
	if idx < 0:
		return null
	return non_aimed[idx]


# Classify by the enemy's *declared* threat tier rather than its filename. The
# tier is read from the packed scene's root node without instantiating combat
# (PRD-05 sets the per-archetype value; default STRAIGHT = not aimed).
func _is_aimed_scene(scene: PackedScene) -> bool:
	if _aimed_cache.has(scene):
		return _aimed_cache[scene]
	var aimed: bool = SpawnPlan.tier_is_aimed(_scene_threat_tier(scene))
	_aimed_cache[scene] = aimed
	return aimed


func _scene_threat_tier(scene: PackedScene) -> int:
	if scene == null:
		return ThreatTier.Tier.STRAIGHT
	var state: SceneState = scene.get_state()
	if state == null or state.get_node_count() == 0:
		return ThreatTier.Tier.STRAIGHT
	for i: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == "primary_threat_tier":
			return int(state.get_node_property_value(0, i))
	return ThreatTier.Tier.STRAIGHT
