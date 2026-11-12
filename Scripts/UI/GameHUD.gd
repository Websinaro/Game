class_name GameHUD
extends Control
## Heads-up display, built in code so layout stays resolution independent
## (canvas_items stretch, 720 px design height).
## TOP: objective + pause button + region banner. BOTTOM: story notifications + use prompt.
## Also hosts the lore panel and the phase-complete screen.

signal pause_requested

var _objective_label: Label
var _notify_label: Label
var _prompt_label: Label
var _region_label: Label
var _lore_panel: PanelContainer
var _lore_title: Label
var _lore_body: Label
var _complete_overlay: ColorRect
var _complete_title: Label
var _complete_banner: Label
var _complete_sub: Label
var _notify_tween: Tween = null
var _region_tween: Tween = null

static func make_style(bg: Color, border: Color, radius: int, margin: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb

static func make_button(text_in: String, min_size: Vector2, font_size: int) -> Button:
	var b: Button = Button.new()
	b.text = text_in
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	b.add_theme_stylebox_override("normal", make_style(Color(0.20, 0.10, 0.05, 0.9), Color(0.85, 0.65, 0.25), 12, 10.0))
	b.add_theme_stylebox_override("hover", make_style(Color(0.32, 0.17, 0.08, 0.95), Color(1.0, 0.8, 0.35), 12, 10.0))
	b.add_theme_stylebox_override("pressed", make_style(Color(0.45, 0.25, 0.10, 1.0), Color(1.0, 0.9, 0.5), 12, 10.0))
	b.focus_mode = Control.FOCUS_NONE
	return b

static func make_label(text_in: String, font_size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = text_in
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_objective()
	_build_pause_button()
	_build_bottom()
	_build_lore_panel()
	_build_complete_overlay()
	QuestManager.objective_changed.connect(_on_objective_changed)
	QuestManager.objective_notice.connect(show_notification)
	StoryManager.lore_requested.connect(_on_lore_requested)
	StoryManager.phase_complete.connect(_on_phase_complete)
	GameInput.interact_target_changed.connect(_on_interact_target)

func _build_objective() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -290.0
	panel.offset_right = 290.0
	panel.offset_top = 12.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", make_style(Color(0.07, 0.05, 0.03, 0.72), Color(0.85, 0.65, 0.25, 0.9), 10, 8.0))
	add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var head: Label = make_label("OBJECTIVE", 15, Color(0.95, 0.75, 0.3))
	box.add_child(head)
	_objective_label = make_label("", 21, Color(1.0, 0.97, 0.88))
	_objective_label.custom_minimum_size = Vector2(540.0, 0.0)
	box.add_child(_objective_label)
	panel.visible = false
	_objective_label.set_meta("panel", panel)

func _build_pause_button() -> void:
	var b: Button = make_button("II", Vector2(72.0, 60.0), 28)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -92.0
	b.offset_right = -20.0
	b.offset_top = 14.0
	b.offset_bottom = 74.0
	b.pressed.connect(func() -> void: pause_requested.emit())
	add_child(b)

func _build_bottom() -> void:
	_notify_label = make_label("", 22, Color(1.0, 0.95, 0.8))
	_notify_label.anchor_left = 0.5
	_notify_label.anchor_right = 0.5
	_notify_label.anchor_top = 1.0
	_notify_label.anchor_bottom = 1.0
	_notify_label.offset_left = -330.0
	_notify_label.offset_right = 330.0
	_notify_label.offset_top = -72.0
	_notify_label.offset_bottom = -20.0
	_notify_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notify_label.modulate.a = 0.0
	_notify_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notify_label)
	_prompt_label = make_label("", 24, Color(1.0, 0.85, 0.4))
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -260.0
	_prompt_label.offset_right = 260.0
	_prompt_label.offset_top = -130.0
	_prompt_label.offset_bottom = -84.0
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_label)
	_region_label = make_label("", 34, Color(1.0, 0.92, 0.7))
	_region_label.anchor_left = 0.5
	_region_label.anchor_right = 0.5
	_region_label.offset_left = -300.0
	_region_label.offset_right = 300.0
	_region_label.offset_top = 128.0
	_region_label.offset_bottom = 176.0
	_region_label.modulate.a = 0.0
	_region_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_region_label)

