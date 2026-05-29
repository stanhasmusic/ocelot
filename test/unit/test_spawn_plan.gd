extends GutTest

# Asserts the stage director's pure decisions (PRD-04). These are the spawn-table
# and pacing rules that used to be trusted to a 60-second playthrough — weighted
# selection, the score-driven interval ramp, the aimed-shot gap, the one-shot boss
# trigger, and the data-driven aimed classifier. External behaviour only: feed a
# known roll/score and assert the answer, never inspect private timers.


# --- weighted_index -------------------------------------------------------

func test_empty_weights_return_negative_one() -> void:
	var weights: Array[float] = []
	assert_eq(SpawnPlan.weighted_index(weights, 0.5), -1, "no scenes to pick from")


func test_equal_weights_partition_the_roll_evenly() -> void:
	var weights: Array[float] = [1.0, 1.0, 1.0, 1.0]
	# Four equal buckets across [0,1): each quarter selects the next index.
	assert_eq(SpawnPlan.weighted_index(weights, 0.0), 0)
	assert_eq(SpawnPlan.weighted_index(weights, 0.3), 1)
	assert_eq(SpawnPlan.weighted_index(weights, 0.6), 2)
	assert_eq(SpawnPlan.weighted_index(weights, 0.99), 3)


func test_skewed_weights_give_the_heavy_index_a_wider_slice() -> void:
	var weights: Array[float] = [1.0, 3.0]  # total 4: index 0 owns only [0, 0.25)
	assert_eq(SpawnPlan.weighted_index(weights, 0.2), 0)
	assert_eq(SpawnPlan.weighted_index(weights, 0.3), 1)
	assert_eq(SpawnPlan.weighted_index(weights, 0.9), 1)


func test_zero_total_weights_fall_back_to_uniform() -> void:
	# A mis-authored all-zero array must still spawn *something*, spread uniformly.
	var weights: Array[float] = [0.0, 0.0, 0.0]
	assert_eq(SpawnPlan.weighted_index(weights, 0.0), 0)
	assert_eq(SpawnPlan.weighted_index(weights, 0.5), 1)
	assert_eq(SpawnPlan.weighted_index(weights, 0.99), 2)


# --- spawn_interval -------------------------------------------------------

func test_interval_is_start_at_zero_score() -> void:
	assert_almost_eq(SpawnPlan.spawn_interval(2.0, 0.5, 0, 1000), 2.0, 0.0001)


func test_interval_is_end_at_threshold() -> void:
	assert_almost_eq(SpawnPlan.spawn_interval(2.0, 0.5, 1000, 1000), 0.5, 0.0001)


func test_interval_clamps_to_end_past_threshold() -> void:
	assert_almost_eq(SpawnPlan.spawn_interval(2.0, 0.5, 5000, 1000), 0.5, 0.0001)


func test_interval_ramps_monotonically_between() -> void:
	var early: float = SpawnPlan.spawn_interval(2.0, 0.5, 250, 1000)
	var mid: float = SpawnPlan.spawn_interval(2.0, 0.5, 500, 1000)
	var late: float = SpawnPlan.spawn_interval(2.0, 0.5, 750, 1000)
	assert_gt(early, mid, "interval tightens as the stage builds")
	assert_gt(mid, late, "interval keeps tightening")


func test_non_positive_threshold_returns_end_interval() -> void:
	assert_almost_eq(SpawnPlan.spawn_interval(2.0, 0.5, 500, 0), 0.5, 0.0001)


# --- can_spawn (concurrency cap) ------------------------------------------

func test_spawn_allowed_below_the_cap() -> void:
	assert_true(SpawnPlan.can_spawn(0, 3))
	assert_true(SpawnPlan.can_spawn(2, 3))


func test_spawn_blocked_at_the_cap() -> void:
	assert_false(SpawnPlan.can_spawn(3, 3), "at the cap, no new spawn")


func test_spawn_blocked_above_the_cap() -> void:
	assert_false(SpawnPlan.can_spawn(5, 3), "over the cap stays blocked until enemies clear")


# --- aimed_blocked --------------------------------------------------------

func test_aimed_blocked_inside_the_gap_window() -> void:
	assert_true(SpawnPlan.aimed_blocked(10.0, 9.0, 2.0), "1s since last aimed < 2s gap")


func test_aimed_allowed_outside_the_gap_window() -> void:
	assert_false(SpawnPlan.aimed_blocked(12.0, 9.0, 2.0), "3s since last aimed > 2s gap")


func test_aimed_allowed_exactly_at_the_gap_boundary() -> void:
	assert_false(SpawnPlan.aimed_blocked(11.0, 9.0, 2.0), "exactly 2s is not < 2s")


func test_zero_gap_never_blocks() -> void:
	assert_false(SpawnPlan.aimed_blocked(9.0, 9.0, 0.0), "a zero gap disables the rule")


# --- boss_should_fire -----------------------------------------------------

func test_boss_does_not_fire_below_threshold() -> void:
	assert_false(SpawnPlan.boss_should_fire(500, 1000, false))


func test_boss_fires_at_threshold_when_untriggered() -> void:
	assert_true(SpawnPlan.boss_should_fire(1000, 1000, false))


func test_boss_does_not_fire_twice() -> void:
	assert_false(SpawnPlan.boss_should_fire(1500, 1000, true), "already triggered = one-shot")


# --- tier_is_aimed --------------------------------------------------------

func test_only_the_aimed_tier_classifies_as_aimed() -> void:
	assert_true(SpawnPlan.tier_is_aimed(ThreatTier.Tier.AIMED))
	assert_false(SpawnPlan.tier_is_aimed(ThreatTier.Tier.STRAIGHT))
	assert_false(SpawnPlan.tier_is_aimed(ThreatTier.Tier.PATTERN))
