extends GutTest

const BOUNDS := Rect2(0, 0, 540, 960)
const MAX_SPEED := 1000.0
const FULL_LERP := 1.0
const DELTA := 1.0 / 60.0

func test_moves_toward_target() -> void:
	var result := PlayerMovement.next_position(
		Vector2(100, 100), Vector2(400, 100), MAX_SPEED, FULL_LERP, DELTA, BOUNDS
	)
	assert_gt(result.x, 100.0, "x should advance toward target")
	assert_eq(result.y, 100.0, "y should not change when target is horizontal")

func test_never_overshoots_max_speed_step() -> void:
	var current := Vector2(100, 100)
	var target := Vector2(10000, 100)  # very far
	var result := PlayerMovement.next_position(current, target, MAX_SPEED, FULL_LERP, DELTA, BOUNDS)
	var step_len := (result - current).length()
	var max_step := MAX_SPEED * DELTA
	assert_almost_eq(step_len, max_step, 0.0001, "step capped to max_speed * delta")

func test_clamps_against_left_edge() -> void:
	var result := PlayerMovement.next_position(
		Vector2(10, 200), Vector2(-1000, 200), MAX_SPEED, FULL_LERP, DELTA, BOUNDS
	)
	assert_eq(result.x, BOUNDS.position.x, "left edge clamp")

func test_clamps_against_right_edge() -> void:
	var result := PlayerMovement.next_position(
		Vector2(530, 200), Vector2(1000, 200), MAX_SPEED, FULL_LERP, DELTA, BOUNDS
	)
	assert_eq(result.x, BOUNDS.position.x + BOUNDS.size.x, "right edge clamp")

func test_clamps_against_top_edge() -> void:
	var result := PlayerMovement.next_position(
		Vector2(200, 10), Vector2(200, -1000), MAX_SPEED, FULL_LERP, DELTA, BOUNDS
	)
	assert_eq(result.y, BOUNDS.position.y, "top edge clamp")

func test_clamps_against_bottom_edge() -> void:
	var result := PlayerMovement.next_position(
		Vector2(200, 950), Vector2(200, 5000), MAX_SPEED, FULL_LERP, DELTA, BOUNDS
	)
	assert_eq(result.y, BOUNDS.position.y + BOUNDS.size.y, "bottom edge clamp")

func test_no_drift_when_at_target() -> void:
	var current := Vector2(270, 480)
	var result := PlayerMovement.next_position(current, current, MAX_SPEED, FULL_LERP, DELTA, BOUNDS)
	assert_eq(result, current, "no movement when already at target")

func test_no_nan_when_at_target() -> void:
	var current := Vector2(270, 480)
	var result := PlayerMovement.next_position(current, current, MAX_SPEED, 0.5, DELTA, BOUNDS)
	assert_false(is_nan(result.x), "x is not NaN")
	assert_false(is_nan(result.y), "y is not NaN")

func test_zero_delta_no_movement() -> void:
	var current := Vector2(100, 100)
	var result := PlayerMovement.next_position(
		current, Vector2(500, 500), MAX_SPEED, FULL_LERP, 0.0, BOUNDS
	)
	assert_eq(result, current, "zero delta produces no movement")

func test_large_delta_still_clamped() -> void:
	# A huge delta should still keep the player inside bounds, never teleport past.
	var result := PlayerMovement.next_position(
		Vector2(100, 100), Vector2(10000, 10000), MAX_SPEED, FULL_LERP, 100.0, BOUNDS
	)
	assert_lte(result.x, BOUNDS.position.x + BOUNDS.size.x, "x stays within right bound")
	assert_lte(result.y, BOUNDS.position.y + BOUNDS.size.y, "y stays within bottom bound")
	assert_gte(result.x, BOUNDS.position.x, "x stays within left bound")
	assert_gte(result.y, BOUNDS.position.y, "y stays within top bound")
