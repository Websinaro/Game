class_name AncientRuinsRegion
extends RegionBase
## The Forgotten Sanctum (north of the ridge). Built in "site" space: origin = plateau
## ground, +Z = front (south, where the ramp is), platform top = 0.9.
## Challenge 2: collect three inscription fragments scattered on the plateau.
## Challenge 3: read the great tablet, turn three pillars to SEA, FOREST, MOUNTAIN.
## The sanctum gate then opens, revealing the altar with the final clue.

class RiddleTablet extends StoryInteractable:
	func _show_lore() -> void:
		var lines: Array = StoryManager.get_tablet_lines()
		var found: PackedStringArray = PackedStringArray()
		for i in range(lines.size()):
			if StoryManager.has_flag("frag_%d" % i):
				found.append(str(lines[i]))
		if found.size() == 0:
			StoryManager.show_lore("tablet_empty")
		elif found.size() < lines.size():
			StoryManager.show_lore("tablet_partial", "\n\n" + "\n".join(found))
		else:
			StoryManager.show_lore("tablet_full")

const GRANITE: Color = Color(0.52, 0.50, 0.47)
const LATERITE: Color = Color(0.58, 0.34, 0.22)
const TERRACOTTA: Color = Color(0.58, 0.25, 0.17)
const TOP: float = 0.9
const SOLUTION: Array[int] = [0, 1, 2]

var _site: Node3D = null
var _stone: MeshBuilder = MeshBuilder.new()
var _col_body: StaticBody3D = null
var _gate: StaticBody3D = null
var _gate_col: CollisionShape3D = null
var _light: OmniLight3D = null
var _pillars: Array[SymbolPillar] = []

func _populate() -> void:
	_site = Node3D.new()
	_site.name = "Site"
	_site.position = world_pos(region_center.x, region_center.y, 0.0)
	add_child(_site)
	_col_body = StaticBody3D.new()
	_col_body.name = "RuinColliders"
	_col_body.collision_layer = 1
	_col_body.collision_mask = 0
	_site.add_child(_col_body)
	WorldRegistry.add_exclusion(region_center.x, region_center.y, 19.0)
	_build_platform()
	_build_gateway_and_pillars()
	_build_sanctum()
	_build_dais()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "RuinStone"
	mi.mesh = _stone.build(GameMaterials.vertex_color())
	_site.add_child(mi)
	_build_gate()
	_build_lamp_posts()
	_build_puzzle()
	_build_fragments()
	_build_tablet()
	_build_altar()
	_build_surroundings()
	QuestManager.objective_completed.connect(_on_objective_completed)

# ---- stone helpers ----------------------------------------------------------------------
func _box(centre: Vector3, size: Vector3, col: Color, basis_in: Basis = Basis.IDENTITY, collide: bool = true) -> void:
	var xf: Transform3D = Transform3D(basis_in, centre)
	_stone.add_box(xf, size, col, col.lightened(0.06))
	if collide:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.transform = xf
		_col_body.add_child(cs)

func _column(x: float, z: float, h: float) -> void:
	_stone.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(x, TOP, z)), 0.55, 0.5, h, 8, GRANITE.darkened(0.12), GRANITE)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = h
	cs.shape = shape
	cs.position = Vector3(x, TOP + h * 0.5, z)
	_col_body.add_child(cs)
	if h > 4.2:
		_stone.add_box(Transform3D(Basis.IDENTITY, Vector3(x, TOP + h + 0.17, z)), Vector3(1.3, 0.35, 1.3), GRANITE.lightened(0.05))

# ---- structures ----------------------------------------------------------------------------
func _build_platform() -> void:
	_box(Vector3(0.0, 0.2, 0.0), Vector3(28.0, 1.4, 30.0), GRANITE)
	_box(Vector3(0.0, -0.15, 0.0), Vector3(29.6, 0.8, 31.6), GRANITE.darkened(0.22), Basis.IDENTITY, false)
	var ang: float = 0.165
	var rb: Basis = Basis(Vector3.RIGHT, ang)
	var n: Vector3 = rb * Vector3.UP
	var rc: Vector3 = Vector3(0.0, 0.4, 18.0) - n * 0.25
	_box(rc, Vector3(7.0, 0.5, 6.2), GRANITE.lightened(0.05), rb)
	for sx in [-3.8, 3.8]:
		_box(rc + n * 0.45 + Vector3(float(sx), 0.0, 0.0), Vector3(0.6, 0.8, 6.2), GRANITE.darkened(0.05), rb)

