class_name SymbolPillar
extends Interactable
## Puzzle pillar. Each use cycles the floating symbol: SEA, FOREST, MOUNTAIN, AXE.
## Dormant until the inscription fragments have been collected.

signal symbol_changed(pillar_index: int, symbol: int)

const NAMES: Array[String] = ["SEA", "FOREST", "MOUNTAIN", "AXE"]
const COLORS: Array[Color] = [Color(0.30, 0.70, 1.00), Color(0.40, 0.95, 0.40), Color(1.00, 0.75, 0.30), Color(1.00, 0.35, 0.30)]

@export var pillar_index: int = 0

var symbol: int = 3
var dormant: bool = true
var locked: bool = false
var _icon: MeshInstance3D = null
var _label: Label3D = null

func _init() -> void:
	show_beacon = false
	interact_radius = 2.8

func _ready() -> void:
	super._ready()
	var mb: MeshBuilder = MeshBuilder.new()
	var stone: Color = Color(0.50, 0.48, 0.45)
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2, 0.0)), Vector3(1.3, 0.4, 1.3), stone.darkened(0.15))
	mb.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.4, 0.0)), 0.48, 0.42, 2.1, 8, stone.darkened(0.1), stone)
	mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.65, 0.0)), Vector3(1.1, 0.3, 1.1), stone.lightened(0.05))
	add_mesh_child(mb.build(GameMaterials.vertex_color()), "Pillar")
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.6
	shape.height = 2.8
	cs.shape = shape
	cs.position = Vector3(0.0, 1.4, 0.0)
	body.add_child(cs)
	add_child(body)
	_icon = MeshInstance3D.new()
	_icon.name = "Icon"
	_icon.position = Vector3(0.0, 3.5, 0.0)
	_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_icon)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.008
	_label.font_size = 48
	_label.outline_size = 12
	_label.position = Vector3(0.0, 4.2, 0.0)
	add_child(_label)
	_refresh()

func get_prompt() -> String:
	if dormant:
		return "Examine the pillar"
	return "Turn the stone (%s)" % NAMES[symbol]

func set_dormant(value: bool) -> void:
	dormant = value
	_refresh()

func set_symbol(value: int) -> void:
	symbol = value % NAMES.size()
	_refresh()

func lock_solved() -> void:
	locked = true
	enabled = false
	_refresh()
	_label.text = NAMES[symbol]
	_label.modulate = Color(1.0, 0.9, 0.5)

func interact(_player: Node3D) -> void:
	if dormant:
		StoryManager.show_lore("pillars_dormant")
		return
	if locked:
		return
	symbol = (symbol + 1) % NAMES.size()
	_refresh()
	_icon.scale = Vector3.ONE * 1.5
	var tw: Tween = create_tween()
	tw.tween_property(_icon, "scale", Vector3.ONE, 0.25)
	symbol_changed.emit(pillar_index, symbol)

func _refresh() -> void:
	var col: Color = Color(0.45, 0.45, 0.5) if dormant else COLORS[symbol]
	_icon.mesh = _build_icon(symbol).build(GameMaterials.emissive(col, 0.4 if dormant else 2.2))
	_label.text = "?" if dormant else NAMES[symbol]
	_label.modulate = Color(0.7, 0.7, 0.75) if dormant else COLORS[symbol]

func _build_icon(sym: int) -> MeshBuilder:
	var mb: MeshBuilder = MeshBuilder.new()
	var c: Color = Color.WHITE
	match sym:
		0:
			for row in range(2):
				var pts: PackedVector3Array = PackedVector3Array()
				var rad: PackedFloat32Array = PackedFloat32Array()
				for i in range(11):
					var x: float = -0.5 + float(i) * 0.1
					pts.append(Vector3(x, 0.14 - float(row) * 0.28 + 0.08 * sin(x * 12.0 + float(row)), 0.0))
					rad.append(0.04)
				mb.add_tube(pts, rad, 4, c, c)
		1:
			for i in range(3):
				mb.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.1 + float(i) * 0.2, 0.0)), 0.34 - float(i) * 0.08, 0.02, 0.36, 6, c, c, false, false)
			mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.3, 0.0)), Vector3(0.08, 0.2, 0.08), c)
		2:
			mb.add_cylinder(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(-0.22, -0.3, 0.0)), 0.34, 0.0, 0.55, 4, c, c, false, false)
			mb.add_cylinder(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0.2, -0.3, 0.0)), 0.44, 0.0, 0.8, 4, c, c, false, false)
		_:
			mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)), Vector3(0.07, 0.85, 0.07), c)
			mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.2, 0.22, 0.0)), Vector3(0.36, 0.3, 0.06), c)
			mb.add_box(Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 0.5)), Vector3(0.42, 0.22, 0.0)), Vector3(0.14, 0.2, 0.06), c)
	return mb
