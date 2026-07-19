extends Node

# Binds the CY-1121 arcade panel (two "Twin USB Gamepad" devices, one per
# panel half) onto this game's existing keyboard actions. Keyboard bindings
# in project.godot are left untouched, so laptop dev and cabinet play both
# work with the same action names.
#
# Raw layout per bank (see ../cy1121-arcade-diagnostics/CONTROLS.md):
#   axes 0/1 = stick (digital, ±1.0), buttons 0..5 = panel buttons 1..6,
#   button 9 = Start, button 8 = Select (LEFT bank only).
#
# Enumeration order of the two banks is not guaranteed, so we bind a default
# order at startup and auto-correct at runtime: a press of Select (button 8)
# can only come from the left bank, and the Start press that begins a session
# is almost always 1P Start (left bank). Either signal claims that device as
# Player 1 and rebinds.

const BTN_START := 9
const BTN_SELECT := 8

var p1_device: int = -1
var p2_device: int = -1
var _locked := false  # stop b9 heuristic once gameplay starts

func _ready() -> void:
	var pads := Input.get_connected_joypads()
	if pads.size() >= 1:
		p1_device = pads[0]
	if pads.size() >= 2:
		p2_device = pads[1]
	_bind_shared_ui()
	_rebind_players()
	Input.joy_connection_changed.connect(_on_joy_changed)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		# Select exists only on the left bank: definitive left-bank signal.
		if event.button_index == BTN_SELECT:
			_claim_p1(event.device)
		# First Start press is assumed to be 1P Start (left bank).
		elif event.button_index == BTN_START and not _locked:
			_claim_p1(event.device)
			_locked = true

func _claim_p1(device: int) -> void:
	if device == p1_device:
		return
	if device == p2_device:
		p2_device = p1_device
	p1_device = device
	_rebind_players()

func _on_joy_changed(device: int, connected: bool) -> void:
	if connected:
		if p1_device < 0:
			p1_device = device
		elif p2_device < 0 and device != p1_device:
			p2_device = device
		_rebind_players()

# --- binding helpers -------------------------------------------------------

func _bind_shared_ui() -> void:
	# Menu navigation / confirm from ANY bank (device -1), on top of Godot's
	# keyboard defaults. Raw indices, so this works even when the pad's GUID
	# is unknown to Godot's SDL database.
	_add_axis("ui_up", -1, JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("ui_down", -1, JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("ui_left", -1, JOY_AXIS_LEFT_X, -1.0)
	_add_axis("ui_right", -1, JOY_AXIS_LEFT_X, 1.0)
	_add_button("ui_accept", -1, 0)          # Button 1 = confirm
	_add_button("ui_accept", -1, BTN_START)  # Start = confirm
	_add_button("ui_cancel", -1, 1)          # Button 2 = back/pause
	_add_button("ui_exit", -1, BTN_SELECT)   # Select = quit to launcher

func _rebind_players() -> void:
	_bind_player(1, p1_device)
	_bind_player(2, p2_device)

func _bind_player(n: int, device: int) -> void:
	var p := "p%d_" % n
	for action in [p + "move_up", p + "move_down", p + "move_left",
			p + "move_right", p + "grab_left", p + "grab_right", p + "power"]:
		_clear_joypad_events(action)
	if device < 0:
		return
	_add_axis(p + "move_up", device, JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(p + "move_down", device, JOY_AXIS_LEFT_Y, 1.0)
	_add_axis(p + "move_left", device, JOY_AXIS_LEFT_X, -1.0)
	_add_axis(p + "move_right", device, JOY_AXIS_LEFT_X, 1.0)
	_add_button(p + "grab_left", device, 0)   # panel Button 1
	_add_button(p + "grab_right", device, 1)  # panel Button 2
	_add_button(p + "power", device, 2)       # panel Button 3 = use power-up

func _clear_joypad_events(action: String) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			InputMap.action_erase_event(action, ev)

func _add_button(action: String, device: int, index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = index as JoyButton
	InputMap.action_add_event(action, ev)

func _add_axis(action: String, device: int, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
