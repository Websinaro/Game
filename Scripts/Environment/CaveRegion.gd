class_name CaveRegion
extends RegionBase
## The First Cave (replaces the old Forgotten Sanctum as the end of the hidden path).
## Built in "site" space: origin = plateau ground, +Z = front (south, where the hidden path arrives).
##
## Story flow (Data/quests.json, quest "lost_axe"):
##   stones  - find the SEA, FOREST and MOUNTAIN stones lying around the cave        (CaveStone)
##   door    - set them in the three hollows of the stone door, in the right order  (StoneSocket)
##   pantham - go into the dark first chamber and take the pantham (torch)          (PanthamPickup)
##   altar   - follow the passage to the station and read it                        (AncientClue)
##
## The cave itself is Assets/Models/cave_lp.glb: your Sketchfab cave, cleaned and baked offline
## (stray sphere removed, flat floor added, doorway cut, oriented so the doorway faces +Z, floor at y = 0).
## Model units are scaled by CAVE_SCALE. The layout numbers below are in MODEL units (u) unless
## the name says SITE; _cave_site() converts them.

const CAVE_MODEL: String = "res://Assets/Models/cave_lp.glb"
const CAVE_SCALE: float = 4.5
## Site-space Z of the doorway plane (the front tip of the cave). The cave runs from here towards -Z.
const DOOR_Z: float = 6.0
## Cave floor sits this far above the flattened terrain so the two surfaces never z-fight.
const FLOOR_LIFT: float = 0.06
## Door slab sits just in front of the doorway (model units along Z, positive = outside).
const DOOR_PLANE_U: float = 0.10
const DOOR_WIDTH: float = 4.9
const DOOR_HEIGHT: float = 4.7
const DOOR_THICK: float = 0.9
## Correct stone order, west to east on the door: SEA, FOREST, MOUNTAIN (CaveStone.NAMES).
## Phase 2 hardening: make this random per playthrough and generate the stele text from it.
const SOLUTION: Array[int] = [0, 1, 2]
## Where the stones lie (site space x, z). All are on the flat plateau, none are in the cave footprint.
const STONE_SPOTS: Array[Vector2] = [Vector2(-15.0, 11.0), Vector2(15.5, 9.0), Vector2(-11.0, -12.0)]
## Pantham pedestal in the first chamber and the station in the second chamber (model units x, z).
const PANTHAM_SPOT_U: Vector2 = Vector2(-0.75, -1.5)
const STATION_SPOT_U: Vector2 = Vector2(0.5, -5.0)
const SIGIL_ROW_Z_U: float = -4.2
## Seconds the sockets must sit untouched (all full, wrong) before the answer is judged wrong.
const PUZZLE_SETTLE_TIME: float = 2.5

const GRANITE: Color = Color(0.46, 0.44, 0.41)
const GLOW: Color = Color(0.45, 0.92, 0.85)

var _site: Node3D = null
var _cave: Node3D = null
var _stone: MeshBuilder = MeshBuilder.new()
var _col_body: StaticBody3D = null
var _door: StaticBody3D = null
var _door_col: CollisionShape3D = null
var _sockets: Array[StoneSocket] = []
var _placed: Array[int] = [-1, -1, -1]
var _check_token: int = 0
var _door_open: bool = false
var _has_torch: bool = false
var _pantham: PanthamPickup = null
var _station_light: OmniLight3D = null
var _sigils_dim: MeshInstance3D = null
var _sigils_lit: MeshInstance3D = null
var _dark: float = 0.0
var _dark_sent: float = -1.0
var _player_ref: Node3D = null

func _populate() -> void:
	_site = Node3D.new()
	_site.name = "Site"
	_site.position = world_pos(region_center.x, region_center.y, 0.0)
	add_child(_site)
	_col_body = StaticBody3D.new()
	_col_body.name = "CaveColliders"
	_col_body.collision_layer = 1
	_col_body.collision_mask = 0
	_site.add_child(_col_body)
	_register_exclusions()
	_build_cave_shell()
	_build_plaza()
	_build_door()
	_build_stones()
	_build_stele()
	_build_interior()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CaveStone"
	mi.mesh = _stone.build(GameMaterials.vertex_color())
	_site.add_child(mi)
	_build_surroundings()
	set_process(true)
	QuestManager.objective_completed.connect(_on_objective_completed)

## Site-space position from model-unit coordinates (x, z) on the cave floor.
func _cave_site(mx: float, mz: float) -> Vector3:
	return Vector3(mx * CAVE_SCALE, FLOOR_LIFT, DOOR_Z + mz * CAVE_SCALE)

