class_name AncientRuinsRegion
extends RegionBase
## The Forgotten Sanctum (north of the ridge). Built in "site" space: origin = plateau
## ground, +Z = front (south, where the ramp is), platform top = 0.9.
## Challenge 2: collect three inscription fragments scattered on the plateau.
## Challenge 3: read the great tablet, turn three pillars to SEA, FOREST, MOUNTAIN.
## The sanctum gate then opens, revealing the altar with the final clue.

class RiddleTablet extends StoryInteractable:
	## Shows the clue lines whose fragments have been collected (frag_<i> flags).
	var tablet_lines: Array[String] = []
	var full_lore_id: String = "tablet_full"

	func _show_lore() -> void:
		var found: PackedStringArray = PackedStringArray()
		for i in range(tablet_lines.size()):
			if StoryManager.has_flag("frag_%d" % i):
				found.append(tablet_lines[i])
		if found.size() == 0:
			StoryManager.show_lore("tablet_empty")
		elif found.size() < tablet_lines.size():
			StoryManager.show_lore("tablet_partial", "\n\n" + "\n".join(found))
		elif full_lore_id == "tablet_full":
			StoryManager.show_lore(full_lore_id)
		else:
			StoryManager.show_lore(full_lore_id, "\n\n" + "\n".join(found))

class RiddleFragment extends StoryInteractable:
	## Hard mode fragment carrying one generated clue line.
	var clue_title: String = ""
	var clue_body: String = ""

	func _show_lore() -> void:
		StoryManager.show_text(clue_title, clue_body)

class SanctumLamp extends Interactable:
	## Hard mode: dark sanctum lamps. Lit by the player once the gate is open.
	signal lamp_lit(lamp: SanctumLamp)
	var is_lit: bool = false
	var _flame: MeshInstance3D = null
	var _glow: OmniLight3D = null

	func _init() -> void:
		show_beacon = false
		prompt_text = "Light the lamp"
		interact_radius = 2.6

	func _ready() -> void:
		super._ready()
		var stone: Color = Color(0.45, 0.43, 0.40)
		var bowl: MeshBuilder = MeshBuilder.new()
		bowl.add_cylinder(Transform3D.IDENTITY, 0.3, 0.2, 0.9, 7, stone.darkened(0.1), stone)
		bowl.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.9, 0.0)), 0.2, 0.34, 0.22, 8, stone, stone.lightened(0.08))
		add_mesh_child(bowl.build(GameMaterials.vertex_color()), "Bowl")
		var fb: MeshBuilder = MeshBuilder.new()
		fb.add_sphere(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 0.0)), Vector3(0.13, 0.24, 0.13), 3, 6, Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.4))
		_flame = add_mesh_child(fb.build(GameMaterials.emissive(Color(1.0, 0.6, 0.2), 3.2)), "Flame")
		_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame.visible = false
		_glow = OmniLight3D.new()
		_glow.position = Vector3(0.0, 1.4, 0.0)
		_glow.light_color = Color(1.0, 0.7, 0.4)
		_glow.omni_range = 7.0
		_glow.light_energy = 0.0
		add_child(_glow)
		add_box_collider(Vector3(0.7, 1.1, 0.7), Vector3(0.0, 0.55, 0.0))

	func can_interact() -> bool:
		return enabled and not is_lit

	func interact(_player: Node3D) -> void:
		if not QuestManager.is_objective_active("light_lamps"):
			return
		is_lit = true
		_flame.visible = true
		_glow.light_energy = 1.4
		lamp_lit.emit(self)

const GRANITE: Color = Color(0.52, 0.50, 0.47)
const LATERITE: Color = Color(0.58, 0.34, 0.22)
const TERRACOTTA: Color = Color(0.58, 0.25, 0.17)
const TOP: float = 0.9
## Seconds the pillars must sit untouched (all set, wrong) before the answer is judged wrong.
const PUZZLE_SETTLE_TIME: float = 2.5
## Rockfall zone on the hidden path in front of the ramp (world x, z).
const ROCKFALL_X: float = -41.5
const ROCKFALL_Z: float = -47.0
## Fragment hiding places (site space x, z). Normal uses the first three; Hard picks from all.
const FRAGMENT_SPOTS: Array[Vector2] = [Vector2(-10.0, 11.0), Vector2(11.0, -6.0), Vector2(-11.0, -12.0), Vector2(-8.5, 11.4), Vector2(8.5, 6.3), Vector2(3.0, -14.2), Vector2(-8.0, -14.2), Vector2(12.5, 3.6), Vector2(-12.5, -6.6), Vector2(10.5, 12.0)]
## Sanctum lamps (site space), Hard only.
const LAMP_SPOTS: Array[Vector2] = [Vector2(-4.6, -11.2), Vector2(4.6, -11.2), Vector2(0.0, -5.4)]
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]

