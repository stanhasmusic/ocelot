extends GutTest

# PRD-03 device -> control-scheme resolver. Pure data in, scheme out; debounce
# and stick-deadzone hysteresis are exercised with explicit timestamps so no
# timer or node is needed.

const DEADZONE := 0.2
const DEBOUNCE := 0.1

func _resolver() -> InputScheme:
	return InputScheme.new(DEADZONE, DEBOUNCE)

func test_default_scheme_is_positional() -> void:
	assert_eq(InputScheme.DEFAULT_SCHEME, InputScheme.Scheme.POSITIONAL,
		"cold start defaults to positional (mouse/touch)")

func test_scheme_for_kind_mapping() -> void:
	assert_eq(InputScheme.scheme_for_kind(InputScheme.EventKind.MOUSE),
		InputScheme.Scheme.POSITIONAL, "mouse -> positional")
	assert_eq(InputScheme.scheme_for_kind(InputScheme.EventKind.TOUCH),
		InputScheme.Scheme.POSITIONAL, "touch -> positional")
	assert_eq(InputScheme.scheme_for_kind(InputScheme.EventKind.JOYPAD),
		InputScheme.Scheme.VELOCITY, "joypad -> velocity")
	assert_eq(InputScheme.scheme_for_kind(InputScheme.EventKind.KEY),
		InputScheme.Scheme.VELOCITY, "key -> velocity")

func test_mouse_swaps_from_velocity_to_positional() -> void:
	var r := _resolver()
	var s := r.resolve(InputScheme.Scheme.VELOCITY, InputScheme.EventKind.MOUSE, 0.0, 1.0)
	assert_eq(s, InputScheme.Scheme.POSITIONAL, "a mouse move swaps to positional")

func test_joypad_button_swaps_from_positional_to_velocity() -> void:
	var r := _resolver()
	var s := r.resolve(InputScheme.Scheme.POSITIONAL, InputScheme.EventKind.JOYPAD, 1.0, 1.0)
	assert_eq(s, InputScheme.Scheme.VELOCITY, "a joypad button swaps to velocity")

func test_above_deadzone_stick_swaps() -> void:
	var r := _resolver()
	var s := r.resolve(InputScheme.Scheme.POSITIONAL, InputScheme.EventKind.JOYPAD, 0.9, 1.0)
	assert_eq(s, InputScheme.Scheme.VELOCITY, "deliberate stick push swaps to velocity")

func test_sub_deadzone_stick_does_not_swap() -> void:
	var r := _resolver()
	var s := r.resolve(InputScheme.Scheme.POSITIONAL, InputScheme.EventKind.JOYPAD, 0.1, 1.0)
	assert_eq(s, InputScheme.Scheme.POSITIONAL, "resting-stick drift never swaps (hysteresis)")

func test_conflicting_event_within_debounce_does_not_thrash() -> void:
	var r := _resolver()
	var s1 := r.resolve(InputScheme.Scheme.POSITIONAL, InputScheme.EventKind.JOYPAD, 1.0, 1.0)
	assert_eq(s1, InputScheme.Scheme.VELOCITY, "first swap goes through")
	var s2 := r.resolve(s1, InputScheme.EventKind.MOUSE, 0.0, 1.05)
	assert_eq(s2, InputScheme.Scheme.VELOCITY, "conflicting swap inside debounce is rejected")

func test_swap_allowed_after_debounce_window() -> void:
	var r := _resolver()
	var s1 := r.resolve(InputScheme.Scheme.POSITIONAL, InputScheme.EventKind.JOYPAD, 1.0, 1.0)
	var s2 := r.resolve(s1, InputScheme.EventKind.MOUSE, 0.0, 1.2)
	assert_eq(s2, InputScheme.Scheme.POSITIONAL, "swap allowed once the debounce window elapses")

func test_identical_repeated_events_are_idempotent() -> void:
	var r := _resolver()
	var a := r.resolve(InputScheme.Scheme.POSITIONAL, InputScheme.EventKind.MOUSE, 0.0, 1.0)
	var b := r.resolve(a, InputScheme.EventKind.MOUSE, 0.0, 1.01)
	var c := r.resolve(b, InputScheme.EventKind.MOUSE, 0.0, 1.02)
	assert_eq(c, InputScheme.Scheme.POSITIONAL, "same-device events keep the scheme stable")

func test_same_device_does_not_consume_debounce_budget() -> void:
	# A burst of same-scheme events must not arm the debounce clock, or a real
	# device change right after would be wrongly rejected.
	var r := _resolver()
	var a := r.resolve(InputScheme.Scheme.POSITIONAL, InputScheme.EventKind.MOUSE, 0.0, 1.0)
	a = r.resolve(a, InputScheme.EventKind.MOUSE, 0.0, 1.02)
	var s := r.resolve(a, InputScheme.EventKind.JOYPAD, 1.0, 1.03)
	assert_eq(s, InputScheme.Scheme.VELOCITY, "a genuine device change still swaps promptly")
