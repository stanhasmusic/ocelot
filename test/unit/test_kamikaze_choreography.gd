extends GutTest

# Asserts the Kamikaze wing's pure choreography (PRD-13): the formation layout and
# the staggered commit schedule. Both are plain geometry/timing, so they're driven
# off knobs with no scene instantiation or rendering (ADR-0004). The node-level
# behaviour (diving, contact, invuln-on-commit, bomb-clears-committed) is
# feel-tested live via the DevConsole, not here.

const VEE := KamikazeChoreography.Shape.VEE
const LINE := KamikazeChoreography.Shape.LINE


# --- member_offsets -------------------------------------------------------

func test_returns_exactly_count_offsets() -> void:
	assert_eq(KamikazeChoreography.member_offsets(5, 70.0, VEE).size(), 5)


func test_non_positive_count_returns_empty() -> void:
	assert_eq(KamikazeChoreography.member_offsets(0, 70.0, VEE).size(), 0)
	assert_eq(KamikazeChoreography.member_offsets(-3, 70.0, VEE).size(), 0)


func test_single_member_sits_on_the_anchor() -> void:
	var offsets := KamikazeChoreography.member_offsets(1, 70.0, VEE)
	assert_eq(offsets.size(), 1)
	assert_eq(offsets[0], Vector2.ZERO)


func test_offsets_are_symmetric_about_the_anchor() -> void:
	# Mirror pairs negate x and share y (a centred V).
	var offsets := KamikazeChoreography.member_offsets(5, 70.0, VEE)
	var n := offsets.size()
	for i in n:
		var mirror := offsets[n - 1 - i]
		assert_almost_eq(offsets[i].x, -mirror.x, 0.0001)
		assert_almost_eq(offsets[i].y, mirror.y, 0.0001)


func test_even_count_is_also_symmetric() -> void:
	var offsets := KamikazeChoreography.member_offsets(4, 50.0, VEE)
	var n := offsets.size()
	var sum_x := 0.0
	for o in offsets:
		sum_x += o.x
	assert_almost_eq(sum_x, 0.0, 0.0001, "lanes balance about the anchor")
	assert_almost_eq(offsets[0].x, -offsets[n - 1].x, 0.0001)


func test_spacing_scales_the_spread_linearly() -> void:
	var narrow := KamikazeChoreography.member_offsets(5, 40.0, VEE)
	var wide := KamikazeChoreography.member_offsets(5, 80.0, VEE)
	for i in narrow.size():
		assert_almost_eq(wide[i].x, narrow[i].x * 2.0, 0.0001)
		assert_almost_eq(wide[i].y, narrow[i].y * 2.0, 0.0001)


func test_vee_trails_the_wings_back_but_line_stays_flat() -> void:
	var vee := KamikazeChoreography.member_offsets(5, 70.0, VEE)
	var line := KamikazeChoreography.member_offsets(5, 70.0, LINE)
	# Centre member is the tip in both; the wing tips trail back only in a VEE.
	assert_almost_eq(vee[2].y, 0.0, 0.0001, "centre is the tip")
	assert_gt(vee[0].y, 0.0, "an edge plane trails back in a VEE")
	for o in line:
		assert_almost_eq(o.y, 0.0, 0.0001, "a LINE is flat")


# --- commit_times ---------------------------------------------------------

func test_returns_exactly_count_times() -> void:
	assert_eq(KamikazeChoreography.commit_times(5, 1.5, 1.1).size(), 5)


func test_first_commit_is_at_hold_time() -> void:
	assert_almost_eq(KamikazeChoreography.commit_times(5, 1.5, 1.1)[0], 1.5, 0.0001)


func test_each_subsequent_commit_increases_by_the_stagger_gap() -> void:
	var times := KamikazeChoreography.commit_times(5, 1.5, 1.1)
	for i in range(1, times.size()):
		assert_almost_eq(times[i] - times[i - 1], 1.1, 0.0001)


func test_schedule_is_monotonic() -> void:
	var times := KamikazeChoreography.commit_times(5, 1.5, 1.1)
	for i in range(1, times.size()):
		assert_gt(times[i], times[i - 1])


func test_single_member_yields_a_single_time() -> void:
	var times := KamikazeChoreography.commit_times(1, 1.5, 1.1)
	assert_eq(times.size(), 1)
	assert_almost_eq(times[0], 1.5, 0.0001)


func test_non_positive_count_yields_no_times() -> void:
	assert_eq(KamikazeChoreography.commit_times(0, 1.5, 1.1).size(), 0)