func _build_lore_panel() -> void:
	_lore_panel = PanelContainer.new()
	_lore_panel.anchor_left = 0.5
	_lore_panel.anchor_right = 0.5
	_lore_panel.anchor_top = 0.5
	_lore_panel.anchor_bottom = 0.5
	_lore_panel.offset_left = -380.0
	_lore_panel.offset_right = 380.0
	_lore_panel.offset_top = -10.0
	_lore_panel.offset_bottom = -10.0
	_lore_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lore_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_lore_panel.add_theme_stylebox_override("panel", make_style(Color(0.08, 0.06, 0.04, 0.94), Color(0.9, 0.7, 0.3), 14, 20.0))
	_lore_panel.visible = false
	add_child(_lore_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_lore_panel.add_child(box)
	_lore_title = make_label("", 30, Color(0.98, 0.78, 0.32))
	box.add_child(_lore_title)
	_lore_body = make_label("", 23, Color(1.0, 0.97, 0.9))
	_lore_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_lore_body.custom_minimum_size = Vector2(700.0, 0.0)
	box.add_child(_lore_body)
	var ok: Button = make_button("Continue", Vector2(220.0, 62.0), 26)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_close_lore)
	box.add_child(ok)

func _build_complete_overlay() -> void:
	_complete_overlay = ColorRect.new()
	_complete_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	_complete_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_complete_overlay.visible = false
	add_child(_complete_overlay)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 22)
	_complete_overlay.add_child(box)
	_complete_title = make_label("", 28, Color(0.95, 0.75, 0.3))
	_complete_title.custom_minimum_size = Vector2(820.0, 0.0)
	box.add_child(_complete_title)
	_complete_banner = make_label("", 48, Color(1.0, 0.95, 0.8))
	_complete_banner.custom_minimum_size = Vector2(820.0, 0.0)
	box.add_child(_complete_banner)
	_complete_sub = make_label("", 22, Color(0.9, 0.9, 0.85))
	_complete_sub.custom_minimum_size = Vector2(820.0, 0.0)
	box.add_child(_complete_sub)
	var ok: Button = make_button("Keep exploring", Vector2(280.0, 64.0), 26)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_close_complete)
	box.add_child(ok)

# ---- public --------------------------------------------------------------------------------
func show_notification(text_in: String) -> void:
	if text_in == "":
		return
	_notify_label.text = text_in
	if _notify_tween != null and _notify_tween.is_valid():
		_notify_tween.kill()
	_notify_tween = create_tween()
	_notify_tween.tween_property(_notify_label, "modulate:a", 1.0, 0.3)
	_notify_tween.tween_interval(4.5)
	_notify_tween.tween_property(_notify_label, "modulate:a", 0.0, 0.8)

func show_region_banner(region_name: String) -> void:
	_region_label.text = region_name
	if _region_tween != null and _region_tween.is_valid():
		_region_tween.kill()
	_region_tween = create_tween()
	_region_tween.tween_property(_region_label, "modulate:a", 1.0, 0.6)
	_region_tween.tween_interval(2.5)
	_region_tween.tween_property(_region_label, "modulate:a", 0.0, 1.0)

# ---- signal handlers ---------------------------------------------------------------------------
func _on_objective_changed(text_in: String) -> void:
	_objective_label.text = text_in
	var panel: Control = _objective_label.get_meta("panel") as Control
	panel.visible = text_in != ""

func _on_interact_target(prompt: String) -> void:
	_prompt_label.text = "" if prompt == "" else "USE: " + prompt

func _on_lore_requested(title_in: String, body_in: String) -> void:
	_lore_title.text = title_in
	_lore_body.text = body_in
	_lore_panel.visible = true
	GameInput.ui_blocking = true
	GameInput.release_touch_actions()

func _close_lore() -> void:
	_lore_panel.visible = false
	GameInput.ui_blocking = false
	StoryManager.notify_lore_closed()

func _on_phase_complete(title_in: String, banner: String, subtitle: String) -> void:
	_complete_title.text = title_in
	_complete_banner.text = banner
	_complete_sub.text = subtitle
	_complete_overlay.modulate.a = 0.0
	_complete_overlay.visible = true
	GameInput.ui_blocking = true
	GameInput.release_touch_actions()
	var tw: Tween = create_tween()
	tw.tween_property(_complete_overlay, "modulate:a", 1.0, 1.6)

func _close_complete() -> void:
	_complete_overlay.visible = false
	GameInput.ui_blocking = false