func _register_exclusions() -> void:
	var cx: float = region_center.x
	var cz: float = region_center.y
	WorldRegistry.add_exclusion(cx, cz, 19.0)
	# the cave body runs from the doorway (site z = DOOR_Z) about 26 m towards -Z
	for dz in [-4.0, -11.0, -18.0, -24.0]:
		WorldRegistry.add_exclusion(cx + 0.5, cz + DOOR_Z + float(dz), 8.5)
	for spot: Vector2 in STONE_SPOTS:
		WorldRegistry.add_exclusion(cx + spot.x, cz + spot.y, 2.6)

# ---- the cave model -----------------------------------------------------------------------------
func _build_cave_shell() -> void:
	_cave = Node3D.new()
	_cave.name = "CaveShell"
	_cave.position = Vector3(0.0, FLOOR_LIFT, DOOR_Z)
	_cave.scale = Vector3.ONE * CAVE_SCALE
	_site.add_child(_cave)
	if not ResourceLoader.exists(CAVE_MODEL):
		push_error("CaveRegion: '%s' is missing or not imported yet. Copy cave_lp.glb into Assets/Models and open the project once." % CAVE_MODEL)
		return
	var packed: PackedScene = load(CAVE_MODEL) as PackedScene
	if packed == null:
		push_error("CaveRegion: could not load " + CAVE_MODEL)
		return
	var inst: Node = packed.instantiate()
	_cave.add_child(inst)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(inst, meshes)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CaveShellCollider"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.0, FLOOR_LIFT, DOOR_Z)
	_site.add_child(body)
	for m: MeshInstance3D in meshes:
		if m.mesh == null:
			continue
		for s in range(m.mesh.get_surface_count()):
			var mat: Material = m.get_active_material(s)
			var std: StandardMaterial3D = mat as StandardMaterial3D
			if std != null:
				var dark: StandardMaterial3D = std.duplicate() as StandardMaterial3D
				dark.albedo_color = Color(0.64, 0.61, 0.58)
				m.set_surface_override_material(s, dark)
		# Collision: the mesh faces scaled by CAVE_SCALE (a scaled physics body is unreliable).
		var faces: PackedVector3Array = m.mesh.get_faces()
		var scaled: PackedVector3Array = PackedVector3Array()
		scaled.resize(faces.size())
		for k in range(faces.size()):
			scaled[k] = faces[k] * CAVE_SCALE
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(scaled)
		shape.backface_collision = true
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null:
		out.append(mi)
	for child: Node in node.get_children():
		_collect_meshes(child, out)

# ---- stone helpers ----------------------------------------------------------------------------------
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
	_stone.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(x, FLOOR_LIFT, z)), 0.6, 0.5, h, 8, GRANITE.darkened(0.12), GRANITE)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.6
	shape.height = h
	cs.shape = shape
	cs.position = Vector3(x, FLOOR_LIFT + h * 0.5, z)
	_col_body.add_child(cs)
	_stone.add_box(Transform3D(Basis.IDENTITY, Vector3(x, FLOOR_LIFT + h + 0.15, z)), Vector3(1.4, 0.3, 1.4), GRANITE.lightened(0.05))

# ---- plaza and door ------------------------------------------------------------------------------------
func _build_plaza() -> void:
	# flat paving in front of the doorway (visual only: the flattened terrain is the floor)
	var y: float = FLOOR_LIFT + 0.02
	_box(Vector3(0.0, y, DOOR_Z + 5.0), Vector3(9.0, 0.08, 9.0), GRANITE.darkened(0.22), Basis.IDENTITY, false)
	_box(Vector3(0.0, y + 0.02, DOOR_Z + 10.0), Vector3(5.0, 0.08, 4.0), GRANITE.darkened(0.15), Basis.IDENTITY, false)
	for k in range(7):
		var jx: float = rng.randf_range(-3.5, 3.5)
		var jz: float = rng.randf_range(1.0, 8.0)
		var r: float = rng.randf_range(0.15, 0.4)
		_stone.add_sphere(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(jx, y + 0.05, DOOR_Z + jz)), Vector3(r, r * 0.5, r), 3, 6, GRANITE.darkened(0.2), GRANITE, 0.25, float(k))

