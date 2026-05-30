extends GutTest

# PRD-06 temporary-topping tracker. Pure: add/tick/query, no nodes.


func test_added_effect_is_active_for_its_duration() -> void:
	var stack := TemporaryEffectStack.new()
	stack.add("fire_swap", 5.0)
	assert_true(stack.is_active("fire_swap"), "effect is live right after adding")
	assert_almost_eq(stack.time_left("fire_swap"), 5.0, 0.0001, "full duration remains")


func test_tick_past_duration_expires_effect() -> void:
	var stack := TemporaryEffectStack.new()
	stack.add("missile", 2.0)
	stack.tick(1.5)
	assert_true(stack.is_active("missile"), "still live before the duration elapses")
	stack.tick(1.0)
	assert_false(stack.is_active("missile"), "expired once total tick exceeds duration")
	assert_eq(stack.time_left("missile"), 0.0, "no time left on an expired effect")


func test_re_adding_refreshes_not_double_stacks() -> void:
	var stack := TemporaryEffectStack.new()
	stack.add("wingman", 5.0)
	stack.tick(3.0)  # 2.0 left
	stack.add("wingman", 5.0)  # refresh to the longer of 2.0 and 5.0
	assert_almost_eq(stack.time_left("wingman"), 5.0, 0.0001, "timer refreshed, not summed to 7.0")


func test_re_adding_shorter_does_not_shrink() -> void:
	var stack := TemporaryEffectStack.new()
	stack.add("wingman", 5.0)
	stack.add("wingman", 1.0)  # shorter -> must not weaken the player
	assert_almost_eq(stack.time_left("wingman"), 5.0, 0.0001, "keeps the longer remaining time")


func test_multiple_effects_expire_independently() -> void:
	var stack := TemporaryEffectStack.new()
	stack.add("fire_swap", 2.0)
	stack.add("wingman", 6.0)
	stack.tick(3.0)
	assert_false(stack.is_active("fire_swap"), "short effect expired")
	assert_true(stack.is_active("wingman"), "long effect still live")
	assert_eq(stack.active().size(), 1, "only the live effect is reported")


func test_tick_empty_stack_is_noop() -> void:
	var stack := TemporaryEffectStack.new()
	stack.tick(1.0)
	assert_eq(stack.active().size(), 0, "ticking an empty stack does nothing")


func test_non_positive_duration_is_ignored() -> void:
	var stack := TemporaryEffectStack.new()
	stack.add("fire_swap", 0.0)
	stack.add("missile", -3.0)
	assert_false(stack.is_active("fire_swap"), "zero-length effect never registers")
	assert_false(stack.is_active("missile"), "negative-length effect never registers")


func test_negative_delta_does_not_extend() -> void:
	var stack := TemporaryEffectStack.new()
	stack.add("missile", 2.0)
	stack.tick(-10.0)
	assert_almost_eq(stack.time_left("missile"), 2.0, 0.0001, "a bad frame time cannot add time")


func test_is_expiring_within_warn_window() -> void:
	var stack := TemporaryEffectStack.new()
	stack.add("fire_swap", 5.0)
	assert_false(stack.is_expiring("fire_swap", 1.0), "not expiring with plenty of time left")
	stack.tick(4.5)  # 0.5 left
	assert_true(stack.is_expiring("fire_swap", 1.0), "expiring once inside the warn window")
	assert_false(stack.is_expiring("missile", 1.0), "a dead effect is never expiring")
