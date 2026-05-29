class_name IntroSchedule
extends RefCounted

# Pure scheduling logic for the stage intro player (PRD-04).
#
# `StageIntroPlayer` drives an authored timeline off an accumulating `_process`
# clock. The decision "which events are due at elapsed t" is pure and worth
# asserting without `_process`, a real frame budget, or scene instantiation, so
# it lives here. The player keeps the clock and the node spawning; this module
# answers how many events are due and when the timeline finishes.
#
# Times are expected pre-sorted ascending (the player sorts the timeline once).


# How many events, starting at `next_index`, are due at `now_elapsed` — i.e. have
# a timestamp at or before the current clock. A single long frame that spans
# several events reports all of them, so none are skipped or fired twice.
static func due_count(sorted_times: Array[float], next_index: int, now_elapsed: float) -> int:
	var count: int = 0
	var i: int = next_index
	while i < sorted_times.size() and sorted_times[i] <= now_elapsed:
		count += 1
		i += 1
	return count


# When the intro is considered finished: the last event's time plus the tail pad,
# or just the tail pad for an empty timeline (so an intro-less stage still waits
# the pad before the body begins).
static func finish_time(sorted_times: Array[float], tail_pad: float) -> float:
	if sorted_times.is_empty():
		return tail_pad
	return sorted_times[-1] + tail_pad
