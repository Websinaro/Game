class_name CameraController
extends Node3D
## Smooth third-person orbit camera. Child of the player but top_level, so it does not
## inherit rotation. Features: drag rotation (touch / mouse), pinch / wheel zoom,
## wall + terrain avoidance (ray cast and terrain height clamp).

@export var distance: float = 5.4
@export var min_distance: float = 2.5
@export var max_distance: float = 10.0
@export var pivot_height: float = 1.55
@export var look_sensitivity: float = 0.0055
@export var key_rotate_speed: float = 1.8
@export var follow_smoothing: float = 14.0

var yaw: float = 0.0
var pitch: float = 0.32

var _target: Node3D = null
var _pivot: Vector3 = Vector3.ZERO
var _current_distance: float = 5.4
var _snap: bool = true

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	top_level = true
	_target = get_parent() as Node3D
	_current_distance = distance
	camera.fov = 65.0
	camera.near = 0.1
	camera.far = 600.0
	GameInput.look_delta.connect(_on_look_delta)
	GameInput.zoom_delta.connect(_on_zoom_delta)

func snap_to_target() -> void:
	_snap = true

func make_current() -> void:
	camera.make_current()

func _on_look_delta(delta: Vector2) -> void:
	yaw -= delta.x * look_sensitivity
	pitch = clampf(pitch + delta.y * look_sensitivity, -0.1, 1.25)

func _on_zoom_delta(amount: float) -> void:
	distance = clampf(distance + amount, min_distance, max_distance)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.6, min_distance, max_distance)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.6, min_distance, max_distance)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_on_look_delta(mm.relative)

func _process(delta: float) -> void:
	if _target == null:
		return
	yaw += (Input.get_action_strength("cam_left") - Input.get_action_strength("cam_right")) * key_rotate_speed * delta
	var goal: Vector3 = _target.global_position + Vector3(0.0, pivot_height, 0.0)
	if _snap:
		_pivot = goal
		_snap = false
	else:
		_pivot = _pivot.lerp(goal, 1.0 - exp(-follow_smoothing * delta))
	global_position = _pivot
	var offset_dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, sin(pitch), cos(pitch))
	var wanted: float = distance
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_pivot, _pivot + offset_dir * (wanted + 0.4), 1)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		wanted = maxf(min_distance * 0.4, _pivot.distance_to(hp) - 0.4)
	var rate: float = 22.0 if wanted < _current_distance else 4.0
	_current_distance = lerpf(_current_distance, wanted, 1.0 - exp(-rate * delta))
	var cam_pos: Vector3 = _pivot + offset_dir * _current_distance
	var floor_y: float = maxf(TerrainGenerator.height_at(cam_pos.x, cam_pos.z), 0.0) + 0.5
	if cam_pos.y < floor_y:
		cam_pos.y = floor_y
	camera.global_position = cam_pos
	camera.look_at(_pivot, Vector3.UP)