func _build_door() -> void:
	var dz: float = DOOR_Z + DOOR_PLANE_U * CAVE_SCALE
	_column(-3.4, dz + 0.6, 5.6)
	_column(3.4, dz + 0.6, 5.6)
	_door = StaticBody3D.new()
	_door.name = "StoneDoor"
	_door.collision_layer = 1
	_door.collision_mask = 0
	_door.position = Vector3(0.0, FLOOR_LIFT, dz)
	_site.add_child(_door)
	var mb: MeshBuilder = MeshBuilder.new()
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, DOOR_HEIGHT * 0.5, 0.0)), Vector3(DOOR_WIDTH, DOOR_HEIGHT, DOOR_THICK), GRANITE.lightened(0.04), GRANITE.lightened(0.1))
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, DOOR_HEIGHT + 0.12, 0.0)), Vector3(DOOR_WIDTH + 0.5, 0.3, DOOR_THICK + 0.3), GRANITE.darkened(0.05))
	var dmi: MeshInstance3D = MeshInstance3D.new()
	dmi.name = "Slab"
	dmi.mesh = mb.build(GameMaterials.vertex_color())
	_door.add_child(dmi)
	# carved glowing lines: a central seam and an arch of three bars above the sockets
	var gb: MeshBuilder = MeshBuilder.new()
	var front: float = DOOR_THICK * 0.5 + 0.02
	gb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, DOOR_HEIGHT * 0.5, front)), Vector3(0.07, DOOR_HEIGHT - 0.6, 0.03), GLOW)
	for i in range(3):
		gb.add_box(Transform3D(Basis.IDENTITY, Vector3(-1.3 + float(i) * 1.3, 2.75, front)), Vector3(0.7, 0.06, 0.03), GLOW)
		gb.add_box(Transform3D(Basis.IDENTITY, Vector3(-1.3 + float(i) * 1.3, 0.8, front)), Vector3(0.06, 0.8, 0.03), GLOW)
	var gmi: MeshInstance3D = MeshInstance3D.new()
	gmi.name = "Carvings"
	gmi.mesh = gb.build(GameMaterials.emissive(GLOW, 1.1))
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_door.add_child(gmi)
	_door_col = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(DOOR_WIDTH, DOOR_HEIGHT, DOOR_THICK)
	_door_col.shape = shape
	_door_col.position = Vector3(0.0, DOOR_HEIGHT * 0.5, 0.0)
	_door.add_child(_door_col)
	for i in range(3):
		var sock: StoneSocket = StoneSocket.new()
		sock.name = "Socket%d" % i
		sock.socket_index = i
		sock.position = Vector3(-1.3 + float(i) * 1.3, 1.7, front)
		_door.add_child(sock)
		sock.cycle_requested.connect(_on_socket_cycle)
		_sockets.append(sock)

# ---- stones, stele ---------------------------------------------------------------------------------------
func _build_stones() -> void:
	for i in range(STONE_SPOTS.size()):
		var st: CaveStone = CaveStone.new()
		st.name = "Stone%d" % i
		st.stone_id = i
		st.position = Vector3(STONE_SPOTS[i].x, FLOOR_LIFT, STONE_SPOTS[i].y)
		_site.add_child(st)

func _build_stele() -> void:
	var t: StoryInteractable = StoryInteractable.new()
	t.name = "CarvedStele"
	t.style = "tablet"
	t.lore_id = "cave_tablet"
	t.prompt_text = "Read the carved stone"
	t.interact_radius = 3.6
	t.position = Vector3(7.5, FLOOR_LIFT, DOOR_Z + 5.5)
	t.rotation.y = PI * 0.88
	_site.add_child(t)

# ---- inside the cave ---------------------------------------------------------------------------------------
func _build_interior() -> void:
	_pantham = PanthamPickup.new()
	_pantham.name = "Pantham"
	_pantham.position = _cave_site(PANTHAM_SPOT_U.x, PANTHAM_SPOT_U.y)
	_site.add_child(_pantham)
	_pantham.taken.connect(_attach_torch)
	var station_pos: Vector3 = _cave_site(STATION_SPOT_U.x, STATION_SPOT_U.y)
	var packed: PackedScene = load("res://Scenes/Objects/AncientClue.tscn") as PackedScene
	var clue: AncientClue = packed.instantiate() as AncientClue
	clue.name = "Station"
	clue.position = station_pos
	clue.rotation.y = PI
	_site.add_child(clue)
	# four small floor sigils in front of the station: the four trials still to come
	var dim: MeshBuilder = MeshBuilder.new()
	var lit: MeshBuilder = MeshBuilder.new()
	for i in range(4):
		var p: Vector3 = _cave_site(STATION_SPOT_U.x + (float(i) - 1.5) * 0.2, SIGIL_ROW_Z_U)
		dim.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(p.x, p.y + 0.03, p.z)), 0.42, 0.36, 0.06, 8, GLOW, GLOW)
		lit.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(p.x, p.y + 0.03, p.z)), 0.42, 0.36, 0.06, 8, GLOW, GLOW)
	_sigils_dim = MeshInstance3D.new()
	_sigils_dim.name = "SigilsDim"
	_sigils_dim.mesh = dim.build(GameMaterials.emissive(GLOW, 0.5))
	_sigils_dim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_site.add_child(_sigils_dim)
	_sigils_lit = MeshInstance3D.new()
	_sigils_lit.name = "SigilsLit"
	_sigils_lit.mesh = lit.build(GameMaterials.emissive(GLOW, 3.0))
	_sigils_lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sigils_lit.visible = false
	_site.add_child(_sigils_lit)
	_station_light = OmniLight3D.new()
	_station_light.name = "StationLight"
	_station_light.position = Vector3(station_pos.x, station_pos.y + 2.2, station_pos.z + 2.5)
	_station_light.light_color = GLOW
	_station_light.omni_range = 9.0
	_station_light.light_energy = 0.5
	_station_light.shadow_enabled = false
	_site.add_child(_station_light)

