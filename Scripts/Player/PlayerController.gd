class_name PlayerController
extends CharacterBody3D
## Movement + interaction. Reads only Input ACTIONS (keyboard or touch UI).
## The visual model lives under $ModelRoot and is fully separate: replace that node's
## content/script with any Node3D that implements:
##   update_motion(speed: float, grounded: bool, delta: float)
##   reach_for_axe(duration: float)      (optional, used by the intro)
## Difficulty numbers (stamina, water, slopes) come from Tuning.gd via GameSettings.

signal interact_target_changed(prompt: String)

@export var walk_speed: float = 3.4
@export var run_speed: float = 6.8
@export var jump_velocity: float = 5.6
@export var acceleration: float = 26.0
@export var air_control: float = 0.5
@export var turn_speed: float = 11.0
@export var gravity_scale: float = 1.5
@export var knock_friction: float = 7.0

var controls_enabled: bool = false
var stamina: float = Tuning.STAMINA_MAX
var tired: bool = false

var _gravity: float = 9.8
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _target: Interactable = null
var _scan_timer: float = 0.0
var _safe_timer: float = 0.0
var _last_safe: Vector3 = Vector3.ZERO
var _regen_delay: float = 0.0
var _stun: float = 0.0
var _last_ratio_sent: float = -1.0
var _last_tired_sent: bool = false
var _water_notice_cd: float = 0.0

@onready var model_root: Node3D = $ModelRoot
@onready var camera_rig: CameraController = $CameraRig

func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	floor_max_angle = deg_to_rad(44.0)
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	_last_safe = global_position

