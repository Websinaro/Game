class_name ParashuramaModel
extends Node3D
## TEMPORARY procedural Parashurama (warrior-sage): saffron dhoti, sacred thread, rudraksha
## beads, long matted hair with top-knot, beard, tilak, armlets, empty axe-loop on the back.
## Faces local -Z. To replace with a Prisma3D / glTF model: delete the children this script
## creates (or swap the script) and keep update_motion() / reach_for_axe() on the root.

const SKIN: Color = Color(0.60, 0.40, 0.27)
const SAFFRON: Color = Color(0.86, 0.52, 0.12)
const SASH: Color = Color(0.62, 0.16, 0.10)
const CREAM: Color = Color(0.92, 0.88, 0.76)
const HAIR: Color = Color(0.13, 0.08, 0.05)
const GOLD: Color = Color(0.85, 0.65, 0.15)
const LEATHER: Color = Color(0.30, 0.18, 0.10)

var _body: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _phase: float = 0.0
var _swing: float = 0.0
var _posing: bool = false

func _ready() -> void:
	var mat: Material = GameMaterials.vertex_color()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_add_mesh(_body, _build_torso(), mat, "Torso")
	_arm_l = _make_limb(Vector3(-0.34, 1.52, 0.0), 0.62, 0.075, "ArmL", true, mat)
	_arm_r = _make_limb(Vector3(0.34, 1.52, 0.0), 0.62, 0.075, "ArmR", true, mat)
	_leg_l = _make_limb(Vector3(-0.13, 0.95, 0.0), 0.88, 0.095, "LegL", false, mat)
	_leg_r = _make_limb(Vector3(0.13, 0.95, 0.0), 0.88, 0.095, "LegR", false, mat)

func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, node_name: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _make_limb(pivot_pos: Vector3, length: float, radius: float, node_name: String, is_arm: bool, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = node_name
	pivot.position = pivot_pos
	_body.add_child(pivot)
	var mb: MeshBuilder = MeshBuilder.new()
	if is_arm:
		mb.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, -length, 0.0)), radius * 0.8, radius, length, 7, SKIN.darkened(0.05), SKIN)
		mb.add_sphere(Transform3D(Basis.IDENTITY, Vector3(0.0, -length - 0.03, 0.0)), Vector3(0.07, 0.08, 0.07), 3, 6, SKIN, SKIN)
		mb.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.3, 0.0)), 0.092, 0.092, 0.06, 8, GOLD, GOLD)
	else:
		mb.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, -length, 0.0)), radius * 0.75, radius, length, 7, SKIN.darkened(0.05), SKIN)
		mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, -length - 0.04, -0.05)), Vector3(0.16, 0.08, 0.3), LEATHER)
	_add_mesh(pivot, mb.build(), mat, node_name + "Mesh")
	return pivot