func _attach_torch() -> void:
	if _has_torch:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	_has_torch = true
	var host: Node3D = player
	var mr: Variant = player.get("model_root")
	if mr is Node3D:
		host = mr as Node3D
	var torch: PanthamTorch = PanthamTorch.new()
	torch.name = "PanthamTorch"
	torch.position = Vector3(0.5, 0.75, -0.25)
	host.add_child(torch)

# ---- door puzzle ---------------------------------------------------------------------------------------------
func _on_socket_cycle(socket: StoneSocket) -> void:
	var idx: int = socket.socket_index
	var cur: int = _placed[idx]
	var ring: Array[int] = [0, 1, 2, -1]
	var start: int = ring.find(cur)
	var chosen: int = -1
	for step in range(1, ring.size() + 1):
		var cand: int = ring[(start + step) % ring.size()]
		if cand < 0:
			chosen = -1
			break
		if StoryManager.has_flag("stone_%d" % cand) and (cand == cur or not _placed.has(cand)):
			chosen = cand
			break
	_placed[idx] = chosen
	socket.set_stone(chosen)
	_check_token += 1
	for v: int in _placed:
		if v < 0:
			return   # not every hollow has a stone yet
	var correct: bool = true
	for i in range(SOLUTION.size()):
		if _placed[i] != SOLUTION[i]:
			correct = false
			break
	if correct:
		for s: StoneSocket in _sockets:
			s.lock_solved()
		QuestManager.complete_objective("door")
		return
	# Wrong so far: the player may still be swapping stones. Judge only after they stop for a moment.
	var token: int = _check_token
	get_tree().create_timer(PUZZLE_SETTLE_TIME).timeout.connect(func() -> void:
		if token == _check_token:
			_puzzle_failed()
	)

func _puzzle_failed() -> void:
	var lockout: float = GameSettings.pick_f(Tuning.CAVE_LOCKOUT_NORMAL, Tuning.CAVE_LOCKOUT_HARD)
	for i in range(_placed.size()):
		_placed[i] = -1
	for s: StoneSocket in _sockets:
		s.flash_wrong(lockout)
	GameInput.notice.emit("The door shudders and the stones fall dark. The order is wrong. It settles in %d seconds." % int(ceil(lockout)))

func _open_door() -> void:
	_door_open = true
	_door_col.set_deferred("disabled", true)
	var tw: Tween = create_tween()
	tw.tween_property(_door, "position:y", _door.position.y - 6.5, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---- darkness inside the cave ---------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D
		if _player_ref == null:
			return
	var inside: bool = false
	if _door_open and _cave != null and _cave.is_inside_tree():
		var m: Vector3 = _cave.to_local(_player_ref.global_position)
		inside = m.z < -0.2 and m.z > -6.2 and absf(m.x) < 2.2 and m.y > -0.6 and m.y < 3.5
	var target: float = 0.0
	if inside:
		if _has_torch:
			target = GameSettings.pick_f(Tuning.CAVE_DARK_TORCH_NORMAL, Tuning.CAVE_DARK_TORCH_HARD)
		else:
			target = Tuning.CAVE_DARK_NO_TORCH
	_dark = move_toward(_dark, target, delta * Tuning.SANCTUM_DARK_FADE_SPEED)
	if absf(_dark - _dark_sent) > 0.01:
		_dark_sent = _dark
		GameInput.darkness_changed.emit(_dark)

# ---- reactions ------------------------------------------------------------------------------------------------------
func _on_objective_completed(_quest_id: String, objective_id: String) -> void:
	if objective_id == "door":
		_open_door()
	elif objective_id == "altar":
		_sigils_dim.visible = false
		_sigils_lit.visible = true
		var tw: Tween = create_tween()
		tw.tween_property(_station_light, "light_energy", 2.2, 2.0)

# ---- surroundings -------------------------------------------------------------------------------------------------------
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
	# big rocks hugging the foot of the cave so the mound looks like part of the mountain
	var foot: Array[Vector2] = [Vector2(cx - 8.5, cz + DOOR_Z - 4.0), Vector2(cx + 9.5, cz + DOOR_Z - 6.0), Vector2(cx - 8.0, cz + DOOR_Z - 13.0), Vector2(cx + 8.5, cz + DOOR_Z - 15.0), Vector2(cx - 5.5, cz + DOOR_Z - 22.0), Vector2(cx + 5.5, cz + DOOR_Z - 23.0)]
	add_rocks(foot, 1.8, 3.0, true)
