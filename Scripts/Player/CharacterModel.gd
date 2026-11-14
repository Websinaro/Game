class_name CharacterModel
extends Node3D
## Script for $ModelRoot in Player.tscn. PlayerController rotates ModelRoot (yaw only) and
## calls update_motion() every physics frame and reach_for_axe() from the intro cinematic.
##
## At start it loads your glb (model_path), fits it to the capsule (auto-scale to target_height,
## feet at y = 0, centred, yaw fixed so he faces Godot forward = -Z) and drives its animations.
## If the glb is missing or fails to load, it prints an error and uses the procedural
## ParashuramaModel instead, so the game always runs.
##
## Node layout it builds:  ModelRoot (this) > MotionRig (procedural bob/lean) > Fit (scale/offset/yaw) > glb scene

const IDLE_KEYS: Array[String] = ["idle", "stand", "breath", "wait"]
const WALK_KEYS: Array[String] = ["walk"]
const RUN_KEYS: Array[String] = ["run", "sprint", "jog"]
const JUMP_KEYS: Array[String] = ["jump", "leap", "air", "fall"]
const REACH_KEYS: Array[String] = ["reach", "axe", "draw"]

const STATE_NONE: int = -1
const STATE_IDLE: int = 0
const STATE_WALK: int = 1
const STATE_RUN: int = 2
const STATE_JUMP: int = 3

@export var model_path: String = "res://Assets/Models/parashurama.glb"
@export var use_glb: bool = true   ## untick to force the procedural fallback model

@export_group("Fit (adjust here if he is the wrong size, rotation or position)")
@export var auto_fit: bool = true
@export var target_height: float = 2.4
@export var scale_multiplier: float = 1.0     ## extra scale on top of auto-fit (or the whole scale when auto_fit is off)
@export var yaw_degrees: float = 180.0        ## glTF models face +Z, Godot forward is -Z. If he walks backwards set 0.
@export var auto_fix_z_up: bool = true        ## rotates models that lie on their back (Z-up export)
@export var center_horizontally: bool = true
@export var manual_offset: Vector3 = Vector3.ZERO   ## added after auto-fit (metres)

@export_group("Animation names (case-insensitive; blank = auto-detect by keyword)")
@export var anim_idle: String = "idle"
@export var anim_walk: String = "walk"
@export var anim_run: String = "run"
@export var anim_jump: String = "jump"
@export var anim_reach: String = "reach"
@export var blend_time: float = 0.2
@export var run_speed_threshold: float = 5.0  ## speed (m/s) above which the run animation is used
@export var walk_anim_ref_speed: float = 3.4  ## walk animation plays at normal speed at this ground speed
@export var run_anim_ref_speed: float = 6.8
@export var air_time_before_jump_anim: float = 0.12

@export_group("Procedural motion (used when the glb has no animation for a state)")
@export var bob_amount: float = 0.045
@export var lean_amount: float = 0.16
@export var sway_amount: float = 0.07
@export var twist_amount: float = 0.06

@export_group("Reach for axe fallback (no reach animation)")
@export var right_arm_bone_hint: String = ""  ## exact bone name; blank = auto-detect
@export var reach_arm_angle_degrees: float = 150.0
@export var reach_arm_sign: float = 1.0       ## flip to -1.0 if the arm swings the wrong way
@export var reach_body_lean: float = 0.22

@export_group("Report")
@export var print_report: bool = true
@export var max_recommended_texture_size: int = 2048

var _motion: Node3D = null
var _fit: Node3D = null
var _model: Node3D = null
var _fallback: ParashuramaModel = null
var _anim: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _a_idle: String = ""
var _a_walk: String = ""
var _a_run: String = ""
var _a_jump: String = ""
var _a_reach: String = ""
var _state: int = STATE_NONE
var _air_time: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _bob: float = 0.0
var _lean: float = 0.0
var _sway: float = 0.0
var _twist: float = 0.0
var _reach_t: float = -1.0
var _reach_dur: float = 0.0
var _reach_uses_anim: bool = false
var _reach_bone: int = -1

func _ready() -> void:
	set_process(false)
	if use_glb and _try_load_glb():
		set_process(true)
		return
	_use_fallback()

