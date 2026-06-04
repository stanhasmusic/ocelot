extends GutTest

# PRD-06 bomb selection rule. Pure: positions + screen rect in, indices out.

const SCREEN := Rect2(0, 0, 540, 960)
const CENTER := Vector2(270, 480)  # within_radius cases


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


# --- within_radius (PRD-09 Flare nearby-clear) ---


func test_within_radius_selects_points_inside_the_circle() -> void:
	var positions := [
		Vector2(270, 480),  # 0 dead centre
		Vector2(370, 480),  # 1 exactly 100 px away
		Vector2(270, 700),  # 2 220 px away — outside a 200 radius
	]
	var hit := BombTargeting.within_radius(positions, CENTER, 200.0)
	assert_eq(hit, [0, 1] as Array[int], "only the points within 200 px come back, in order")


func test_within_radius_rim_is_inclusive() -> void:
	var hit := BombTargeting.within_radius([Vector2(270, 580)], CENTER, 100.0)
	assert_eq(hit, [0] as Array[int], "a point exactly on the rim counts as hit")


func test_within_radius_non_positive_radius_hits_nothing() -> void:
	var hit := BombTargeting.within_radius([CENTER], CENTER, 0.0)
	assert_eq(hit.size(), 0, "a zero radius clears nothing, even at the centre")


func test_within_radius_empty_input_returns_empty() -> void:
	var hit := BombTargeting.within_radius([], CENTER, 300.0)
	assert_eq(hit.size(), 0, "no entities -> nothing cleared")
