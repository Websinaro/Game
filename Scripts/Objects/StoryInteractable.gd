class_name StoryInteractable
extends Interactable
## Generic story object: shows a lore panel and advances the quest.
## style: "marks" (sand drag marks), "tree" (carved tree), "fragment" (floating shard),
##        "tablet" (standing tablet), "altar" (final clue altar).

signal activated(source: StoryInteractable)

@export var lore_id: String = ""
@export var objective_id: String = ""
@export var count_progress: bool = false
@export var required_objective: String = ""
@export var locked_lore_id: String = ""
@export var style: String = "marks"
@export var vanish_on_use: bool = false

const GLOW: Color = Color(0.45, 0.92, 0.85)
const GRANITE: Color = Color(0.50, 0.48, 0.45)

var used: bool = false
var _spin: MeshInstance3D = null

func _ready() -> void:
	super._ready()
	match style:
		"marks":
			_build_marks()
		"tree":
			_build_tree()
		"fragment":
			_build_fragment()
		"tablet":
			_build_tablet()
		"altar":
			_build_altar()

func _process(delta: float) -> void:
	super(delta)
	if _spin != null:
		_spin.rotate_y(delta * 0.9)

func interact(_player: Node3D) -> void:
	if required_objective != "" and not QuestManager.is_objective_active(required_objective):
		if locked_lore_id != "":
			StoryManager.show_lore(locked_lore_id)
		return
	var first: bool = not used
	used = true
	_show_lore()
	if first:
		if objective_id != "":
			if count_progress:
				QuestManager.progress_objective(objective_id)
			else:
				QuestManager.complete_objective(objective_id)
		activated.emit(self)
		if vanish_on_use:
			enabled = false
			var tw: Tween = create_tween()
			tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
			tw.tween_callback(queue_free)

## Subclasses (e.g. riddle tablet) override to build dynamic text.
func _show_lore() -> void:
	StoryManager.show_lore(lore_id)

# ---- visuals ---------------------------------------------------------------------------
func _build_marks() -> void:
	beacon_height = 1.5
	var mb: MeshBuilder = MeshBuilder.new()
	var dark: Color = Color(0.55, 0.47, 0.32)
	for si in range(2):
		var sx: float = -0.4 if si == 0 else 0.4
		mb.add_box(Transform3D(Basis.IDENTITY, Vector3(sx, 0.0, -1.5)), Vector3(0.16, 0.1, 6.5), dark)
	for i in range(9):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var xf: Transform3D = Transform3D(Basis(Vector3.UP, side * 0.15), Vector3(side * 1.1, 0.0, 1.0 - float(i) * 0.7))
		mb.add_box(xf, Vector3(0.16, 0.08, 0.34), dark.darkened(0.15))
	add_mesh_child(mb.build(GameMaterials.vertex_color()), "Marks")
	if _beacon != null:
		_beacon.position.y = beacon_height

func _build_tree() -> void:
	beacon_height = 4.2
	var mi: MeshInstance3D = add_mesh_child(Vegetation.get_tree_mesh(0, 1), "Tree")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mb: MeshBuilder = MeshBuilder.new()
	var pts: PackedVector3Array = PackedVector3Array()
	var rad: PackedFloat32Array = PackedFloat32Array()
	for i in range(22):
		var a: float = float(i) * 0.55
		var r: float = 0.03 + 0.012 * float(i)
		pts.append(Vector3(cos(a) * r, 1.6 + sin(a) * r, -0.3))
		rad.append(0.018)
	mb.add_tube(pts, rad, 4, GLOW, GLOW)
	add_mesh_child(mb.build(GameMaterials.emissive(GLOW, 2.5)), "Sigil")
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 3.0
	cs.shape = shape
	cs.position = Vector3(0.0, 1.5, 0.0)
	body.add_child(cs)
	add_child(body)
	if _beacon != null:
		_beacon.position.y = beacon_height

func _build_fragment() -> void:
	beacon_height = 1.9
	var mb: MeshBuilder = MeshBuilder.new()
	mb.add_cylinder(Transform3D.IDENTITY, 0.5, 0.4, 0.15, 7, GRANITE.darkened(0.2), GRANITE)
	add_mesh_child(mb.build(GameMaterials.vertex_color()), "Base")
	var sb: MeshBuilder = MeshBuilder.new()
	sb.add_box(Transform3D(Basis.from_euler(Vector3(0.2, 0.0, 0.25)), Vector3.ZERO), Vector3(0.34, 0.62, 0.12), GLOW)
	_spin = add_mesh_child(sb.build(GameMaterials.emissive(GLOW, 1.8)), "Shard")
	_spin.position = Vector3(0.0, 0.95, 0.0)
	if _beacon != null:
		_beacon.position.y = beacon_height

func _build_tablet() -> void:
	show_beacon = true
	beacon_height = 3.1
	var mb: MeshBuilder = MeshBuilder.new()
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 0.0)), Vector3(3.0, 0.3, 0.8), GRANITE.darkened(0.15))
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.4, 0.0)), Vector3(2.6, 2.2, 0.35), GRANITE, GRANITE.lightened(0.1))
	add_mesh_child(mb.build(GameMaterials.vertex_color()), "Slab")
	var gb: MeshBuilder = MeshBuilder.new()
	for i in range(6):
		var w: float = 1.9 - float(i % 3) * 0.5
		gb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0 - float(i) * 0.28, -0.19)), Vector3(w, 0.05, 0.02), GLOW)
	add_mesh_child(gb.build(GameMaterials.emissive(GLOW, 1.2)), "Carvings")
	add_box_collider(Vector3(2.8, 2.6, 0.8), Vector3(0.0, 1.3, 0.0))
	if _beacon != null:
		_beacon.position.y = beacon_height

func _build_altar() -> void:
	beacon_height = 3.4
	var mb: MeshBuilder = MeshBuilder.new()
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2, 0.0)), Vector3(2.8, 0.4, 2.2), GRANITE.darkened(0.2))
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.7, 0.0)), Vector3(2.1, 0.6, 1.6), GRANITE)
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.9, -0.45)), Vector3(1.8, 1.8, 0.28), GRANITE.lightened(0.08))
	add_mesh_child(mb.build(GameMaterials.vertex_color()), "Altar")
	var gb: MeshBuilder = MeshBuilder.new()
	# relief: two mountains, an axe, a line of lamps
	gb.add_cylinder(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(-0.45, 1.45, -0.6)), 0.34, 0.0, 0.6, 4, GLOW, GLOW, false, false)
	gb.add_cylinder(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0.1, 1.45, -0.6)), 0.46, 0.0, 0.85, 4, GLOW, GLOW, false, false)
	gb.add_box(Transform3D(Basis.IDENTITY, Vector3(-0.55, 2.1, -0.6)), Vector3(0.05, 0.55, 0.03), GLOW)
	gb.add_box(Transform3D(Basis.IDENTITY, Vector3(-0.45, 2.3, -0.6)), Vector3(0.2, 0.18, 0.03), GLOW)
	for i in range(5):
		gb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.35 + float(i) * 0.12, 2.35 - float(i) * 0.14, -0.6)), Vector3(0.06, 0.06, 0.03), GLOW)
	add_mesh_child(gb.build(GameMaterials.emissive(GLOW, 2.0)), "Relief")
	add_box_collider(Vector3(2.8, 2.8, 2.2), Vector3(0.0, 1.4, 0.0))
	if _beacon != null:
		_beacon.position.y = beacon_height
