extends Node
## Autoload "GameInput".
## - Registers every input action in code (keyboard for editor testing).
## - Acts as the event bus between touch UI, camera, player and HUD.
## Touch controls drive the same actions with Input.action_press(), so the
## player script only ever reads Input actions.

@warning_ignore("unused_signal")
signal look_delta(delta: Vector2)
@warning_ignore("unused_signal")
signal zoom_delta(amount: float)
@warning_ignore("unused_signal")
signal interact_target_changed(prompt: String)
@warning_ignore("unused_signal")
signal touch_reset()

## True while a modal panel (lore, phase complete) is open; touch controls ignore new touches.
var ui_blocking: bool = false

const TOUCH_ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "run", "jump", "interact"
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_action("move_forward", PackedInt32Array([KEY_W, KEY_UP]))
	_add_action("move_back", PackedInt32Array([KEY_S, KEY_DOWN]))
	_add_action("move_left", PackedInt32Array([KEY_A, KEY_LEFT]))
	_add_action("move_right", PackedInt32Array([KEY_D, KEY_RIGHT]))
	_add_action("jump", PackedInt32Array([KEY_SPACE]))
	_add_action("run", PackedInt32Array([KEY_SHIFT]))
	_add_action("interact", PackedInt32Array([KEY_E, KEY_F]))
	_add_action("pause", PackedInt32Array([KEY_ESCAPE, KEY_P]))
	_add_action("cam_left", PackedInt32Array([KEY_Q]))
	_add_action("cam_right", PackedInt32Array([KEY_R]))

func _add_action(action_name: String, keys: PackedInt32Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)
	for key_code: int in keys:
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = key_code as Key
		InputMap.action_add_event(action_name, ev)

## Releases every touch-driven action (used when pausing or opening modal UI).
func release_touch_actions() -> void:
	for action_name: String in TOUCH_ACTIONS:
		Input.action_release(action_name)
	touch_reset.emit()
