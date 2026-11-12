class_name MobileControls
extends Control
## Multi-touch controls, drawn in code.
##  LEFT: floating virtual joystick (touch anywhere on the left side).
##  RIGHT: Jump button, Use (interact) button, and a camera-drag area (pinch = zoom).
## Drives Input actions (move_*, run, jump, interact) and GameInput.look_delta / zoom_delta.
## With emulate_touch_from_mouse enabled, the mouse also works in the editor.

const JOY_RADIUS: float = 95.0
const TOP_MARGIN: float = 84.0
const BTN_RADIUS: float = 64.0
const RUN_THRESHOLD: float = 0.85

var _joy_touch: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _jump_touch: int = -1
var _use_touch: int = -1
var _cam_touches: Dictionary = {}
var _pinch_last: float = 0.0
var _use_available: bool = false
var _pulse: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameInput.interact_target_changed.connect(_on_target)
	GameInput.touch_reset.connect(_reset_state)
	get_viewport().size_changed.connect(queue_redraw)

func _on_target(prompt: String) -> void:
	_use_available = prompt != ""

func _screen() -> Vector2:
	return get_viewport_rect().size

func _jump_center() -> Vector2:
	var s: Vector2 = _screen()
	return Vector2(s.x - 120.0, s.y - 130.0)

func _use_center() -> Vector2:
	var s: Vector2 = _screen()
	return Vector2(s.x - 270.0, s.y - 95.0)

func _idle_joy_center() -> Vector2:
	var s: Vector2 = _screen()
	return Vector2(JOY_RADIUS + 70.0, s.y - JOY_RADIUS - 60.0)

func _reset_state() -> void:
	_joy_touch = -1
	_jump_touch = -1
	_use_touch = -1
	_cam_touches.clear()
	_set_axes(Vector2.ZERO)
	Input.action_release("run")
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_touch_down(st.index, st.position)
		else:
			_touch_up(st.index)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		_touch_drag(sd.index, sd.position, sd.relative)

func _touch_down(index: int, pos: Vector2) -> void:
	if GameInput.ui_blocking or pos.y < TOP_MARGIN:
		return
	if pos.distance_to(_jump_center()) <= BTN_RADIUS * 1.25 and _jump_touch == -1:
		_jump_touch = index
		Input.action_press("jump")
	elif pos.distance_to(_use_center()) <= BTN_RADIUS * 1.15 and _use_touch == -1:
		_use_touch = index
		Input.action_press("interact")
	elif pos.x < _screen().x * 0.42 and _joy_touch == -1:
		_joy_touch = index
		_joy_origin = pos
		_joy_pos = pos
	elif pos.x >= _screen().x * 0.42:
		_cam_touches[index] = pos
		if _cam_touches.size() == 2:
			_pinch_last = _pinch_distance()
	queue_redraw()

func _touch_up(index: int) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		_set_axes(Vector2.ZERO)
		Input.action_release("run")
	elif index == _jump_touch:
		_jump_touch = -1
		_release_later("jump")
	elif index == _use_touch:
		_use_touch = -1
		_release_later("interact")
	elif _cam_touches.has(index):
		_cam_touches.erase(index)
	queue_redraw()

func _release_later(action_name: String) -> void:
	# Keep the action down for a few frames so a very short tap is never missed.
	get_tree().create_timer(0.09).timeout.connect(func() -> void: Input.action_release(action_name))

func _touch_drag(index: int, pos: Vector2, rel: Vector2) -> void:
	if index == _joy_touch:
		_joy_pos = pos
		var v: Vector2 = (pos - _joy_origin) / JOY_RADIUS
		if v.length() > 1.0:
			v = v.normalized()
			_joy_origin = pos - v * JOY_RADIUS
		_set_axes(v)
		if v.length() >= RUN_THRESHOLD:
			Input.action_press("run")
		else:
			Input.action_release("run")
		queue_redraw()
	elif _cam_touches.has(index):
		_cam_touches[index] = pos
		if _cam_touches.size() >= 2:
			var d: float = _pinch_distance()
			GameInput.zoom_delta.emit(-(d - _pinch_last) * 0.02)
			_pinch_last = d
		else:
			GameInput.look_delta.emit(rel)

func _pinch_distance() -> float:
	var pts: Array = _cam_touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)

func _set_axes(v: Vector2) -> void:
	var dz: float = 0.12
	_axis("move_left", "move_right", v.x, dz)
	_axis("move_forward", "move_back", v.y, dz)

func _axis(neg: String, pos_action: String, value: float, dead: float) -> void:
	if value < -dead:
		Input.action_press(neg, minf(-value, 1.0))
		Input.action_release(pos_action)
	elif value > dead:
		Input.action_press(pos_action, minf(value, 1.0))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos_action)

func _process(delta: float) -> void:
	if _use_available:
		_pulse += delta * 4.0
		queue_redraw()

func _draw() -> void:
	var cream: Color = Color(1.0, 0.95, 0.8)
	var gold: Color = Color(0.95, 0.75, 0.3)
	# joystick
	var base_c: Vector2 = _joy_origin if _joy_touch != -1 else _idle_joy_center()
	var knob_c: Vector2 = _joy_pos if _joy_touch != -1 else base_c
	var a: float = 0.45 if _joy_touch != -1 else 0.22
	draw_circle(base_c, JOY_RADIUS, Color(0.0, 0.0, 0.0, a * 0.6))
	draw_arc(base_c, JOY_RADIUS, 0.0, TAU, 48, Color(cream.r, cream.g, cream.b, a + 0.2), 3.0)
	draw_circle(knob_c, 40.0, Color(cream.r, cream.g, cream.b, a + 0.25))
	# jump
	var jc: Vector2 = _jump_center()
	var jp: bool = _jump_touch != -1
	draw_circle(jc, BTN_RADIUS, Color(0.0, 0.0, 0.0, 0.5 if jp else 0.3))
	draw_arc(jc, BTN_RADIUS, 0.0, TAU, 40, Color(cream.r, cream.g, cream.b, 0.8), 3.0)
	_label(jc, "JUMP", 22, cream)
	# use
	var uc: Vector2 = _use_center()
	var up: bool = _use_touch != -1
	var glow: float = 0.5 + 0.5 * sin(_pulse) if _use_available else 0.0
	draw_circle(uc, BTN_RADIUS * 0.85, Color(0.35, 0.2, 0.05, 0.75 if _use_available else 0.28) if not up else Color(0.6, 0.35, 0.1, 0.9))
	draw_arc(uc, BTN_RADIUS * 0.85 + 2.0 + glow * 4.0, 0.0, TAU, 40, Color(gold.r, gold.g, gold.b, 0.35 + 0.6 * float(_use_available)), 3.0 + glow * 2.0)
	_label(uc, "USE", 22, cream if _use_available else Color(cream.r, cream.g, cream.b, 0.5))

func _label(centre: Vector2, text_in: String, font_size: int, col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var w: Vector2 = font.get_string_size(text_in, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	draw_string(font, centre + Vector2(-w.x * 0.5, w.y * 0.3), text_in, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, col)