func _build_gateway_and_pillars() -> void:
	for sx in [-3.0, 3.0]:
		_box(Vector3(float(sx), TOP + 2.8, 11.0), Vector3(1.1, 5.6, 1.1), GRANITE)
	_box(Vector3(-1.9, TOP + 6.05, 11.0), Vector3(3.8, 0.9, 1.3), GRANITE.lightened(0.04))
	_box(Vector3(4.6, 1.3, 13.0), Vector3(3.2, 0.8, 1.2), GRANITE, Basis.from_euler(Vector3(0.1, 0.6, 0.2)))
	for zi in [-12.0, -5.0, 2.0, 9.0]:
		for sx in [-12.5, 12.5]:
			_column(float(sx), float(zi), rng.randf_range(2.2, 5.6))
	_box(Vector3(-8.5, TOP + 0.7, 12.8), Vector3(5.0, 1.6, 0.9), LATERITE, Basis.from_euler(Vector3(0.05, 0.3, 0.12)))
	_box(Vector3(8.5, TOP + 0.5, 7.5), Vector3(4.0, 1.2, 0.9), LATERITE, Basis.from_euler(Vector3(0.0, -0.4, 0.1)))
	_box(Vector3(-10.0, TOP + 0.6, -7.0), Vector3(4.5, 1.4, 0.9), LATERITE, Basis.from_euler(Vector3(0.0, 1.2, -0.08)))
	for i in range(14):
		var p: Vector3 = Vector3(rng.randf_range(-13.0, 13.0), TOP + 0.1, rng.randf_range(-13.0, 14.0))
		var r: float = rng.randf_range(0.2, 0.5)
		_stone.add_sphere(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(r, r * 0.6, r), 3, 6, GRANITE.darkened(0.2), GRANITE, 0.25, float(i))

func _build_sanctum() -> void:
	var wall_c: float = TOP + 2.5
	_box(Vector3(0.0, wall_c, -13.0), Vector3(13.9, 5.0, 0.9), LATERITE)
	_box(Vector3(-6.5, wall_c, -8.0), Vector3(0.9, 5.0, 10.2), LATERITE)
	_box(Vector3(6.5, wall_c, -8.0), Vector3(0.9, 5.0, 10.2), LATERITE)
	_box(Vector3(-4.275, wall_c, -3.0), Vector3(5.35, 5.0, 0.9), LATERITE)
	_box(Vector3(4.275, wall_c, -3.0), Vector3(5.35, 5.0, 0.9), LATERITE)
	_box(Vector3(0.0, TOP + 4.1, -3.0), Vector3(3.2, 1.6, 0.9), LATERITE.lightened(0.05))
	_box(Vector3(0.0, 6.25, -8.0), Vector3(14.6, 0.7, 11.2), TERRACOTTA.darkened(0.15))
	var roof_basis: Basis = Basis.from_scale(Vector3(1.05, 1.0, 0.79)) * Basis(Vector3.UP, PI * 0.25)
	_stone.add_cylinder(Transform3D(roof_basis, Vector3(0.0, 6.6, -8.0)), 10.0, 0.5, 3.6, 4, TERRACOTTA.darkened(0.1), TERRACOTTA, false, false)

func _build_dais() -> void:
	_stone.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, TOP, 3.0)), 8.0, 8.0, 0.04, 24, GRANITE.darkened(0.3), GRANITE.darkened(0.2))

func _build_gate() -> void:
	_gate = StaticBody3D.new()
	_gate.name = "SanctumGate"
	_gate.collision_layer = 1
	_gate.collision_mask = 0
	_gate.position = Vector3(0.0, TOP + 1.7, -3.0)
	_site.add_child(_gate)
	var mb: MeshBuilder = MeshBuilder.new()
	mb.add_box(Transform3D.IDENTITY, Vector3(3.2, 3.4, 0.7), GRANITE.lightened(0.05))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mb.build(GameMaterials.vertex_color())
	_gate.add_child(mi)
	var gb: MeshBuilder = MeshBuilder.new()
	for i in range(3):
		gb.add_box(Transform3D(Basis.IDENTITY, Vector3(-0.8 + float(i) * 0.8, 0.2, 0.36)), Vector3(0.1, 2.2, 0.03), Color(0.45, 0.92, 0.85))
	var gmi: MeshInstance3D = MeshInstance3D.new()
	gmi.mesh = gb.build(GameMaterials.emissive(Color(0.45, 0.92, 0.85), 1.4))
	_gate.add_child(gmi)
	_gate_col = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.2, 3.4, 0.7)
	_gate_col.shape = shape
	_gate.add_child(_gate_col)
	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, TOP + 3.2, -9.0)
	_light.light_color = Color(1.0, 0.75, 0.45)
	_light.omni_range = 10.0
	_light.light_energy = 0.0
	_site.add_child(_light)

func _build_lamp_posts() -> void:
	var fb: MeshBuilder = MeshBuilder.new()
	var pb: MeshBuilder = MeshBuilder.new()
	for sx in [-3.2, 3.2]:
		var x: float = float(sx)
		pb.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(x, TOP, -1.0)), 0.25, 0.18, 1.4, 7, GRANITE.darkened(0.1), GRANITE)
		pb.add_sphere(Transform3D(Basis.IDENTITY, Vector3(x, TOP + 1.5, -1.0)), Vector3(0.3, 0.14, 0.3), 3, 8, GRANITE.darkened(0.2), GRANITE.darkened(0.05))
		fb.add_sphere(Transform3D(Basis.IDENTITY, Vector3(x, TOP + 1.78, -1.0)), Vector3(0.11, 0.2, 0.11), 3, 6, Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.4))
	var a: MeshInstance3D = MeshInstance3D.new()
	a.mesh = pb.build(GameMaterials.vertex_color())
	_site.add_child(a)
	var b: MeshInstance3D = MeshInstance3D.new()
	b.mesh = fb.build(GameMaterials.emissive(Color(1.0, 0.55, 0.15), 3.0))
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_site.add_child(b)