func teleport(pos: Vector3, facing_yaw: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_last_safe = pos
	model_root.rotation.y = facing_yaw

## Used by cutscenes: places the player and animates the model without physics.
func scripted_step(pos: Vector3, facing_yaw: float, speed: float, delta: float) -> void:
	global_position = pos
	model_root.rotation.y = lerp_angle(model_root.rotation.y, facing_yaw, 1.0 - exp(-8.0 * delta))
	if model_root.has_method("update_motion"):
		model_root.call("update_motion", speed, true, delta)

func play_reach_for_axe(duration: float) -> void:
	if model_root.has_method("reach_for_axe"):
		model_root.call("reach_for_axe", duration)

## Hazards (falling rock etc.) call this. No damage: it shoves, stuns briefly and drains stamina.
func apply_hit(from_direction: Vector3, knock_speed: float, stamina_penalty: float, stun_time: float) -> void:
	var dir: Vector3 = Vector3(from_direction.x, 0.0, from_direction.z)
	if dir.length() < 0.001:
		dir = Vector3(0.0, 0.0, 1.0)
	dir = dir.normalized()
	velocity.x = dir.x * knock_speed
	velocity.z = dir.z * knock_speed
	_stun = stun_time
	stamina = maxf(stamina - stamina_penalty, 0.0)
	_regen_delay = GameSettings.pick_f(Tuning.STAMINA_REGEN_DELAY_NORMAL, Tuning.STAMINA_REGEN_DELAY_HARD)
	if stamina <= 0.0:
		tired = true

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	var stunned: bool = _stun > 0.0
	_stun = maxf(_stun - delta, 0.0)
	_water_notice_cd = maxf(_water_notice_cd - delta, 0.0)
	var input_vec: Vector2 = Vector2.ZERO
	if not stunned:
		input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var move_dir: Vector3 = right * input_vec.x + forward * (-input_vec.y)
	var strength: float = minf(input_vec.length(), 1.0)
	var moving: bool = strength > 0.01
	var running: bool = Input.is_action_pressed("run") and moving and not tired and stamina > 0.0
	var target_speed: float = 0.0
	if moving:
		move_dir = move_dir.normalized()
		target_speed = run_speed if running else walk_speed * maxf(strength, 0.4)
		if tired:
			target_speed *= GameSettings.pick_f(Tuning.TIRED_SPEED_MULT_NORMAL, Tuning.TIRED_SPEED_MULT_HARD)
	_update_stamina(running, moving, delta)

	# Slippery slopes: steep floor pushes you downhill and makes climbing slower.
	var slip_down: Vector3 = Vector3.ZERO
	var slip_factor: float = 0.0
	if is_on_floor():
		var slip_start: float = GameSettings.pick_f(Tuning.SLIP_START_DEG_NORMAL, Tuning.SLIP_START_DEG_HARD)
		var floor_deg: float = rad_to_deg(get_floor_angle())
		if floor_deg > slip_start:
			var max_deg: float = maxf(rad_to_deg(floor_max_angle), slip_start + 1.0)
			slip_factor = clampf((floor_deg - slip_start) / (max_deg - slip_start), 0.0, 1.0)
			var fn: Vector3 = get_floor_normal()
			slip_down = Vector3(fn.x, 0.0, fn.z)
			if slip_down.length() > 0.001:
				slip_down = slip_down.normalized()
				var uphill: float = -move_dir.dot(slip_down)
				if uphill > 0.0:
					target_speed *= 1.0 - GameSettings.pick_f(Tuning.SLIP_UPHILL_PENALTY_NORMAL, Tuning.SLIP_UPHILL_PENALTY_HARD) * slip_factor * uphill
			else:
				slip_factor = 0.0

	# Deep water: slows you down, then a current pushes you back; you cannot wade past the limit.
	var depth: float = Tuning.WATER_SURFACE_Y - TerrainGenerator.height_at(global_position.x, global_position.z)
	var shore_dir: Vector3 = Vector3.ZERO
	var wade_limit: float = GameSettings.pick_f(Tuning.WATER_WADE_LIMIT_NORMAL, Tuning.WATER_WADE_LIMIT_HARD)
	var current_start: float = GameSettings.pick_f(Tuning.WATER_CURRENT_START_NORMAL, Tuning.WATER_CURRENT_START_HARD)
	if depth > 0.15:
		var water_t: float = clampf(depth / wade_limit, 0.0, 1.0)
		target_speed *= 1.0 - GameSettings.pick_f(Tuning.WATER_SLOW_MAX_NORMAL, Tuning.WATER_SLOW_MAX_HARD) * water_t
		shore_dir = _shore_direction(global_position.x, global_position.z)

	var horiz: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var accel: float = acceleration if is_on_floor() else acceleration * air_control
	if stunned:
		horiz = horiz.move_toward(Vector3.ZERO, knock_friction * delta)
	else:
		horiz = horiz.move_toward(move_dir * target_speed, accel * delta)
	if slip_factor > 0.0:
		horiz += slip_down * GameSettings.pick_f(Tuning.SLIP_ACCEL_NORMAL, Tuning.SLIP_ACCEL_HARD) * (0.3 + 0.7 * slip_factor) * delta
		if horiz.length() > Tuning.SLIP_MAX_SPEED:
			horiz = horiz.normalized() * Tuning.SLIP_MAX_SPEED
	if shore_dir != Vector3.ZERO and depth > current_start:
		var k: float = clampf((depth - current_start) / maxf(wade_limit - current_start, 0.05), 0.0, 1.5)
		var surge: float = 0.75 + 0.25 * sin(float(Time.get_ticks_msec()) * 0.0015)
		var push: float = GameSettings.pick_f(Tuning.WATER_CURRENT_PUSH_NORMAL, Tuning.WATER_CURRENT_PUSH_HARD)
		horiz += shore_dir * push * k * surge * delta
		if depth >= wade_limit:
			var into_deep: float = -horiz.dot(shore_dir)
			if into_deep > 0.0:
				horiz += shore_dir * into_deep
			if _water_notice_cd <= 0.0:
				_water_notice_cd = Tuning.WATER_NOTICE_COOLDOWN
				GameInput.notice.emit("The current is too strong. The sea will not let you pass.")
	velocity.x = horiz.x
	velocity.z = horiz.z

	if is_on_floor():
		_coyote = 0.12
	else:
		_coyote -= delta
		velocity.y -= _gravity * gravity_scale * delta
	_jump_buffer -= delta
	if Input.is_action_just_pressed("jump") and not stunned:
		_jump_buffer = 0.12
	if _jump_buffer > 0.0 and _coyote > 0.0:
		var jump_mult: float = 1.0
		if tired:
			jump_mult = GameSettings.pick_f(Tuning.TIRED_JUMP_MULT_NORMAL, Tuning.TIRED_JUMP_MULT_HARD)
		velocity.y = jump_velocity * jump_mult
		_jump_buffer = 0.0
		_coyote = 0.0
		stamina = maxf(stamina - GameSettings.pick_f(Tuning.JUMP_STAMINA_COST_NORMAL, Tuning.JUMP_STAMINA_COST_HARD), 0.0)
		_regen_delay = GameSettings.pick_f(Tuning.STAMINA_REGEN_DELAY_NORMAL, Tuning.STAMINA_REGEN_DELAY_HARD)
		if stamina <= 0.0:
			tired = true
	move_and_slide()
	if move_dir != Vector3.ZERO and not stunned:
		var target_yaw: float = atan2(-move_dir.x, -move_dir.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	if model_root.has_method("update_motion"):
		model_root.call("update_motion", Vector3(velocity.x, 0.0, velocity.z).length(), is_on_floor(), delta)
	_update_interaction(delta)
	_safety(delta)

## Unit vector on the ground plane pointing UPHILL (towards shallower water / the shore).
func _shore_direction(x: float, z: float) -> Vector3:
	var e: float = 1.5
	var gx: float = TerrainGenerator.height_at(x + e, z) - TerrainGenerator.height_at(x - e, z)
	var gz: float = TerrainGenerator.height_at(x, z + e) - TerrainGenerator.height_at(x, z - e)
	var g: Vector3 = Vector3(gx, 0.0, gz)
	if g.length() < 0.001:
		return Vector3(0.0, 0.0, -1.0)
	return g.normalized()

func _update_stamina(running: bool, moving: bool, delta: float) -> void:
	if running:
		stamina = maxf(stamina - GameSettings.pick_f(Tuning.STAMINA_DRAIN_NORMAL, Tuning.STAMINA_DRAIN_HARD) * delta, 0.0)
		_regen_delay = GameSettings.pick_f(Tuning.STAMINA_REGEN_DELAY_NORMAL, Tuning.STAMINA_REGEN_DELAY_HARD)
		if stamina <= 0.0:
			tired = true
	else:
		_regen_delay -= delta
		if _regen_delay <= 0.0:
			var regen: float = GameSettings.pick_f(Tuning.STAMINA_REGEN_NORMAL, Tuning.STAMINA_REGEN_HARD)
			if not moving:
				regen *= Tuning.STAMINA_STILL_REGEN_MULT
			stamina = minf(stamina + regen * delta, Tuning.STAMINA_MAX)
	if tired and stamina >= GameSettings.pick_f(Tuning.STAMINA_RECOVER_AT_NORMAL, Tuning.STAMINA_RECOVER_AT_HARD):
		tired = false
	var ratio: float = stamina / Tuning.STAMINA_MAX
	if absf(ratio - _last_ratio_sent) > 0.004 or tired != _last_tired_sent:
		_last_ratio_sent = ratio
		_last_tired_sent = tired
		GameInput.stamina_changed.emit(ratio, tired)

func _update_interaction(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		var best: Interactable = null
		var best_d: float = INF
		for n: Node in get_tree().get_nodes_in_group("interactable"):
			var it: Interactable = n as Interactable
			if it == null or not it.can_interact():
				continue
			var d: float = global_position.distance_to(it.global_position)
			if d <= it.interact_radius and d < best_d:
				best = it
				best_d = d
		if best != _target:
			_target = best
			var prompt: String = "" if best == null else best.get_prompt()
			interact_target_changed.emit(prompt)
			GameInput.interact_target_changed.emit(prompt)
		elif _target != null:
			GameInput.interact_target_changed.emit(_target.get_prompt())
	if Input.is_action_just_pressed("interact") and _target != null and not StoryManager.lore_open:
		_target.interact(self)

func _safety(delta: float) -> void:
	_safe_timer -= delta
	if is_on_floor() and global_position.y > 0.3 and _safe_timer <= 0.0:
		_safe_timer = 1.0
		_last_safe = global_position
	if global_position.y < -12.0:
		teleport(_last_safe + Vector3(0.0, 1.0, 0.0), model_root.rotation.y)