var _site: Node3D = null
var _stone: MeshBuilder = MeshBuilder.new()
var _col_body: StaticBody3D = null
var _gate: StaticBody3D = null
var _gate_col: CollisionShape3D = null
var _light: OmniLight3D = null
var _pillars: Array[SymbolPillar] = []
var _solution: Array[int] = [0, 1, 2]
var _clues: Array[String] = []
var _puzzle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lamps_lit: int = 0
var _check_token: int = 0
var _lamps_done: bool = false
var _dark: float = 0.0
var _dark_sent: float = -1.0
var _dark_enabled: bool = false
var _player_ref: Node3D = null

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
	_puzzle_rng.randomize()
	_plan_puzzle()
	_build_puzzle()
	_build_fragments()
	_build_tablet()
	_build_altar()
	_build_hazards()
	_build_surroundings()
	_dark_enabled = GameSettings.pick_b(Tuning.SANCTUM_DARK_ON_NORMAL, Tuning.SANCTUM_DARK_ON_HARD)
	set_process(_dark_enabled)
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

# ---- puzzle planning (solution order + clue text) ------------------------------------------------
func _plan_puzzle() -> void:
	var count: int = GameSettings.pick_i(Tuning.PUZZLE_PILLARS_NORMAL, Tuning.PUZZLE_PILLARS_HARD)
	if count <= 3:
		_solution = [0, 1, 2]   # fixed order: the 3 stored clue lines describe exactly this order
		var lines: Array = StoryManager.get_tablet_lines()
		_clues.clear()
		for line: Variant in lines:
			_clues.append(str(line))
		return
	# Hard: five symbols in a random order, described by relative clues.
	var pool: Array[int] = [0, 1, 2, 4, 5]
	if GameSettings.pick_b(Tuning.PUZZLE_SHUFFLE_NORMAL, Tuning.PUZZLE_SHUFFLE_HARD):
		_shuffle_ints(pool)
	_solution = pool
	var riddle: Dictionary = StoryManager.get_riddle()
	var n: Array[String] = []
	for sym: int in _solution:
		n.append(SymbolPillar.NAMES[sym])
	var lines2: Array[String] = []
	lines2.append(str(riddle.get("west_end", "At the western end stands %s.")) % [n[0]])
	lines2.append(str(riddle.get("between", "%s stands between %s and %s.")) % [n[1], n[0], n[2]])
	lines2.append(str(riddle.get("middle", "In the heart of the row stands %s.")) % [n[2]])
	lines2.append(str(riddle.get("between", "%s stands between %s and %s.")) % [n[3], n[2], n[4]])
	lines2.append(str(riddle.get("east_end", "At the eastern end stands %s.")) % [n[4]])
	# shuffle the reading order so the lines do not simply list the row from west to east
	for i in range(lines2.size() - 1, 0, -1):
		var j: int = _puzzle_rng.randi_range(0, i)
		var tmp: String = lines2[i]
		lines2[i] = lines2[j]
		lines2[j] = tmp
	_clues = lines2

