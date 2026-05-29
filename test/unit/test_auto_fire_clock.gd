extends GutTest

const INTERVAL := 0.15

func _new_clock() -> AutoFireClock:
	return AutoFireClock.new(INTERVAL)

func test_no_volley_before_interval_elapses() -> void:
	var clock := _new_clock()
	assert_eq(clock.tick(INTERVAL * 0.5), 0, "no volley below interval")
	assert_eq(clock.tick(INTERVAL * 0.3), 0, "still no volley below interval after second tick")

func test_exactly_one_volley_at_interval() -> void:
	var clock := _new_clock()
	assert_eq(clock.tick(INTERVAL), 1, "single volley when delta == interval")

func test_long_delta_spans_multiple_intervals() -> void:
	var clock := _new_clock()
	# 3.5 intervals -> 3 volleys, 0.5 interval carried.
	var volleys := clock.tick(INTERVAL * 3.5)
	assert_eq(volleys, 3, "three volleys for 3.5x interval")
	# Next tick of 0.5 interval should now complete the fourth volley.
	var next_volleys := clock.tick(INTERVAL * 0.5)
	assert_eq(next_volleys, 1, "carry completes the next volley")

func test_remainder_carries_across_sub_interval_frames() -> void:
	var clock := _new_clock()
	var total := 0
	# Ten small frames, each 0.05 interval, summing to 0.5 interval.
	for i in 10:
		total += clock.tick(INTERVAL * 0.05)
	# Expect exactly 0 volleys so far (we've only accumulated half an interval).
	assert_eq(total, 0, "no volleys until accumulator reaches interval")
	# Ten more small frames -> total is now 1.0 interval -> exactly one volley.
	for i in 10:
		total += clock.tick(INTERVAL * 0.05)
	assert_eq(total, 1, "one volley after enough sub-interval frames accumulate")

func test_disabled_when_interval_non_positive() -> void:
	var clock := AutoFireClock.new(0.0)
	assert_eq(clock.tick(1.0), 0, "zero interval is disabled")
	clock.fire_interval = -1.0
	assert_eq(clock.tick(1.0), 0, "negative interval is disabled")

func test_reset_clears_accumulator() -> void:
	var clock := _new_clock()
	clock.tick(INTERVAL * 0.9)
	clock.reset()
	assert_eq(clock.tick(INTERVAL * 0.5), 0, "after reset, half interval is still below threshold")
