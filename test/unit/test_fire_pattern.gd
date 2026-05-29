extends GutTest

# Guards the shared fire-geometry helpers (PRD-05). External behaviour only:
# feed source/target points or a count + arc and assert the returned vectors —
# no enemy scene is instantiated. These replace the per-enemy literal angle
# lists, so the tests also pin the legacy spreads to prove parity.

const TAU_QUARTER := PI / 2.0


# --- aimed_direction ------------------------------------------------------

func test_aimed_direction_points_straight_down() -> void:
	var dir := FirePattern.aimed_direction(Vector2.ZERO, Vector2(0, 100))
	assert_almost_eq(dir.x, 0.0, 0.0001)
	assert_almost_eq(dir.y, 1.0, 0.0001)


func test_aimed_direction_points_right() -> void:
	var dir := FirePattern.aimed_direction(Vector2.ZERO, Vector2(100, 0))
	assert_almost_eq(dir.x, 1.0, 0.0001)
	assert_almost_eq(dir.y, 0.0, 0.0001)


func test_aimed_direction_is_a_unit_vector_on_the_diagonal() -> void:
	var dir := FirePattern.aimed_direction(Vector2(10, 10), Vector2(110, 110))
	assert_almost_eq(dir.length(), 1.0, 0.0001, "diagonal aim is normalised")
	assert_almost_eq(dir.x, dir.y, 0.0001, "45 degree diagonal is symmetric")


func test_aimed_direction_degenerate_falls_back_to_down() -> void:
	var dir := FirePattern.aimed_direction(Vector2(5, 5), Vector2(5, 5))
	assert_eq(dir, Vector2.DOWN, "same point never divides by zero")


# --- spread_directions ----------------------------------------------------

func test_single_shot_returns_the_base_direction() -> void:
	var dirs := FirePattern.spread_directions(Vector2.DOWN, 1, 1.0)
	assert_eq(dirs.size(), 1)
	assert_almost_eq(dirs[0].angle(), TAU_QUARTER, 0.0001, "count 1 ignores the arc")


func test_zero_count_returns_empty() -> void:
	assert_eq(FirePattern.spread_directions(Vector2.DOWN, 0, 1.0).size(), 0)


func test_spread_returns_exactly_count_vectors() -> void:
	assert_eq(FirePattern.spread_directions(Vector2.DOWN, 5, 1.0).size(), 5)


func test_spread_is_symmetric_about_the_base() -> void:
	var dirs := FirePattern.spread_directions(Vector2.DOWN, 3, 0.6)
	# Middle of an odd fan is the base direction; ends mirror each other.
	assert_almost_eq(dirs[1].angle(), TAU_QUARTER, 0.0001, "odd count centres on base")
	var left_offset := dirs[0].angle() - TAU_QUARTER
	var right_offset := dirs[2].angle() - TAU_QUARTER
	assert_almost_eq(left_offset, -right_offset, 0.0001, "ends are mirror images")


func test_spread_spans_the_requested_arc() -> void:
	var dirs := FirePattern.spread_directions(Vector2.DOWN, 4, 1.2)
	var span := dirs[dirs.size() - 1].angle() - dirs[0].angle()
	assert_almost_eq(span, 1.2, 0.0001, "first-to-last covers the full arc")


func test_spread_vectors_are_all_unit_length() -> void:
	for dir in FirePattern.spread_directions(Vector2.DOWN, 5, 1.0):
		assert_almost_eq(dir.length(), 1.0, 0.0001)


func test_reproduces_legacy_bomber_spread() -> void:
	# Old Bomber fired b.rotation = PI/2 + [-0.5,-0.25,0,0.25,0.5].
	var expected := [-0.5, -0.25, 0.0, 0.25, 0.5]
	var dirs := FirePattern.spread_directions(Vector2.DOWN, 5, 1.0)
	for i in dirs.size():
		assert_almost_eq(dirs[i].angle(), TAU_QUARTER + expected[i], 0.0001)
