extends GutTest

# PRD-12 — the pure boss brain (BossState): the parts tree, the core gate, phase
# resolution from weak-point destruction, the monotonic aggregate bar, and
# defeat-on-core. Same "assert external behaviour through the interface, not
# private state" discipline as the HangarUpgrades / GadgetLoadout tests; no
# autoload or scene dependencies — BossState is built purely as data.

# A reference boss: two weak-points guarding a core. Mirrors BossReference.tscn.
func _two_weakpoint_boss() -> BossState:
	var s := BossState.new()
	s.add_part("core", 30, true)
	s.add_part("gun_left", 12, false)
	s.add_part("gun_right", 12, false)
	return s


func _mini_boss() -> BossState:
	var s := BossState.new()
	s.add_part("core", 40, true)
	return s


# --- core gate ---


func test_core_not_damageable_while_any_weakpoint_lives() -> void:
	var s := _two_weakpoint_boss()
	assert_false(s.is_damageable("core"), "core is gated at spawn")
	s.apply_damage("gun_left", 12)  # one weak-point down, one still alive
	assert_false(s.is_damageable("core"), "core stays gated while a weak-point lives")


func test_core_becomes_damageable_the_instant_last_weakpoint_dies() -> void:
	var s := _two_weakpoint_boss()
	s.apply_damage("gun_left", 12)
	s.apply_damage("gun_right", 12)
	assert_true(s.is_damageable("core"), "core unlocks the instant the last weak-point falls")
	assert_true(s.is_core_exposed(), "core-exposed beat is set")


func test_damage_to_gated_core_is_a_no_op() -> void:
	var s := _two_weakpoint_boss()
	var result := s.apply_damage("core", 10)
	assert_false(result["ok"], "a gated core takes no damage")
	assert_eq(s.current_hp("core"), 30, "core HP unchanged by a shrugged-off hit")
	assert_false(s.is_defeated(), "shrugging off hits never defeats")


# --- phase resolution (purely weak-point driven) ---


func test_phase_advances_at_each_weakpoint_milestone() -> void:
	var s := _two_weakpoint_boss()
	assert_eq(s.current_phase(), 1, "phase 1 with all weak-points alive")
	assert_eq(s.phase_count(), 3, "two weak-points yield three phases")
	s.apply_damage("gun_left", 12)
	assert_eq(s.current_phase(), 2, "phase 2 when the first weak-point falls")
	s.apply_damage("gun_right", 12)
	assert_eq(s.current_phase(), 3, "final phase when all weak-points are destroyed")


func test_phase_is_order_independent() -> void:
	var s := _two_weakpoint_boss()
	s.apply_damage("gun_right", 12)  # kill the other one first
	assert_eq(s.current_phase(), 2, "phase counts destroyed weak-points, not which")
	s.apply_damage("gun_left", 12)
	assert_eq(s.current_phase(), 3, "final phase regardless of kill order")


func test_no_hp_percentage_phase_flip() -> void:
	# Chipping a weak-point below half its HP must NOT advance the phase — only
	# destruction does (the prototype's current_hp <= max/2 flip is gone).
	var s := _two_weakpoint_boss()
	s.apply_damage("gun_left", 11)  # 1 HP left, not destroyed
	assert_eq(s.current_phase(), 1, "a wounded-but-living weak-point does not advance the phase")


# --- aggregate HP (monotonic) ---


func test_aggregate_max_is_sum_at_spawn() -> void:
	var s := _two_weakpoint_boss()
	var agg := s.aggregate_hp()
	assert_eq(agg["max"], 54, "max = 30 + 12 + 12")
	assert_eq(agg["current"], 54, "current = max at spawn")


func test_aggregate_drains_with_damage_and_destruction() -> void:
	var s := _two_weakpoint_boss()
	s.apply_damage("gun_left", 5)
	assert_eq(s.aggregate_hp()["current"], 49, "a 5-damage hit drains the aggregate by 5")
	s.apply_damage("gun_left", 7)  # destroys it (12 total)
	assert_eq(s.aggregate_hp()["current"], 42, "a destroyed part contributes 0, not negative")


func test_aggregate_floors_at_core_hp_just_before_core_dies() -> void:
	var s := _two_weakpoint_boss()
	s.apply_damage("gun_left", 12)
	s.apply_damage("gun_right", 12)
	assert_eq(s.aggregate_hp()["current"], 30, "with both weak-points gone, only core HP remains")
	s.apply_damage("core", 30)
	assert_eq(s.aggregate_hp()["current"], 0, "aggregate bottoms out at 0 when the core dies")


func test_aggregate_never_goes_negative_on_overkill() -> void:
	var s := _mini_boss()
	s.apply_damage("core", 999)
	assert_eq(s.aggregate_hp()["current"], 0, "overkill clamps to 0, never negative")


# --- defeat (core only) ---


func test_not_defeated_until_core_destroyed() -> void:
	var s := _two_weakpoint_boss()
	s.apply_damage("gun_left", 12)
	s.apply_damage("gun_right", 12)
	assert_false(s.is_defeated(), "destroying every weak-point alone never defeats")
	s.apply_damage("core", 30)
	assert_true(s.is_defeated(), "defeated once the exposed core is destroyed")


# --- mini-boss (degenerate core-only case) ---


func test_mini_boss_is_immediately_damageable_single_phase() -> void:
	var s := _mini_boss()
	assert_true(s.is_damageable("core"), "a core-only boss is exposed from the start")
	assert_eq(s.weakpoint_count(), 0, "no weak-points to peel")
	assert_eq(s.current_phase(), 1, "single phase")
	assert_eq(s.phase_count(), 1, "no extra phases without weak-points")


func test_mini_boss_defeated_when_its_one_part_dies() -> void:
	var s := _mini_boss()
	var result := s.apply_damage("core", 40)
	assert_true(result["ok"], "the lone core takes damage")
	assert_true(result["destroyed"], "the hit that empties it reports destroyed")
	assert_true(s.is_defeated(), "the boss dies with its one part — no special-casing")


# --- no mutation on no-op ---


func test_no_mutation_when_damaging_a_destroyed_part() -> void:
	var s := _two_weakpoint_boss()
	s.apply_damage("gun_left", 12)  # destroy it
	var before: int = s.aggregate_hp()["current"]
	var result := s.apply_damage("gun_left", 5)  # hit the corpse
	assert_false(result["ok"], "a destroyed part takes no further damage")
	assert_eq(s.aggregate_hp()["current"], before, "state unchanged hitting a dead part")


func test_non_positive_damage_is_a_no_op() -> void:
	var s := _mini_boss()
	assert_false(s.apply_damage("core", 0)["ok"], "zero damage does nothing")
	assert_false(s.apply_damage("core", -5)["ok"], "negative damage does nothing")
	assert_eq(s.current_hp("core"), 40, "core HP untouched by non-positive damage")


func test_destroyed_flag_only_on_the_emptying_hit() -> void:
	var s := _mini_boss()
	assert_false(s.apply_damage("core", 10)["destroyed"], "a partial hit is not a destruction")
	assert_true(s.apply_damage("core", 30)["destroyed"], "the hit that reaches 0 reports destroyed")
