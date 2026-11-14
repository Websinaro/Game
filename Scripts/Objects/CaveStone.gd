class_name CaveStone
extends Interactable
## One of the three stones lying around the cave (Phase 1, cave door puzzle).
## stone_id: 0 = SEA, 1 = FOREST, 2 = MOUNTAIN (same order as SymbolPillar.NAMES / COLORS).
## Taking it sets the story flag "stone_<id>" and adds one unit of progress to objective "stones".

signal collected(stone: CaveStone)

const NAMES: Array[String] = ["SEA", "FOREST", "MOUNTAIN"]
const LORE_IDS: Array[String] = ["stone_sea", "stone_forest", "stone_mountain"]
const COLORS: Array[Color] = [Color(0.30, 0.70, 1.00), Color(0.40, 0.95, 0.40), Color(1.00, 0.75, 0.30)]

@export var stone_id: int = 0

var _gem: MeshInstance3D = null
var _taken: bool = false

func _init() -> void:
	prompt_text = "Take the stone"
	interact_radius = 2.8
	beacon_height = 1.6

func _ready() -> void:
	super._ready()
	var col: Color = COLORS[clampi(stone_id, 0, COLORS.size() - 1)]
	var base: MeshBuilder = MeshBuilder.new()
	var rock: Color = Color(0.40, 0.38, 0.35)
	base.add_cylinder(Transform3D.IDENTITY, 0.55, 0.42, 0.18, 7, rock.darkened(0.2), rock)
	base.add_sphere(Transform3D(Basis.IDENTITY, Vector3(0.28, 0.12, 0.1)), Vector3(0.22, 0.14, 0.2), 3, 6, rock.darkened(0.15), rock, 0.2, float(stone_id))
	add_mesh_child(base.build(GameMaterials.vertex_color()), "Base")
	var gem: MeshBuilder = MeshBuilder.new()
	gem.add_sphere(Transform3D.IDENTITY, Vector3(0.24, 0.3, 0.24), 3, 6, col.darkened(0.15), col, 0.12, float(stone_id) + 3.0)
	_gem = add_mesh_child(gem.build(GameMaterials.emissive(col, 1.7)), "Gem")
	_gem.position = Vector3(0.0, 0.62, 0.0)
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(true)

func _process(delta: float) -> void:
	super(delta)
	if _gem != null:
		_gem.rotate_y(delta * 1.1)

func interact(_player: Node3D) -> void:
	if _taken:
		return
	if not QuestManager.is_objective_active("stones"):
		StoryManager.show_lore("stone_locked")
		return
	_taken = true
	enabled = false
	StoryManager.set_flag("stone_%d" % stone_id)
	StoryManager.show_lore(LORE_IDS[clampi(stone_id, 0, LORE_IDS.size() - 1)])
	QuestManager.progress_objective("stones")
	collected.emit(self)
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
	tw.tween_callback(queue_free)
