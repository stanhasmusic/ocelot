extends GutTest

# PRD-06 bomb selection rule. Pure: positions + screen rect in, indices out.

const SCREEN := Rect2(0, 0, 540, 960)


func test_inside_screen_is_selected() -> void:
	var hit := BombTargeting.affected_by_bomb([Vector2(270, 480)], SCREEN)
	assert_eq(hit, [0] as Array[int], "a point in the middle of the screen is hit")


func test_outside_screen_is_not_selected() -> void:
	var positions := [Vector2(-10, 480), Vector2(270, 1200), Vector2(600, 480)]
	var hit := BombTargeting.affected_by_bomb(positions, SCREEN)
	assert_eq(hit.size(), 0, "points off-screen are not hit")


func test_mixed_returns_only_inside_indices() -> void:
	var positions := [
		Vector2(270, 480),  # 0 in
		Vector2(-50, -50),  # 1 out
		Vector2(10, 10),  # 2 in
		Vector2(540, 960),  # 3 out (bottom-right is exclusive)
	]
	var hit := BombTargeting.affected_by_bomb(positions, SCREEN)
	assert_eq(hit, [0, 2] as Array[int], "only the on-screen indices come back, in order")


func test_top_left_corner_is_inclusive() -> void:
	var hit := BombTargeting.affected_by_bomb([Vector2(0, 0)], SCREEN)
	assert_eq(hit, [0] as Array[int], "the top-left corner counts as on-screen (Rect2.has_point)")


func test_empty_input_returns_empty() -> void:
	var hit := BombTargeting.affected_by_bomb([], SCREEN)
	assert_eq(hit.size(), 0, "no entities -> nothing hit")
