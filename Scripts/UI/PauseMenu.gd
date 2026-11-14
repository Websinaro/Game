class_name PauseMenu
extends Control
## Pause menu (process mode ALWAYS). Also pauses automatically when the app is
## backgrounded and handles the Android Back button.

var enabled_in_game: bool = false
var _quality_button: Button
var _gfx_info: Label
var _difficulty_button: Button
var _difficulty_note: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title: Label = GameHUD.make_label("PAUSED", 44, Color(0.98, 0.78, 0.32))
	title.custom_minimum_size = Vector2(520.0, 0.0)
	box.add_child(title)
	var resume: Button = GameHUD.make_button("Resume", Vector2(340.0, 58.0), 26)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(close)
	box.add_child(resume)
	_quality_button = GameHUD.make_button("Graphics: AUTO", Vector2(340.0, 58.0), 24)
	_quality_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quality_button.pressed.connect(_cycle_quality)
	box.add_child(_quality_button)
	_gfx_info = GameHUD.make_label("", 16, Color(0.8, 0.9, 0.95))
	_gfx_info.custom_minimum_size = Vector2(760.0, 0.0)
	box.add_child(_gfx_info)
	_difficulty_button = GameHUD.make_button("Difficulty: Normal", Vector2(340.0, 58.0), 24)
	_difficulty_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_difficulty_button.pressed.connect(_toggle_difficulty)
	box.add_child(_difficulty_button)
	_difficulty_note = GameHUD.make_label("", 16, Color(0.95, 0.8, 0.45))
	_difficulty_note.custom_minimum_size = Vector2(760.0, 0.0)
	box.add_child(_difficulty_note)
	var restart: Button = GameHUD.make_button("Restart", Vector2(340.0, 58.0), 24)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(_restart)
	box.add_child(restart)
	var quit: Button = GameHUD.make_button("Quit", Vector2(340.0, 58.0), 24)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	var help: Label = GameHUD.make_label("Left side: move (push far to run)   Right side: drag to look, pinch to zoom\nJUMP / USE buttons   Keyboard: WASD, Shift, Space, E, Q/R, Esc", 18, Color(0.85, 0.85, 0.8))
	help.custom_minimum_size = Vector2(760.0, 0.0)
	box.add_child(help)
	_refresh_buttons()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		open()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	if not enabled_in_game or visible:
		return
	GameInput.release_touch_actions()
	_refresh_buttons()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _refresh_buttons() -> void:
	_quality_button.text = "Graphics: " + GraphicsManager.mode_name() + (" (" + GraphicsManager.preset_name() + ")" if GraphicsManager.mode == GraphicsManager.MODE_AUTO else "")
	_gfx_info.text = GraphicsManager.get_status_text()
	_difficulty_button.text = "Difficulty: " + GameSettings.difficulty_name()
	_difficulty_note.text = "Stamina, water, slopes, rockfall and beacons change at once.\nPuzzle and fragments change after Restart."

func _cycle_quality() -> void:
	GraphicsManager.cycle_mode()
	_refresh_buttons()

func _toggle_difficulty() -> void:
	var next: int = GameSettings.DIFFICULTY_NORMAL if GameSettings.is_hard() else GameSettings.DIFFICULTY_HARD
	GameSettings.set_difficulty(next)
	_refresh_buttons()

func _restart() -> void:
	get_tree().paused = false
	QuestManager.reset()
	StoryManager.flags.clear()
	StoryManager.lore_open = false
	GameInput.ui_blocking = false
	get_tree().reload_current_scene()
