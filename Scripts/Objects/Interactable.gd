class_name Interactable
extends Node3D
## Base class for everything the player can "Use". Registers itself in group
## "interactable" (PlayerController scans that group) and shows a floating beacon
## so that important objects are easy to spot on a phone screen.

@export var prompt_text: String = "Examine"
@export var interact_radius: float = 3.0
@export var beacon_height: float = 2.2
@export var show_beacon: bool = true

var enabled: bool = true
var _beacon: MeshInstance3D = null
var _beacon_time: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	if show_beacon:
		_make_beacon()
	set_process(show_beacon)

func _make_beacon() -> void:
	var mb: MeshBuilder = MeshBuilder.new()
	var gold: Color = Color(1.0, 0.82, 0.35)
	mb.add_sphere(Transform3D.IDENTITY, Vector3(0.14, 0.24, 0.14), 2, 4, gold, gold)
	_beacon = MeshInstance3D.new()
	_beacon.name = "Beacon"
	_beacon.mesh = mb.build(GameMaterials.emissive(gold, 2.4))
	_beacon.position = Vector3(0.0, beacon_height, 0.0)
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beacon)

func _process(delta: float) -> void:
	if _beacon == null:
		return
	_beacon_time += delta
	_beacon.visible = enabled
	_beacon.position.y = beacon_height + sin(_beacon_time * 2.0) * 0.12
	_beacon.rotate_y(delta * 1.6)

func can_interact() -> bool:
	return enabled

func get_prompt() -> String:
	return prompt_text

## Override in subclasses.
func interact(_player: Node3D) -> void:
	pass

# helpers for subclasses -----------------------------------------------------------
func add_mesh_child(mesh: Mesh, node_name: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	add_child(mi)
	return mi

func add_box_collider(size: Vector3, centre: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = centre
	body.add_child(cs)
	add_child(body)
