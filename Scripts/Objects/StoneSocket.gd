class_name StoneSocket
extends Interactable
## A hollow in the great cave door. Each use asks CaveRegion to put the next collected stone
## into this socket (cycle: empty -> stone -> stone -> stone -> empty). The region owns the rules.

signal cycle_requested(socket: StoneSocket)

@export var socket_index: int = 0

## -1 = empty, otherwise a stone id (CaveStone.NAMES).
var stone: int = -1
var locked: bool = false
var _lockout_until_ms: int = 0
var _gem: MeshInstance3D = null
var _label: Label3D = null

func _init() -> void:
	show_beacon = false
	prompt_text = "Examine the hollow"
	interact_radius = 3.2

func _ready() -> void:
	super._ready()
	var ring: MeshBuilder = MeshBuilder.new()
	var rock: Color = Color(0.30, 0.28, 0.26)
	ring.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, 0.0)), 0.52, 0.46, 0.14, 10, rock.darkened(0.2), rock, true, false)
	add_mesh_child(ring.build(GameMaterials.vertex_color()), "Ring")
	_gem = MeshInstance3D.new()
	_gem.name = "Gem"
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gem.position = Vector3(0.0, 0.0, 0.16)
	add_child(_gem)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.008
	_label.font_size = 40
	_label.outline_size = 10
	_label.position = Vector3(0.0, 0.85, 0.2)
	add_child(_label)
	_refresh()

func get_prompt() -> String:
	if locked:
		return "The stone is fixed"
	if Time.get_ticks_msec() < _lockout_until_ms:
		return "The door is settling..."
	if stone < 0:
		return "Place a stone"
	return "Change the stone (%s)" % CaveStone.NAMES[stone]

func can_interact() -> bool:
	return enabled and not locked

func interact(_player: Node3D) -> void:
	if not QuestManager.is_objective_active("door"):
		StoryManager.show_lore("socket_locked")
		return
	if Time.get_ticks_msec() < _lockout_until_ms:
		GameInput.notice.emit("The door is still settling. Wait.")
		return
	cycle_requested.emit(self)

func set_stone(value: int) -> void:
	stone = value
	_refresh()
	if _gem != null:
		_gem.scale = Vector3.ONE * 1.5
		var tw: Tween = create_tween()
		tw.tween_property(_gem, "scale", Vector3.ONE, 0.25)

func lock_solved() -> void:
	locked = true
	_refresh()
	if stone >= 0:
		_label.modulate = Color(1.0, 0.9, 0.5)

## Wrong order: glow red, then go empty and dead for lockout_seconds.
func flash_wrong(lockout_seconds: float) -> void:
	_lockout_until_ms = Time.get_ticks_msec() + int(lockout_seconds * 1000.0)
	var red: Color = Color(1.0, 0.15, 0.1)
	var gb: MeshBuilder = MeshBuilder.new()
	gb.add_sphere(Transform3D.IDENTITY, Vector3(0.26, 0.26, 0.14), 3, 6, red, red)
	_gem.mesh = gb.build(GameMaterials.emissive(red, 3.0))
	_label.modulate = red
	var tw: Tween = create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(set_stone.bind(-1))

func _refresh() -> void:
	if stone < 0:
		_gem.mesh = null
		_label.text = ""
		return
	var col: Color = CaveStone.COLORS[stone]
	var gb: MeshBuilder = MeshBuilder.new()
	gb.add_sphere(Transform3D.IDENTITY, Vector3(0.26, 0.26, 0.14), 3, 6, col.darkened(0.15), col, 0.08, float(stone))
	_gem.mesh = gb.build(GameMaterials.emissive(col, 2.4))
	_label.text = CaveStone.NAMES[stone]
	_label.modulate = col