# ---- loading ------------------------------------------------------------------------------
func _try_load_glb() -> bool:
	if not ResourceLoader.exists(model_path):
		push_error("CharacterModel: model file '%s' not found. Copy parashurama.glb to Assets/Models/ (Godot must import it). Using the procedural fallback model." % model_path)
		return false
	var res: Resource = load(model_path)
	var packed: PackedScene = res as PackedScene
	if packed == null:
		push_error("CharacterModel: '%s' did not load as a scene (import error?). Check the Import tab. Using the procedural fallback model." % model_path)
		return false
	var inst: Node = packed.instantiate()
	var model: Node3D = inst as Node3D
	if model == null:
		push_error("CharacterModel: root of '%s' is not a Node3D. Using the procedural fallback model." % model_path)
		inst.queue_free()
		return false
	_motion = Node3D.new()
	_motion.name = "MotionRig"
	add_child(_motion)
	_fit = Node3D.new()
	_fit.name = "Fit"
	_motion.add_child(_fit)
	_fit.add_child(model)
	_model = model
	_apply_fit()
	_prepare_meshes()
	_setup_skeleton()
	_setup_animation()
	if print_report:
		_print_report()
	return true

func _use_fallback() -> void:
	push_warning("CharacterModel: using procedural ParashuramaModel (glb not used).")
	_fallback = ParashuramaModel.new()
	_fallback.name = "ProceduralModel"
	add_child(_fallback)

# ---- fit: scale, orientation, pivot --------------------------------------------------------
func _apply_fit() -> void:
	var bounds: AABB = _collect_aabb()
	var rot: Basis = Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var z_up_fixed: bool = false
	if bounds.size.y > 0.0001 and auto_fix_z_up and bounds.size.z > bounds.size.y * 1.5 and bounds.size.z >= bounds.size.x:
		rot = rot * Basis(Vector3.RIGHT, -PI * 0.5)
		z_up_fixed = true
	var s: float = scale_multiplier
	var offset: Vector3 = manual_offset
	if auto_fit and bounds.size.y > 0.0001:
		var rotated: AABB = Transform3D(rot, Vector3.ZERO) * bounds
		if rotated.size.y > 0.0001:
			s = target_height / rotated.size.y * scale_multiplier
			var cx: float = rotated.position.x + rotated.size.x * 0.5
			var cz: float = rotated.position.z + rotated.size.z * 0.5
			if not center_horizontally:
				cx = 0.0
				cz = 0.0
			offset = Vector3(-cx * s, -rotated.position.y * s, -cz * s) + manual_offset
	elif auto_fit:
		push_warning("CharacterModel: could not measure the model (no meshes?). Fit skipped; use scale_multiplier / manual_offset.")
	_fit.transform = Transform3D(rot.scaled(Vector3(s, s, s)), offset)
	if print_report:
		print("CharacterModel fit: raw bounds pos=%s size=%s | z_up_fixed=%s | scale=%.4f | offset=%s | yaw=%.0f" % [str(bounds.position), str(bounds.size), str(z_up_fixed), s, str(offset), yaw_degrees])

## Combined AABB of all meshes in the model's own space (before the Fit transform).
func _collect_aabb() -> AABB:
	var result: AABB = AABB()
	var have: bool = false
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf: Transform3D = Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != _fit:
			var n3: Node3D = cur as Node3D
			if n3 != null:
				# Skinned meshes are posed in skeleton space; their own node transform is not used.
				if not (n3 == mi and mi.skin != null):
					xf = n3.transform * xf
			cur = cur.get_parent()
		var box: AABB = xf * mi.get_aabb()
		if have:
			result = result.merge(box)
		else:
			result = box
			have = true
	return result

# ---- meshes: shadows, culling, texture check -------------------------------------------------
func _prepare_meshes() -> void:
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.extra_cull_margin = 1.0   # skinned meshes can pop out of view if their AABB is stale

# ---- skeleton / animation ------------------------------------------------------------------------
func _setup_skeleton() -> void:
	var skels: Array[Node] = _model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	_skeleton = skels[0] as Skeleton3D

func _setup_animation() -> void:
	var players: Array[Node] = _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0] as AnimationPlayer
	_a_idle = _resolve(anim_idle, IDLE_KEYS)
	_a_walk = _resolve(anim_walk, WALK_KEYS)
	_a_run = _resolve(anim_run, RUN_KEYS)
	_a_jump = _resolve(anim_jump, JUMP_KEYS)
	_a_reach = _resolve(anim_reach, REACH_KEYS)
	if _a_walk == "":
		_a_walk = _a_run
	if _a_run == "":
		_a_run = _a_walk
	for looped: String in [_a_idle, _a_walk, _a_run]:
		if looped != "" and _anim.has_animation(looped):
			_anim.get_animation(looped).loop_mode = Animation.LOOP_LINEAR

