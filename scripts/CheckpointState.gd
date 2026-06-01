class_name CheckpointState
extends RefCounted

# Tracks the furthest *safe resume point* reached during a run (PRD-02).
#
# A resume point is a stage index plus a within-stage marker (STAGE_START before
# the scripted intro, POST_INTRO once the procedural body begins). On player
# death with lives remaining, respawn logic consults `resume_point()` so a long
# level resumes at the last checkpoint instead of the start.
#
# The point is **monotonic** — recording an earlier stage/marker never moves the
# player backward. Pure logic: no node/scene dependencies; safe to unit-test.
# In-memory for the current run only; cross-restart persistence is PRD-07.

enum Marker { STAGE_START, POST_INTRO }

var _stage_index: int = 0
var _marker: int = Marker.STAGE_START


func record(stage_index: int, marker: int = Marker.STAGE_START) -> void:
	if stage_index > _stage_index or (stage_index == _stage_index and marker > _marker):
		_stage_index = stage_index
		_marker = marker


func resume_point() -> Dictionary:
	return {"stage_index": _stage_index, "marker": _marker}


func reset() -> void:
	_stage_index = 0
	_marker = Marker.STAGE_START


# Flatten to a plain Dictionary for the save file (PRD-07). Inverse of
# `deserialize`; pure data, no side effects.
func serialize() -> Dictionary:
	return {"stage_index": _stage_index, "marker": _marker}


# Restore from a `serialize()` payload. Tolerates missing/partial data by
# falling back to the origin, so a malformed or empty save never crashes.
func deserialize(data: Dictionary) -> void:
	_stage_index = int(data.get("stage_index", 0))
	_marker = int(data.get("marker", Marker.STAGE_START))
