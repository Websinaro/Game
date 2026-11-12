class_name ForestRegion
extends RegionBase
## The Whispering Grove: broadleaf forest with palms, undergrowth and a visible mud trail.
## Challenge 1 (hidden path): the trail ends at a wall of vines. A carved tree off the trail
## reveals the way; the vines part and lamps light up the hidden path to the ruins.

const GAP_X: float = -45.0
const GAP_Z: float = -30.0

var _barrier: VineBarrier = null
var _lamps: Node3D = null

func _populate() -> void:
	WorldRegistry.add_exclusion(-66.0, -8.0, 4.0)       # marked tree
	WorldRegistry.add_exclusion(GAP_X, GAP_Z, 13.0)     # vine barrier
	var r: float = region_radius
	var tree_pts: Array[Vector2] = grid_points(region_center.x - r, region_center.x + r, region_center.y - r, region_center.y + r, 5.5, 2.2, 0.62, true)
	var trees: Array[Vector2] = []
	for p: Vector2 in filter_placeable(tree_pts, 2.4, 0.45, 3.8):
		if p.y > -26.0 and p.y < 36.0:
			trees.append(p)
	add_trees(trees)
	var palm_pts: Array[Vector2] = grid_points(region_center.x - r, region_center.x + r, 18.0, 40.0, 11.0, 4.0, 0.45, true)
	add_palms(filter_placeable(palm_pts, 2.0, 0.4, 3.8))
	var bush_pts: Array[Vector2] = grid_points(region_center.x - r, region_center.x + r, region_center.y - r, 34.0, 4.0, 1.8, 0.45, true)
	var bushes: Array[Vector2] = []
	for p2: Vector2 in filter_placeable(bush_pts, 2.3, 0.5, 2.4):
		if p2.y > -27.0:
			bushes.append(p2)
	add_bushes(bushes)
	var tuft_pts: Array[Vector2] = grid_points(region_center.x - r, region_center.x + r, -27.0, 36.0, 2.3, 1.0, 0.55, true)
	add_tufts(filter_placeable(tuft_pts, 2.3, 0.55, 0.0))
	var banana_pts: Array[Vector2] = grid_points(region_center.x - r, region_center.x + r, -10.0, 36.0, 14.0, 4.0, 0.4, true)
	add_bananas(filter_placeable(banana_pts, 2.3, 0.4, 3.5))
	var rock_pts: Array[Vector2] = grid_points(region_center.x - r, region_center.x + r, -26.0, 36.0, 13.0, 5.0, 0.4, true)
	add_rocks(filter_placeable(rock_pts, 2.3, 0.6, 2.5), 0.8, 1.9, true)
	_marked_tree()
	_barrier = VineBarrier.new()
	_barrier.name = "VineBarrier"
	_barrier.position = world_pos(GAP_X, GAP_Z, -0.2)
	add_child(_barrier)
	_build_lamps()
	QuestManager.objective_completed.connect(_on_objective_completed)

func _marked_tree() -> void:
	var tree: StoryInteractable = StoryInteractable.new()
	tree.name = "MarkedTree"
	tree.style = "tree"
	tree.lore_id = "tree_mark"
	tree.objective_id = "hidden_path"
	tree.required_objective = "hidden_path"
	tree.locked_lore_id = "tree_locked"
	tree.prompt_text = "Touch the glowing sigil"
	tree.interact_radius = 3.4
	tree.position = world_pos(-66.0, -8.0, -0.1)
	tree.rotation.y = -PI * 0.5
	add_child(tree)

func _build_lamps() -> void:
	_lamps = Node3D.new()
	_lamps.name = "HiddenPathLamps"
	_lamps.visible = false
	add_child(_lamps)
	var start: Vector2 = Vector2(GAP_X, GAP_Z - 3.0)
	var finish: Vector2 = Vector2(-38.0, -56.0)
	var perp: Vector2 = (finish - start).orthogonal().normalized()
	for i in range(9):
		var t: float = float(i + 1) / 10.0
		var side: float = 2.4 if i % 2 == 0 else -2.4
		var p: Vector2 = start.lerp(finish, t) + perp * side
		var stone: MeshBuilder = MeshBuilder.new()
		stone.add_cylinder(Transform3D.IDENTITY, 0.28, 0.2, 0.7, 6, Color(0.40, 0.38, 0.35), Color(0.52, 0.50, 0.46))
		var lamp: Node3D = Node3D.new()
		lamp.position = world_pos(p.x, p.y, -0.05)
		_lamps.add_child(lamp)
		var base_mi: MeshInstance3D = MeshInstance3D.new()
		base_mi.mesh = stone.build(GameMaterials.vertex_color())
		lamp.add_child(base_mi)
		var flame: MeshBuilder = MeshBuilder.new()
		flame.add_sphere(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.88, 0.0)), Vector3(0.1, 0.17, 0.1), 3, 6, Color(1.0, 0.6, 0.2), Color(1.0, 0.8, 0.4))
		var flame_mi: MeshInstance3D = MeshInstance3D.new()
		flame_mi.mesh = flame.build(GameMaterials.emissive(Color(1.0, 0.6, 0.2), 3.0))
		flame_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(flame_mi)

func _on_objective_completed(_quest_id: String, objective_id: String) -> void:
	if objective_id != "hidden_path":
		return
	_barrier.dissolve()
	_lamps.visible = true
	var i: int = 0
	for child: Node in _lamps.get_children():
		var lamp: Node3D = child as Node3D
		lamp.scale = Vector3.ZERO
		var tw: Tween = create_tween()
		tw.tween_interval(0.25 * float(i))
		tw.tween_property(lamp, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
