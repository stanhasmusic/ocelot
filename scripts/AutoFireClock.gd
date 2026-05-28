class_name AutoFireClock
extends RefCounted

# Accumulates delta-time and emits one volley per `fire_interval`. A single long
# tick that spans multiple intervals returns the matching count (>1) and carries
# the leftover remainder so cadence stays accurate across many small frames.
# `fire_interval <= 0` is treated as disabled (no volleys).

var fire_interval: float
var _accum: float = 0.0

func _init(interval: float = 0.15) -> void:
	fire_interval = interval

func tick(delta: float) -> int:
	if fire_interval <= 0.0:
		return 0
	_accum += max(delta, 0.0)
	if _accum < fire_interval:
		return 0
	var volleys: int = int(_accum / fire_interval)
	_accum -= float(volleys) * fire_interval
	return volleys

func reset() -> void:
	_accum = 0.0
