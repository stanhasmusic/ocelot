extends GutTest

# PRD-03 pickup magnet steering. Pure: position + radius in, per-frame delta out.

const FALL := 100.0
const DELTA := 1.0 / 60.0

func test_zero_radius_is_straight_fall() -> void:
	var d := PickupMagnet.step(Vector2(100, 100), Vector2(100, 300), FALL, 0.0, DELTA)
	assert_eq(d.x, 0.0, "no horizontal pull when magnet is disabled")
	assert_almost_eq(d.y, FALL * DELTA, 0.0001, "falls at fall_speed * delta")

func test_outside_radius_is_straight_fall() -> void:
	# Player far to the left but beyond the radius -> no attraction.
	var d := PickupMagnet.step(Vector2(400, 100), Vector2(100, 100), FALL, 50.0, DELTA)
	assert_eq(d.x, 0.0, "no pull outside the magnet radius")
	assert_almost_eq(d.y, FALL * DELTA, 0.0001, "still falls normally")

func test_inside_radius_pulls_left_toward_player() -> void:
	var d := PickupMagnet.step(Vector2(200, 100), Vector2(150, 100), FALL, 200.0, DELTA)
	assert_lt(d.x, 0.0, "pulled left toward a player on the left")

func test_inside_radius_pulls_right_toward_player() -> void:
	var d := PickupMagnet.step(Vector2(100, 100), Vector2(150, 100), FALL, 200.0, DELTA)
	assert_gt(d.x, 0.0, "pulled right toward a player on the right")

func test_player_on_top_is_safe() -> void:
	var d := PickupMagnet.step(Vector2(150, 150), Vector2(150, 150), FALL, 200.0, DELTA)
	assert_false(is_nan(d.x), "no NaN when player coincides with pickup")
	assert_false(is_nan(d.y), "no NaN on the y axis either")