func _shuffle_ints(arr: Array[int]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _puzzle_rng.randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# ---- challenge 3: pillars ---------------------------------------------------------------------
func _build_puzzle() -> void:
	var count: int = _solution.size()
	var spacing: float = 4.0 if count <= 3 else 3.4
	var x0: float = -spacing * float(count - 1) * 0.5
	for i in range(count):
		var p: SymbolPillar = SymbolPillar.new()
		p.name = "SymbolPillar%d" % i
		p.pillar_index = i
		p.symbol_count = 4 if count <= 3 else SymbolPillar.NAMES.size()
		p.position = Vector3(x0 + spacing * float(i), TOP, 3.0)
		_site.add_child(p)
		p.symbol_changed.connect(_on_pillar_changed)
		_pillars.append(p)

func _on_pillar_changed(_idx: int, _sym: int) -> void:
	_check_token += 1
	for p: SymbolPillar in _pillars:
		if p.symbol == SymbolPillar.UNSET:
			return   # not every pillar has been set yet
	var correct: bool = true
	for i in range(_pillars.size()):
		if _pillars[i].symbol != _solution[i]:
			correct = false
			break
	if correct:
		for p2: SymbolPillar in _pillars:
			p2.lock_solved()
		QuestManager.complete_objective("symbols")
		return
	# Wrong so far: the player may still be turning a pillar through other symbols.
	# Only call it a failure after they stop turning for a moment.
	var token: int = _check_token
	get_tree().create_timer(PUZZLE_SETTLE_TIME).timeout.connect(func() -> void:
		if token == _check_token:
			_puzzle_failed()
	)

func _puzzle_failed() -> void:
	var lockout: float = GameSettings.pick_f(Tuning.PUZZLE_LOCKOUT_NORMAL, Tuning.PUZZLE_LOCKOUT_HARD)
	for p: SymbolPillar in _pillars:
		p.flash_wrong(lockout)
	GameInput.notice.emit("The stones groan and fall silent. The order is wrong. They reset in %d seconds." % int(ceil(lockout)))

# ---- challenge 2: fragments --------------------------------------------------------------------
func _build_fragments() -> void:
	var count: int = _solution.size()
	var spots: Array[Vector2] = []
	if GameSettings.is_hard():
		var order: Array[int] = []
		for k in range(FRAGMENT_SPOTS.size()):
			order.append(k)
		_shuffle_ints(order)
		for k2 in range(count):
			spots.append(FRAGMENT_SPOTS[order[k2]])
	else:
		for k3 in range(count):
			spots.append(FRAGMENT_SPOTS[k3])
	for i in range(count):
		var f: StoryInteractable
		if GameSettings.is_hard():
			var rf: RiddleFragment = RiddleFragment.new()
			rf.clue_title = "Inscription Fragment %s" % ROMAN[i]
			rf.clue_body = "A shard of carved stone. The worn script reads:\n\n\"%s\"" % _clues[i]
			f = rf
		else:
			f = StoryInteractable.new()
			f.lore_id = "fragment_%d" % (i + 1)
		f.name = "Fragment%d" % (i + 1)
		f.style = "fragment"
		f.show_beacon = false
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
	t.tablet_lines = _clues
	if GameSettings.is_hard():
		t.full_lore_id = "tablet_full_hard"
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
	for p: Vector2 in scatter_points(cx - r, cx + r, cz - r, cz + r, 9.5, 0.55, true):
		if Vector2(p.x - cx, p.y - cz).length() > 19.5:
			tree_pts.append(p)
	add_trees(filter_placeable(tree_pts, 2.5, 0.45, 3.5))
	var bush_pts: Array[Vector2] = []
	for p2: Vector2 in grid_points(cx - r, cx + r, cz - r, cz + r, 5.0, 2.0, 0.45, true):
		if Vector2(p2.x - cx, p2.y - cz).length() > 17.0:
			bush_pts.append(p2)
	add_bushes(filter_placeable(bush_pts, 2.5, 0.5, 2.5))
	var tuft_pts: Array[Vector2] = []
	for p3: Vector2 in scatter_points(cx - r, cx + r, cz - r, cz + r, 2.8, 0.9, true):
		if Vector2(p3.x - cx, p3.y - cz).length() > 16.5:
			tuft_pts.append(p3)
	add_tufts(filter_placeable(tuft_pts, 2.5, 0.55, 0.0))
	var rock_pts: Array[Vector2] = []
	for p4: Vector2 in grid_points(cx - r, cx + r, cz - r, cz + r, 8.0, 3.0, 0.5, true):
		if Vector2(p4.x - cx, p4.y - cz).length() > 17.5:
			rock_pts.append(p4)
	add_rocks(filter_placeable(rock_pts, 2.5, 0.7, 3.0), 1.2, 2.8, false)

# ---- hazards: falling rocks on the hidden path, dark sanctum with lamps (Hard) ----------------------
func _build_hazards() -> void:
	var rz: RockfallZone = RockfallZone.new()
	rz.name = "RockfallZone"
	rz.position = world_pos(ROCKFALL_X, ROCKFALL_Z, 0.0)
	add_child(rz)
	if GameSettings.pick_b(Tuning.SANCTUM_DARK_ON_NORMAL, Tuning.SANCTUM_DARK_ON_HARD):
		for spot: Vector2 in LAMP_SPOTS:
			var lamp: SanctumLamp = SanctumLamp.new()
			lamp.position = Vector3(spot.x, TOP, spot.y)
			_site.add_child(lamp)
			lamp.lamp_lit.connect(_on_lamp_lit)

func _on_lamp_lit(_lamp: SanctumLamp) -> void:
	_lamps_lit += 1
	if _lamps_lit >= LAMP_SPOTS.size():
		QuestManager.complete_objective("light_lamps")

## Screen darkness while the player stands in the unlit sanctum.
func _process(delta: float) -> void:
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D
		if _player_ref == null:
			return
	var local: Vector3 = _site.to_local(_player_ref.global_position)
	var inside: bool = absf(local.x) < 6.2 and local.z < -3.3 and local.z > -13.0
	var target: float = 1.0 if (inside and not _lamps_done) else 0.0
	_dark = move_toward(_dark, target, delta * Tuning.SANCTUM_DARK_FADE_SPEED)
	if absf(_dark - _dark_sent) > 0.01:
		_dark_sent = _dark
		GameInput.darkness_changed.emit(_dark * Tuning.SANCTUM_DARK_MAX_ALPHA)

# ---- reactions ----------------------------------------------------------------------------------
func _on_objective_completed(_quest_id: String, objective_id: String) -> void:
	if objective_id == "inscriptions":
		for p: SymbolPillar in _pillars:
			p.set_dormant(false)
	elif objective_id == "symbols":
		_open_gate()
	elif objective_id == "light_lamps":
		_lamps_done = true
		_light.light_energy = 2.2

func _open_gate() -> void:
	_gate_col.set_deferred("disabled", true)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_gate, "position:y", _gate.position.y - 3.8, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_light, "light_energy", 1.6, 3.0)