func _build_torso() -> ArrayMesh:
	var mb: MeshBuilder = MeshBuilder.new()
	var id: Basis = Basis.IDENTITY
	# lower cloth (dhoti) - flared wrap to the knee, sash at waist
	mb.add_cylinder(Transform3D(id, Vector3(0.0, 0.52, 0.0)), 0.36, 0.27, 0.6, 10, SAFFRON.darkened(0.1), SAFFRON)
	mb.add_cylinder(Transform3D(id, Vector3(0.0, 1.07, 0.0)), 0.275, 0.275, 0.1, 10, SASH, SASH)
	mb.add_box(Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 0.0)), Vector3(0.0, 0.7, -0.3)), Vector3(0.2, 0.55, 0.05), SAFFRON.lightened(0.1))
	# chest + belly
	mb.add_sphere(Transform3D(id, Vector3(0.0, 1.38, 0.0)), Vector3(0.33, 0.30, 0.2), 6, 10, SKIN.darkened(0.05), SKIN.lightened(0.05))
	mb.add_sphere(Transform3D(id, Vector3(0.0, 1.17, 0.0)), Vector3(0.26, 0.17, 0.18), 4, 8, SKIN.darkened(0.08), SKIN)
	# shoulders
	mb.add_sphere(Transform3D(id, Vector3(-0.34, 1.52, 0.0)), Vector3(0.11, 0.1, 0.11), 3, 6, SKIN, SKIN)
	mb.add_sphere(Transform3D(id, Vector3(0.34, 1.52, 0.0)), Vector3(0.11, 0.1, 0.11), 3, 6, SKIN, SKIN)
	# sacred thread (diagonal sash)
	var thread: PackedVector3Array = PackedVector3Array([Vector3(-0.2, 1.62, -0.12), Vector3(-0.1, 1.46, -0.2), Vector3(0.05, 1.28, -0.2), Vector3(0.18, 1.12, -0.17)])
	mb.add_tube(thread, PackedFloat32Array([0.022, 0.022, 0.022, 0.022]), 4, CREAM, CREAM)
	# neck + head
	mb.add_cylinder(Transform3D(id, Vector3(0.0, 1.6, 0.0)), 0.075, 0.07, 0.12, 7, SKIN, SKIN)
	mb.add_sphere(Transform3D(id, Vector3(0.0, 1.76, 0.0)), Vector3(0.115, 0.14, 0.12), 6, 10, SKIN.darkened(0.04), SKIN.lightened(0.04))
	mb.add_sphere(Transform3D(id, Vector3(0.0, 1.68, -0.1)), Vector3(0.09, 0.11, 0.07), 4, 8, HAIR, HAIR.lightened(0.1), 0.1, 2.0)
	mb.add_sphere(Transform3D(id, Vector3(0.0, 1.75, -0.12)), Vector3(0.025, 0.035, 0.025), 3, 5, SKIN.darkened(0.1), SKIN)
	mb.add_sphere(Transform3D(id, Vector3(-0.045, 1.79, -0.11)), Vector3(0.016, 0.012, 0.01), 3, 4, Color.BLACK, Color.BLACK)
	mb.add_sphere(Transform3D(id, Vector3(0.045, 1.79, -0.11)), Vector3(0.016, 0.012, 0.01), 3, 4, Color.BLACK, Color.BLACK)
	mb.add_box(Transform3D(id, Vector3(0.0, 1.84, -0.115)), Vector3(0.02, 0.05, 0.01), Color(0.75, 0.1, 0.08))
	# hair: top-knot, headband, long locks down the back
	mb.add_sphere(Transform3D(id, Vector3(0.0, 1.9, 0.02)), Vector3(0.12, 0.1, 0.12), 4, 8, HAIR, HAIR.lightened(0.15), 0.12, 5.0)
	mb.add_sphere(Transform3D(id, Vector3(0.0, 1.79, 0.05)), Vector3(0.125, 0.12, 0.115), 4, 8, HAIR, HAIR.lightened(0.1), 0.08, 3.0)
	var band: PackedVector3Array = PackedVector3Array()
	for i in range(13):
		var a: float = TAU * float(i) / 12.0
		band.append(Vector3(cos(a) * 0.12, 1.83, sin(a) * 0.125))
	mb.add_tube(band, PackedFloat32Array([0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014]), 4, SASH, SASH)
	for k in range(3):
		var ox: float = (float(k) - 1.0) * 0.07
		var lock: PackedVector3Array = PackedVector3Array([Vector3(ox, 1.8, 0.1), Vector3(ox * 1.2, 1.55, 0.18), Vector3(ox * 1.4, 1.28, 0.22), Vector3(ox * 1.5, 1.02, 0.2)])
		mb.add_tube(lock, PackedFloat32Array([0.05, 0.045, 0.04, 0.025]), 5, HAIR, HAIR.lightened(0.08))
	# beard + moustache
	mb.add_sphere(Transform3D(id, Vector3(0.0, 1.66, -0.08)), Vector3(0.075, 0.1, 0.06), 4, 8, HAIR, HAIR.lightened(0.1), 0.12, 1.0)
	# rudraksha beads
	for i in range(14):
		var a2: float = TAU * float(i) / 14.0
		mb.add_sphere(Transform3D(id, Vector3(cos(a2) * 0.12, 1.5, sin(a2) * 0.11 - 0.04)), Vector3(0.02, 0.02, 0.02), 3, 4, Color(0.28, 0.16, 0.08), Color(0.4, 0.25, 0.12))
	# empty axe loop on the back: leather strap + ring (axe is missing!)
	var strap: PackedVector3Array = PackedVector3Array([Vector3(-0.28, 1.55, 0.19), Vector3(-0.1, 1.35, 0.22), Vector3(0.1, 1.15, 0.23), Vector3(0.25, 0.98, 0.2)])
	mb.add_tube(strap, PackedFloat32Array([0.03, 0.03, 0.03, 0.03]), 4, LEATHER, LEATHER)
	var ring: PackedVector3Array = PackedVector3Array()
	for i in range(11):
		var a3: float = TAU * float(i) / 10.0
		ring.append(Vector3(cos(a3) * 0.07, 1.25 + sin(a3) * 0.07, 0.25))
	mb.add_tube(ring, PackedFloat32Array([0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014]), 4, GOLD.darkened(0.2), GOLD.darkened(0.2))
	return mb.build()

## Procedural walk cycle. Called every physics frame by PlayerController.
func update_motion(speed: float, grounded: bool, delta: float) -> void:
	if _body == null:
		return
	var amount: float = clampf(speed / 6.5, 0.0, 1.0)
	_phase += delta * (speed * 1.5 + 1.0)
	var target_swing: float = sin(_phase) * 0.85 * amount if grounded else 0.0
	_swing = lerpf(_swing, target_swing, 1.0 - exp(-18.0 * delta))
	_leg_l.rotation.x = _swing
	_leg_r.rotation.x = -_swing
	if not _posing:
		var arm_target: float = -0.6 if not grounded else 0.0
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -_swing * 0.8 + arm_target, 1.0 - exp(-14.0 * delta))
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, _swing * 0.8 + arm_target, 1.0 - exp(-14.0 * delta))
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.05, 1.0 - exp(-10.0 * delta))
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.05, 1.0 - exp(-10.0 * delta))
	var bob: float = absf(sin(_phase)) * 0.035 * amount
	var breathe: float = sin(Time.get_ticks_msec() * 0.002) * 0.006
	_body.position.y = bob + breathe

## Right hand reaches over the shoulder for the axe, finds nothing, drops. Non-blocking.
func reach_for_axe(duration: float) -> void:
	_posing = true
	var tw: Tween = create_tween()
	tw.set_parallel(false)
	tw.tween_property(_arm_r, "rotation", Vector3(-2.7, 0.0, -0.25), duration * 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(duration * 0.35)
	tw.tween_property(_arm_r, "rotation", Vector3(0.3, 0.0, -0.1), duration * 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_end_pose)

func _end_pose() -> void:
	_posing = false