func _resolve(wanted: String, keywords: Array[String]) -> String:
	if _anim == null:
		return ""
	var names: PackedStringArray = _anim.get_animation_list()
	if wanted != "":
		for exact: String in names:
			if exact.to_lower() == wanted.to_lower():
				return exact
	for candidate: String in names:
		var low: String = candidate.to_lower()
		for key: String in keywords:
			if low.contains(key):
				return candidate
	return ""

# ---- per-frame interface used by PlayerController -------------------------------------------------
func update_motion(speed: float, grounded: bool, delta: float) -> void:
	if _fallback != null:
		_fallback.update_motion(speed, grounded, delta)
		return
	if _model == null:
		return
	_time += delta
	if grounded:
		_air_time = 0.0
	else:
		_air_time += delta
	if _reach_t >= 0.0:
		return   # the reach pose owns the body while it plays
	var wanted: int = STATE_IDLE
	if _air_time > air_time_before_jump_anim:
		wanted = STATE_JUMP
	elif speed >= run_speed_threshold:
		wanted = STATE_RUN
	elif speed > 0.25:
		wanted = STATE_WALK
	var played: bool = false
	if _anim != null:
		if wanted != _state:
			_state = wanted
			_play_state(wanted)
		played = _state_animation(_state) != ""
		if played and (_state == STATE_WALK or _state == STATE_RUN):
			var ref: float = walk_anim_ref_speed if _state == STATE_WALK else run_anim_ref_speed
			_anim.speed_scale = clampf(speed / maxf(ref, 0.1), 0.6, 1.6)
	else:
		_state = wanted
	_update_procedural(speed, grounded, delta, played)

func _state_animation(state: int) -> String:
	match state:
		STATE_IDLE:
			return _a_idle
		STATE_WALK:
			return _a_walk
		STATE_RUN:
			return _a_run
		STATE_JUMP:
			return _a_jump
	return ""

func _play_state(state: int) -> void:
	var anim_name: String = _state_animation(state)
	if anim_name == "":
		_anim.stop()
		return
	_anim.speed_scale = 1.0
	_anim.play(anim_name, blend_time)

## Simple bob / lean / sway. Fully applied when the glb has no animation for the current state.
func _update_procedural(speed: float, grounded: bool, delta: float, has_animation: bool) -> void:
	var amount: float = clampf(speed / 6.5, 0.0, 1.0)
	if has_animation:
		amount = 0.0
	_phase += delta * (speed * 1.5 + 1.0)
	var k: float = 1.0 - exp(-12.0 * delta)
	var bob_t: float = absf(sin(_phase)) * bob_amount * amount
	var lean_t: float = lean_amount * amount
	var sway_t: float = sin(_phase) * sway_amount * amount
	var twist_t: float = sin(_phase) * twist_amount * amount
	if not grounded and not has_animation:
		lean_t += 0.08
		bob_t += 0.04
	if not has_animation:
		bob_t += sin(_time * 1.8) * 0.006
	_bob = lerpf(_bob, bob_t, k)
	_lean = lerpf(_lean, lean_t, k)
	_sway = lerpf(_sway, sway_t, k)
	_twist = lerpf(_twist, twist_t, k)
	_motion.position.y = _bob
	_motion.rotation = Vector3(-_lean, _twist, _sway)

# ---- reach for axe (intro cinematic) ---------------------------------------------------------------
func reach_for_axe(duration: float) -> void:
	if _fallback != null:
		_fallback.reach_for_axe(duration)
		return
	if _model == null:
		return
	_reach_dur = maxf(duration, 0.2)
	_reach_t = 0.0
	_reach_uses_anim = false
	_reach_bone = -1
	if _anim != null and _a_reach != "":
		_reach_uses_anim = true
		var length: float = _anim.get_animation(_a_reach).length
		_anim.play(_a_reach, blend_time)
		_anim.speed_scale = clampf(length / _reach_dur, 0.25, 3.0)
		return
	if _skeleton != null:
		_reach_bone = _find_right_arm_bone()
		if _reach_bone >= 0 and _anim != null:
			_anim.pause()   # otherwise the playing animation overwrites the bone every frame
	if _reach_bone < 0 and print_report:
		print("CharacterModel: no reach animation and no right-arm bone found; using a body lean only.")

