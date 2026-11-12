class_name Rock
extends Node3D
## Procedural rock. Use Rock.tscn for hand-placed rocks; scatter uses the static meshes.
## Unit size = 1 m radius; scale instances to taste.

@export var seed_value: int = 1
@export var rock_size: float = 1.0
@export var mossy: bool = false

static var _cache: Dictionary = {}

static func build_mesh(seed_value_in: int, mossy_in: bool) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value_in
	var mb: MeshBuilder = MeshBuilder.new()
	var bottom: Color = Color(0.26, 0.25, 0.25)
	var top: Color = Color(0.25, 0.38, 0.16) if mossy_in else Color(0.46, 0.45, 0.42)
	var yaw: float = rng.randf() * TAU
	mb.add_sphere(Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, 0.18, 0.0)), Vector3(1.0, 0.62, 0.85), 5, 8, bottom, top, 0.28, float(seed_value_in))
	if rng.randf() < 0.7:
		var off: Vector3 = Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.7, 0.7))
		mb.add_sphere(Transform3D(Basis(Vector3.UP, yaw + 1.0), off), Vector3(0.5, 0.35, 0.45), 4, 6, bottom, top.darkened(0.1), 0.3, float(seed_value_in) + 3.0)
	return mb.build(GameMaterials.vertex_color())

static func get_variant_mesh(variant: int, mossy_in: bool) -> ArrayMesh:
	var key: String = "rock_%d_%s" % [variant, str(mossy_in)]
	if not _cache.has(key):
		_cache[key] = build_mesh(100 + variant * 17, mossy_in)
	return _cache[key] as ArrayMesh

func _ready() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = build_mesh(seed_value, mossy)
	mi.scale = Vector3.ONE * rock_size
	add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = rock_size * 0.8
	cs.shape = shape
	cs.position = Vector3(0.0, rock_size * 0.25, 0.0)
	body.add_child(cs)
	add_child(body)
