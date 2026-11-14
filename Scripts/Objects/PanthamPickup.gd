class_name PanthamPickup
extends Interactable
## The pantham (torch) lying in the dark first chamber of the cave.
## A faint ember glow is the only light, so the player has to look for it.
## Taking it completes objective "pantham"; CaveRegion then attaches a PanthamTorch to the player.

signal taken()

var _ember: MeshInstance3D = null
var _glow: OmniLight3D = null
var _t: float = 0.0
var _done: bool = false

func _init() -> void:
	prompt_text = "Take the pantham"
	interact_radius = 3.0
	beacon_height = 1.7

func _ready() -> void:
	super._ready()
	var wood: Color = Color(0.34, 0.21, 0.10)
	var rock: Color = Color(0.36, 0.34, 0.31)
	var mb: MeshBuilder = MeshBuilder.new()
	mb.add_cylinder(Transform3D.IDENTITY, 0.7, 0.55, 0.6, 8, rock.darkened(0.2), rock)
	mb.add_box(Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 1.25)), Vector3(0.0, 0.78, 0.0)), Vector3(0.08, 0.95, 0.08), wood)
	mb.add_cylinder(Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 1.25)), Vector3(0.43, 0.88, 0.0)), 0.1, 0.13, 0.24, 7, Color(0.14, 0.09, 0.06), Color(0.26, 0.16, 0.08))
	add_mesh_child(mb.build(GameMaterials.vertex_color()), "Pedestal")
	var eb: MeshBuilder = MeshBuilder.new()
	eb.add_sphere(Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(0.07, 0.09, 0.07), 2, 5, Color(1.0, 0.4, 0.1), Color(1.0, 0.7, 0.3))
	_ember = add_mesh_child(eb.build(GameMaterials.emissive(Color(1.0, 0.45, 0.12), 3.0)), "Ember")
	_ember.position = Vector3(0.62, 1.12, 0.0)
	_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0.62, 1.2, 0.0)
	_glow.light_color = Color(1.0, 0.55, 0.25)
	_glow.omni_range = 4.5
	_glow.light_energy = 0.6
	_glow.shadow_enabled = false
	add_child(_glow)
	add_box_collider(Vector3(1.3, 0.6, 1.3), Vector3(0.0, 0.3, 0.0))
	set_process(true)

func _process(delta: float) -> void:
	super(delta)
	_t += delta
	if _glow != null:
		_glow.light_energy = 0.55 + 0.15 * sin(_t * 3.1) + 0.05 * sin(_t * 9.0)

func interact(_player: Node3D) -> void:
	if _done:
		return
	if not QuestManager.is_objective_active("pantham"):
		return
	_done = true
	enabled = false
	StoryManager.set_flag("has_pantham")
	StoryManager.show_lore("pantham_taken")
	QuestManager.complete_objective("pantham")
	taken.emit()
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tw.tween_callback(queue_free)
