extends Node
## Entry point. Builds the world behind a loading screen, plays the intro,
## then hands control to the player and starts the first quest.

@onready var world: WorldManager = $World
@onready var player: PlayerController = $Player
@onready var cinematic_camera: Camera3D = $CinematicCamera
@onready var ui_layer: CanvasLayer = $UI
@onready var hud: GameHUD = $UI/GameHUD
@onready var touch: MobileControls = $UI/MobileControls
@onready var pause_menu: PauseMenu = $UI/PauseMenu
@onready var intro: IntroCinematic = $UI/IntroCinematic

func _ready() -> void:
	cinematic_camera.make_current()
	hud.visible = false
	touch.visible = false
	var loading: ColorRect = ColorRect.new()
	loading.color = Color(0.05, 0.04, 0.03, 1.0)
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	var msg: Label = GameHUD.make_label("Preparing the shore...", 34, Color(1.0, 0.9, 0.6))
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg.custom_minimum_size = Vector2(700.0, 0.0)
	loading.add_child(msg)
	ui_layer.add_child(loading)
	await get_tree().process_frame
	await get_tree().process_frame
	world.build_world()
	var spawn: Vector3 = world.get_spawn_position()
	player.teleport(spawn + Vector3(0.0, 0.2, 0.0), 0.0)
	player.camera_rig.snap_to_target()
	world.set_tracked(player)
	world.region_changed.connect(_on_region_changed)
	hud.pause_requested.connect(pause_menu.toggle)
	pause_menu.quality_changed.connect(world.set_low_quality)
	loading.queue_free()
	await intro.play(player, cinematic_camera, spawn)
	player.controls_enabled = true
	hud.visible = true
	touch.visible = true
	pause_menu.enabled_in_game = true
	QuestManager.start_quest("lost_axe")

func _on_region_changed(_region_id: String, region_name: String) -> void:
	hud.show_region_banner(region_name)