func _process(delta: float) -> void:
	if _reach_t < 0.0:
		return
	_reach_t += delta
	var p: float = clampf(_reach_t / _reach_dur, 0.0, 1.0)
	if _reach_uses_anim:
		if _reach_t >= _reach_dur:
			_finish_reach()
		return
	# profile: rise 0..0.35, hold 0.35..0.7, return 0.7..1
	var prof: float = 0.0
	if p < 0.35:
		prof = sin(p / 0.35 * PI * 0.5)
	elif p < 0.7:
		prof = 1.0
	else:
		prof = cos((p - 0.7) / 0.3 * PI * 0.5)
	_motion.rotation = Vector3(reach_body_lean * prof, 0.0, 0.0)
	if _reach_bone >= 0:
		_pose_arm(prof * deg_to_rad(reach_arm_angle_degrees) * reach_arm_sign)
	if p >= 1.0:
		_finish_reach()

func _finish_reach() -> void:
	_reach_t = -1.0
	if _skeleton != null and _reach_bone >= 0:
		_skeleton.reset_bone_pose(_reach_bone)
	_reach_bone = -1
	_motion.rotation = Vector3.ZERO
	_state = STATE_NONE   # forces the locomotion animation to start again
	if _anim != null:
		_anim.speed_scale = 1.0

## Rotates the arm bone about the model's forward axis (skeleton space), assuming a rest/T-pose.
func _pose_arm(angle: float) -> void:
	var parent: int = _skeleton.get_bone_parent(_reach_bone)
	var parent_basis: Basis = Basis.IDENTITY
	if parent >= 0:
		parent_basis = _skeleton.get_bone_global_pose(parent).basis
	var rest_basis: Basis = _skeleton.get_bone_rest(_reach_bone).basis
	var swing: Basis = Basis(Vector3(0.0, 0.0, 1.0), angle)
	var local_swing: Basis = parent_basis.inverse() * swing * parent_basis
	var q: Quaternion = (local_swing * rest_basis).get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(_reach_bone, q)

func _find_right_arm_bone() -> int:
	if right_arm_bone_hint != "":
		var hinted: int = _skeleton.find_bone(right_arm_bone_hint)
		if hinted >= 0:
			return hinted
	for i in range(_skeleton.get_bone_count()):
		var low: String = _skeleton.get_bone_name(i).to_lower()
		var is_right: bool = low.contains("right") or low.ends_with("_r") or low.ends_with(".r") or low.begins_with("r_") or low.begins_with("r.")
		var is_upper_arm: bool = low.contains("upperarm") or low.contains("upper_arm") or (low.contains("arm") and not low.contains("fore") and not low.contains("lower") and not low.contains("hand"))
		if is_right and is_upper_arm:
			return i
	return -1

# ---- report (visible in the Godot Output / Debugger panel) -----------------------------------------
func _print_report() -> void:
	print("---- CharacterModel report: %s ----" % model_path)
	var mesh_count: int = 0
	var tris: int = 0
	var worst_tex: int = 0
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mesh_count += 1
		var am: ArrayMesh = mi.mesh as ArrayMesh
		for s in range(mi.mesh.get_surface_count()):
			if am != null:
				var idx: int = am.surface_get_array_index_len(s)
				var count: int = idx if idx > 0 else am.surface_get_array_len(s)
				tris += int(float(count) / 3.0)
			var mat: Material = mi.get_active_material(s)
			var bm: BaseMaterial3D = mat as BaseMaterial3D
			if bm == null:
				continue
			for slot in range(BaseMaterial3D.TEXTURE_MAX):
				var tex: Texture2D = bm.get_texture(slot as BaseMaterial3D.TextureParam)
				if tex == null:
					continue
				var biggest: int = maxi(tex.get_width(), tex.get_height())
				worst_tex = maxi(worst_tex, biggest)
				if biggest > max_recommended_texture_size:
					push_warning("CharacterModel: texture %dx%d on mesh '%s' is large for phones. Import tab: Process > Size Limit = %d, VRAM compression on, Mipmaps on." % [tex.get_width(), tex.get_height(), mi.name, max_recommended_texture_size])
	print("meshes=%d  triangles~%d  largest texture=%d px" % [mesh_count, tris, worst_tex])
	if _skeleton != null:
		print("skeleton '%s' with %d bones" % [_skeleton.name, _skeleton.get_bone_count()])
	else:
		print("no Skeleton3D found")
	if _anim == null:
		print("no AnimationPlayer: procedural walk bob / lean / sway will be used")
	else:
		for anim_name: String in _anim.get_animation_list():
			print("animation '%s'  %.2f s  loop_mode=%d" % [anim_name, _anim.get_animation(anim_name).length, int(_anim.get_animation(anim_name).loop_mode)])
		print("mapped: idle='%s' walk='%s' run='%s' jump='%s' reach='%s'" % [_a_idle, _a_walk, _a_run, _a_jump, _a_reach])
	print("---- end report ----")
