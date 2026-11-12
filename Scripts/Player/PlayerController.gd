class_name PlayerController
extends CharacterBody3D
## Movement + interaction. Reads only Input ACTIONS (keyboard or touch UI).
## The visual model lives under $ModelRoot and is fully separate: replace that node's
## content/script with any Node3D that implements:
##   update_motion(speed: float, grounded: bool, delta: float)
##   reach_for_axe(duration: float)      (optional, used by the intro)

signal interact_target_changed(prompt: String)

@export var walk_speed: float = 3.4
@export var run_speed: float = 6.8
@export var jump_velocity: float = 5.6
@export var acceleration: float = 26.0
@export var air_control: float = 0.5
@export var turn_speed: float = 11.0
@export var gravity_scale: float = 1.5

var controls_enabled: bool = false

var _gravity: float = 9.8
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _target: Interactable = null
var _scan_timer: float = 0.0
var _safe_timer: float = 0.0
var _last_safe: Vector3 = Vector3.ZERO

@onready var model_root: Node3D = $ModelRoot
@onready var camera_rig: CameraController = $CameraRig

func _ready() -> void:
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

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var move_dir: Vector3 = right * input_vec.x + forward * (-input_vec.y)
	var strength: float = minf(input_vec.length(), 1.0)
	var running: bool = Input.is_action_pressed("run")
	var target_speed: float = 0.0
	if strength > 0.01:
		move_dir = move_dir.normalized()
		target_speed = run_speed if running else walk_speed * maxf(strength, 0.4)
		if global_position.y < -0.1:
			target_speed *= 0.6
	var horiz: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var accel: float = acceleration if is_on_floor() else acceleration * air_control
	horiz = horiz.move_toward(move_dir * target_speed, accel * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		_coyote = 0.12
	else:
		_coyote -= delta
		velocity.y -= _gravity * gravity_scale * delta
	_jump_buffer -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
	move_and_slide()
	if move_dir != Vector3.ZERO:
		var target_yaw: float = atan2(-move_dir.x, -move_dir.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	if model_root.has_method("update_motion"):
		model_root.call("update_motion", Vector3(velocity.x, 0.0, velocity.z).length(), is_on_floor(), delta)
	_update_interaction(delta)
	_safety(delta)

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
