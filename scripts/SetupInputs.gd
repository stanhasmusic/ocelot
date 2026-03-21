@tool
extends EditorScript

func _run() -> void:
	# Movement (WASD + Arrows + Controller)
	_setup_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], []) # Will add axis manually below to be explicit? No, using the function.
	# Actually, the utility function supports it. 
	_setup_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], []) 
	# Wait, I need negative values. The helper assumes 1.0 for triggers.
	# I need to update the helper or just handle it here.
	# Simplified: Just calling _setup_action for buttons and then adding axes manually for clarity.
	
	_setup_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_setup_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_setup_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_setup_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	
	_add_axis_event("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis_event("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis_event("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis_event("move_down", JOY_AXIS_LEFT_Y, 1.0)
	
	# Actions
	_setup_action("shoot", [KEY_SPACE], [], [JOY_AXIS_TRIGGER_RIGHT])
	_setup_action("bomb", [KEY_ALT], [JOY_BUTTON_A]) # Xbox A / Cross
	
	# UI Actions (Controller Support)
	_setup_action("ui_accept", [KEY_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_setup_action("ui_cancel", [KEY_ESCAPE], [JOY_BUTTON_B])
	
	print("Input Map configured successfully! (Keyboard + Controller with Sticks)")

func _add_axis_event(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var event = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _setup_action(action_name: String, keys: Array = [], joy_buttons: Array = [], joy_axes: Array = []) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	
	# Add deadzone to the action itself if it doesn't have it (optional, but good for axes)
	# InputMap.action_set_deadzone(action_name, 0.5)

	# Add Keys
	for k in keys:
		var event = InputEventKey.new()
		event.keycode = k
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)
	
	# Add Joypad Buttons
	for b in joy_buttons:
		var event = InputEventJoypadButton.new()
		event.button_index = b
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)
			
	# Add Joypad Axes (Triggers)
	for a in joy_axes:
		var event = InputEventJoypadMotion.new()
		event.axis = a
		event.axis_value = 1.0 # Trigger pressed
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)
