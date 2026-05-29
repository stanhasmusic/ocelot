extends GutTest

# Asserts the stage intro player's pure scheduling (PRD-04): which authored events
# are due at elapsed `t`, and when an intro is considered finished. Driving this
# off plain time arrays keeps the firing order/edge timing deterministic without a
# running `_process`, a frame budget, or scene instantiation.

const TIMES: Array[float] = [0.5, 1.0, 1.0, 2.5]  # pre-sorted, with a tie at 1.0


# --- due_count ------------------------------------------------------------

func test_nothing_is_due_before_the_first_event() -> void:
	assert_eq(IntroSchedule.due_count(TIMES, 0, 0.25), 0)


func test_event_is_due_at_its_exact_timestamp() -> void:
	assert_eq(IntroSchedule.due_count(TIMES, 0, 0.5), 1, "at/after the timestamp counts")


func test_a_long_frame_reports_every_spanned_event() -> void:
	# A single slow frame jumping to 1.2s must fire 0.5, 1.0 and 1.0 — none skipped.
	assert_eq(IntroSchedule.due_count(TIMES, 0, 1.2), 3)


func test_due_count_advances_from_next_index() -> void:
	# Having already fired the first two, only the tied 1.0 remains due at 1.0.
	assert_eq(IntroSchedule.due_count(TIMES, 2, 1.0), 1)


func test_all_events_due_once_clock_passes_the_last() -> void:
	assert_eq(IntroSchedule.due_count(TIMES, 0, 99.0), TIMES.size())


func test_nothing_due_once_all_consumed() -> void:
	assert_eq(IntroSchedule.due_count(TIMES, TIMES.size(), 99.0), 0)


# --- finish_time ----------------------------------------------------------

func test_finish_is_last_event_plus_tail_pad() -> void:
	assert_almost_eq(IntroSchedule.finish_time(TIMES, 0.5), 3.0, 0.0001)


func test_empty_timeline_finishes_after_the_tail_pad() -> void:
	var empty: Array[float] = []
	assert_almost_eq(IntroSchedule.finish_time(empty, 0.5), 0.5, 0.0001)
