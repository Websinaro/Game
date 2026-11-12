class_name IntroCinematic
extends Control
## Opening cinematic: ocean -> coastline -> Parashurama arrives -> reaches for the axe ->
## "The axe is gone" -> hand-over to gameplay camera. Fully scripted camera shots, skippable.
## Narration text comes from res://Data/story.json (intro.captions).

signal finished

var _title: Label
var _subtitle: Label
var _caption: Label
var _skipped: bool = false
var _player: PlayerController = null
var _cam: Camera3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	for top_bar in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top_bar:
			bar.offset_bottom = 64.0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -64.0
		add_child(bar)
	_title = GameHUD.make_label("", 68, Color(1.0, 0.9, 0.6))
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.offset_top = -80.0
	_title.custom_minimum_size = Vector2(1000.0, 0.0)
	_title.modulate.a = 0.0
	add_child(_title)
	_subtitle = GameHUD.make_label("", 28, Color(1.0, 0.95, 0.85))
	_subtitle.set_anchors_preset(Control.PRESET_CENTER)
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.offset_top = 10.0
	_subtitle.custom_minimum_size = Vector2(1000.0, 0.0)
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)
	_caption = GameHUD.make_label("", 28, Color(1.0, 0.97, 0.9))
	_caption.anchor_left = 0.5
	_caption.anchor_right = 0.5
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = -420.0
	_caption.offset_right = 420.0
	_caption.offset_top = -190.0
	_caption.offset_bottom = -80.0
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_caption.modulate.a = 0.0
	add_child(_caption)
	var skip: Button = GameHUD.make_button("Skip >>", Vector2(150.0, 54.0), 22)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -170.0
	skip.offset_right = -20.0
	skip.offset_top = 76.0
	skip.offset_bottom = 130.0
	skip.pressed.connect(func() -> void: _skipped = true)
	add_child(skip)

func _build_shots(spawn: Vector3) -> Array:
	var caps: Array = StoryManager.get_intro().get("captions", []) as Array
	var gy: float = spawn.y
	var s: Vector3 = spawn
	var back_cam: Vector3 = s + Vector3(0.0, 1.68 + 1.55, 5.12)
	var shots: Array = []
	shots.append({"dur": 4.5, "a": Vector3(20.0, 22.0, 150.0), "b": Vector3(10.0, 14.0, 122.0), "la": Vector3(0.0, 4.0, 40.0), "lb": Vector3(0.0, 4.0, 40.0), "cap": "", "title": true})
	shots.append({"dur": 5.5, "a": Vector3(-60.0, 7.0, 100.0), "b": Vector3(-20.0, 5.0, 80.0), "la": Vector3(0.0, 3.0, 45.0), "lb": Vector3(0.0, 3.0, 45.0), "cap": str(caps[0])})
	shots.append({"dur": 6.5, "a": Vector3(45.0, 3.5, 72.0), "b": Vector3(-30.0, 3.5, 62.0), "la": Vector3(20.0, 4.0, 42.0), "lb": Vector3(-20.0, 4.0, 40.0), "cap": str(caps[1])})
	shots.append({"dur": 6.5, "a": Vector3(-20.0, 4.0, 66.0), "b": Vector3(-10.0, 3.2, 60.0), "la": Vector3(6.0, gy + 1.2, 57.0), "lb": Vector3(1.0, gy + 1.4, 49.0), "cap": str(caps[2]), "actor": "walk"})
	shots.append({"dur": 3.5, "a": s + Vector3(2.4, 2.1, 3.0), "b": s + Vector3(1.6, 1.95, 2.3), "la": s + Vector3(0.0, 1.35, 0.0), "lb": s + Vector3(0.0, 1.45, 0.0), "cap": str(caps[3]), "reach": 6.0})
	shots.append({"dur": 4.5, "a": s + Vector3(-2.6, 1.7, -3.6), "b": s + Vector3(-1.4, 1.65, -2.6), "la": s + Vector3(0.0, 1.55, 0.0), "lb": s + Vector3(0.0, 1.6, 0.0), "cap": str(caps[4])})
	shots.append({"dur": 5.5, "a": s + Vector3(0.0, 2.0, 6.0), "b": s + Vector3(0.0, 6.0, 13.0), "la": s + Vector3(0.0, 1.5, -2.0), "lb": s + Vector3(0.0, 1.5, -2.0), "cap": str(caps[5])})
	shots.append({"dur": 4.5, "a": s + Vector3(0.0, 6.0, 13.0), "b": back_cam, "la": s + Vector3(0.0, 1.5, -2.0), "lb": s + Vector3(0.0, 1.55, 0.0), "cap": str(caps[6])})
	return shots

func play(player: PlayerController, cam: Camera3D, spawn: Vector3) -> void:
	_player = player
	_cam = cam
	_skipped = false
	visible = true
	var intro_data: Dictionary = StoryManager.get_intro()
	_title.text = str(intro_data.get("title", ""))
	_subtitle.text = str(intro_data.get("subtitle", ""))
	cam.make_current()
	var start_pos: Vector3 = Vector3(6.0, TerrainGenerator.height_at(6.0, 58.0), 58.0)
	player.teleport(start_pos, 0.5)
	player.visible = false
	var shots: Array = _build_shots(spawn)
	for shot_variant: Variant in shots:
		if _skipped:
			break
		await _run_shot(shot_variant as Dictionary, spawn, start_pos)
	player.visible = true
	player.teleport(spawn + Vector3(0.0, 0.2, 0.0), 0.0)
	player.camera_rig.yaw = 0.0
	player.camera_rig.pitch = 0.32
	player.camera_rig.snap_to_target()
	player.camera_rig.make_current()
	visible = false
	finished.emit()

func _run_shot(shot: Dictionary, spawn: Vector3, start_pos: Vector3) -> void:
	var dur: float = float(shot["dur"])
	var a: Vector3 = shot["a"] as Vector3
	var b: Vector3 = shot["b"] as Vector3
	var la: Vector3 = shot["la"] as Vector3
	var lb: Vector3 = shot["lb"] as Vector3
	var cap: String = str(shot["cap"])
	var is_title: bool = bool(shot.get("title", false))
	var actor: String = str(shot.get("actor", ""))
	_caption.text = cap
	if actor == "walk":
		_player.visible = true
	elif shot.has("reach"):
		_player.visible = true
		_player.teleport(spawn, 0.0)
		_player.play_reach_for_axe(float(shot["reach"]))
	var elapsed: float = 0.0
	while elapsed < dur and not _skipped:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		elapsed += dt
		var k: float = clampf(elapsed / dur, 0.0, 1.0)
		_cam.global_position = a.lerp(b, k)
		_cam.look_at(la.lerp(lb, k), Vector3.UP)
		_caption.modulate.a = clampf(minf(elapsed / 0.6, (dur - elapsed) / 0.5), 0.0, 1.0)
		if is_title:
			var ta: float = clampf(minf((elapsed - 0.5) / 0.8, (dur - 0.3 - elapsed) / 0.8), 0.0, 1.0)
			_title.modulate.a = ta
			_subtitle.modulate.a = ta
		if actor == "walk":
			var p: Vector3 = start_pos.lerp(spawn, k)
			p.y = TerrainGenerator.height_at(p.x, p.z)
			var d: Vector3 = spawn - start_pos
			_player.scripted_step(p, atan2(-d.x, -d.z), 1.8, dt)
		elif _player.visible:
			_player.scripted_step(spawn, 0.0, 0.0, dt)
	_caption.modulate.a = 0.0
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
