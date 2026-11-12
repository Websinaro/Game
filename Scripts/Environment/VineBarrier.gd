class_name VineBarrier
extends StaticBody3D
## Wall of hanging vines that blocks the hidden path until the marked tree is found.

@export var barrier_width: float = 24.0
@export var barrier_height: float = 7.0

var _col: CollisionShape3D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 909
	var mb: MeshBuilder = MeshBuilder.new()
	var vines: int = 34
	for i in range(vines):
		var x: float = -barrier_width * 0.5 + barrier_width * float(i) / float(vines - 1) + rng.randf_range(-0.3, 0.3)
		var z: float = rng.randf_range(-0.8, 0.8)
		var pts: PackedVector3Array = PackedVector3Array()
		var rad: PackedFloat32Array = PackedFloat32Array()
		for k in range(5):
			var t: float = float(k) / 4.0
			pts.append(Vector3(x + sin(t * 5.0 + float(i)) * 0.25, barrier_height * (1.0 - t), z))
			rad.append(lerpf(0.09, 0.05, t))
		mb.add_tube(pts, rad, 4, Color(0.10, 0.28, 0.09), Color(0.20, 0.42, 0.14))
	for i in range(34):
		var c: Vector3 = Vector3(rng.randf_range(-barrier_width * 0.5, barrier_width * 0.5), rng.randf_range(0.5, barrier_height), rng.randf_range(-0.7, 0.7))
		var r: float = rng.randf_range(0.5, 1.1)
		mb.add_sphere(Transform3D(Basis.IDENTITY, c), Vector3(r, r * 0.8, r * 0.8), 4, 6, Color(0.10, 0.26, 0.08), Color(0.28, 0.5, 0.15), 0.25, float(i))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Vines"
	mi.mesh = mb.build(GameMaterials.foliage())
	add_child(mi)
	_col = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(barrier_width, barrier_height, 2.4)
	_col.shape = shape
	_col.position = Vector3(0.0, barrier_height * 0.5, 0.0)
	add_child(_col)

func dissolve() -> void:
	if _col != null:
		_col.set_deferred("disabled", true)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.0, 0.02, 1.0), 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(hide)
