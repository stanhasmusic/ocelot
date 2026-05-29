class_name StageIntroPlayer
extends Node

signal intro_finished

const TAIL_PAD_SECONDS: float = 0.5

var _timeline: StageIntroTimeline = null
var _stage_root: Node = null
var _sorted_events: Array[StageIntroEvent] = []
var _sorted_times: Array[float] = []
var _next_index: int = 0
var _elapsed: float = 0.0
var _playing: bool = false
var _finish_at: float = 0.0


func _ready() -> void:
	set_process(false)
	process_mode = Node.PROCESS_MODE_PAUSABLE


func play(
	timeline: StageIntroTimeline, stage_root: Node, tail_pad: float = TAIL_PAD_SECONDS
) -> void:
	cancel()
	if timeline == null or stage_root == null:
		intro_finished.emit()
		return
	_timeline = timeline
	_stage_root = stage_root
	_sorted_events.clear()
	for e in timeline.events:
		if e is StageIntroEvent:
			_sorted_events.append(e)
	_sorted_events.sort_custom(_compare_events)
	_sorted_times = []
	for e: StageIntroEvent in _sorted_events:
		_sorted_times.append(e.time)
	_next_index = 0
	_elapsed = 0.0
	_finish_at = IntroSchedule.finish_time(_sorted_times, tail_pad)
	_playing = true
	set_process(true)


func cancel() -> void:
	_playing = false
	set_process(false)
	_timeline = null
	_stage_root = null
	_sorted_events = []
	_sorted_times = []
	_next_index = 0
	_elapsed = 0.0


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	var due: int = IntroSchedule.due_count(_sorted_times, _next_index, _elapsed)
	for _i: int in due:
		_fire(_sorted_events[_next_index])
		_next_index += 1
	if _elapsed >= _finish_at:
		_playing = false
		set_process(false)
		_timeline = null
		_stage_root = null
		_sorted_events = []
		_sorted_times = []
		_next_index = 0
		_elapsed = 0.0
		intro_finished.emit()


static func _compare_events(a: StageIntroEvent, b: StageIntroEvent) -> bool:
	return a.time < b.time


func _fire(event: StageIntroEvent) -> void:
	if event.scene == null or _stage_root == null:
		return
	var instance: Node = event.scene.instantiate()
	if instance is Node2D:
		(instance as Node2D).global_position = event.spawn_position
	_stage_root.add_child(instance)