# ---- challenge 3: pillars ---------------------------------------------------------------------
func _build_puzzle() -> void:
	for i in range(3):
		var p: SymbolPillar = SymbolPillar.new()
		p.name = "SymbolPillar%d" % i
		p.pillar_index = i
		p.position = Vector3(-4.0 + 4.0 * float(i), TOP, 3.0)
		_site.add_child(p)
		p.symbol_changed.connect(_on_pillar_changed)
		_pillars.append(p)

func _on_pillar_changed(_idx: int, _sym: int) -> void:
	for i in range(3):
		if _pillars[i].symbol != SOLUTION[i]:
			return
	for p: SymbolPillar in _pillars:
		p.lock_solved()
	QuestManager.complete_objective("symbols")

# ---- challenge 2: fragments --------------------------------------------------------------------
func _build_fragments() -> void:
	var spots: Array[Vector2] = [Vector2(-10.0, 11.0), Vector2(11.0, -6.0), Vector2(-11.0, -12.0)]
	for i in range(3):
		var f: StoryInteractable = StoryInteractable.new()
		f.name = "Fragment%d" % (i + 1)
		f.style = "fragment"
		f.lore_id = "fragment_%d" % (i + 1)
		f.objective_id = "inscriptions"
		f.count_progress = true
		f.required_objective = "inscriptions"
		f.locked_lore_id = "fragment_locked"
		f.vanish_on_use = true
		f.prompt_text = "Take the inscription fragment"
		f.position = Vector3(spots[i].x, TOP, spots[i].y)
		_site.add_child(f)
		var idx: int = i
		f.activated.connect(func(_src: StoryInteractable) -> void: StoryManager.set_flag("frag_%d" % idx))

func _build_tablet() -> void:
	var t: RiddleTablet = RiddleTablet.new()
	t.name = "GreatTablet"
	t.style = "tablet"
	t.prompt_text = "Read the great tablet"
	t.interact_radius = 3.6
	t.position = Vector3(-9.0, TOP, 6.0)
	t.rotation.y = PI
	_site.add_child(t)

func _build_altar() -> void:
	var packed: PackedScene = load("res://Scenes/Objects/AncientClue.tscn") as PackedScene
	var clue: AncientClue = packed.instantiate() as AncientClue
	clue.position = Vector3(0.0, TOP, -10.6)
	clue.rotation.y = PI
	_site.add_child(clue)

func _build_surroundings() -> void:
	var r: float = region_radius
	var cx: float = region_center.x
	var cz: float = region_center.y
	var tree_pts: Array[Vector2] = []
	for p: Vector2 in grid_points(cx - r, cx + r, cz - r, cz + r, 7.0, 2.5, 0.55, true):
		if Vector2(p.x - cx, p.y - cz).length() > 19.5:
			tree_pts.append(p)
	add_trees(filter_placeable(tree_pts, 2.5, 0.45, 3.5))
	var bush_pts: Array[Vector2] = []
	for p2: Vector2 in grid_points(cx - r, cx + r, cz - r, cz + r, 5.0, 2.0, 0.45, true):
		if Vector2(p2.x - cx, p2.y - cz).length() > 17.0:
			bush_pts.append(p2)
	add_bushes(filter_placeable(bush_pts, 2.5, 0.5, 2.5))
	var tuft_pts: Array[Vector2] = []
	for p3: Vector2 in grid_points(cx - r, cx + r, cz - r, cz + r, 2.8, 1.2, 0.4, true):
		if Vector2(p3.x - cx, p3.y - cz).length() > 16.5:
			tuft_pts.append(p3)
	add_tufts(filter_placeable(tuft_pts, 2.5, 0.55, 0.0))
	var rock_pts: Array[Vector2] = []
	for p4: Vector2 in grid_points(cx - r, cx + r, cz - r, cz + r, 8.0, 3.0, 0.5, true):
		if Vector2(p4.x - cx, p4.y - cz).length() > 17.5:
			rock_pts.append(p4)
	add_rocks(filter_placeable(rock_pts, 2.5, 0.7, 3.0), 1.2, 2.8, false)

# ---- reactions ----------------------------------------------------------------------------------
func _on_objective_completed(_quest_id: String, objective_id: String) -> void:
	if objective_id == "inscriptions":
		for p: SymbolPillar in _pillars:
			p.set_dormant(false)
	elif objective_id == "symbols":
		_open_gate()

func _open_gate() -> void:
	_gate_col.set_deferred("disabled", true)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_gate, "position:y", _gate.position.y - 3.8, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_light, "light_energy", 1.6, 3.0)
