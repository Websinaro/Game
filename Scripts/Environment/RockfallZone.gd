class_name RockfallZone
extends Node3D
## Falling-rock hazard on the hidden path. While the player is inside the zone, rocks fall every
## few seconds: a red disc marks the spot, then the rock lands. A hit shoves the player, stuns
## briefly and drains stamina (no damage, no death). All numbers are in Tuning.gd (ROCKFALL_*).

var _player: PlayerController = null
var _timer: float = 2.0
var _warned: bool = false
var _enabled: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_enabled = GameSettings.pick_b(Tuning.ROCKFALL_ON_NORMAL, Tuning.ROCKFALL_ON_HARD)
	set_process(_enabled)

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if _player == null:
			return
	var dx: float = _player.global_position.x - global_position.x
	var dz: float = _player.global_position.z - global_position.z
	var dist: float = sqrt(dx * dx + dz * dz)
	if dist > Tuning.ROCKFALL_ZONE_RADIUS + 6.0:
		return
	if dist <= Tuning.ROCKFALL_ZONE_RADIUS and not _warned:
		_warned = true
		GameInput.notice.emit("Loose rock overhead. Watch the red marks on the ground!")
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = GameSettings.pick_f(Tuning.ROCKFALL_INTERVAL_NORMAL, Tuning.ROCKFALL_INTERVAL_HARD) * _rng.randf_range(0.7, 1.3)
	if dist <= Tuning.ROCKFALL_ZONE_RADIUS:
		_drop(_pick_target(dist))

func _pick_target(dist: float) -> Vector3:
	var x: float
	var z: float
	if dist <= Tuning.ROCKFALL_ZONE_RADIUS and _rng.randf() < Tuning.ROCKFALL_AIM_AT_PLAYER_CHANCE:
		var lead: float = GameSettings.pick_f(Tuning.ROCKFALL_WARNING_NORMAL, Tuning.ROCKFALL_WARNING_HARD)
		x = _player.global_position.x + _player.velocity.x * lead * 0.6
		z = _player.global_position.z + _player.velocity.z * lead * 0.6
	else:
		var a: float = _rng.randf() * TAU
		var r: float = sqrt(_rng.randf()) * Tuning.ROCKFALL_ZONE_RADIUS
		x = global_position.x + cos(a) * r
		z = global_position.z + sin(a) * r
	return Vector3(x, TerrainGenerator.height_at(x, z), z)

func _drop(target: Vector3) -> void:
	var warn: float = GameSettings.pick_f(Tuning.ROCKFALL_WARNING_NORMAL, Tuning.ROCKFALL_WARNING_HARD)
	var radius: float = GameSettings.pick_f(Tuning.ROCKFALL_HIT_RADIUS_NORMAL, Tuning.ROCKFALL_HIT_RADIUS_HARD)
	var disc_mat: StandardMaterial3D = StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.albedo_color = Color(0.85, 0.12, 0.05, 0.0)
	var disc_mesh: CylinderMesh = CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.03
	disc_mesh.radial_segments = 20
	disc_mesh.rings = 1
	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.mesh = disc_mesh
	disc.material_override = disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(disc)
	disc.global_position = target + Vector3(0.0, 0.08, 0.0)
	var rock: MeshInstance3D = MeshInstance3D.new()
	rock.mesh = Rock.get_variant_mesh(_rng.randi_range(0, 3), false)
	var s: float = _rng.randf_range(0.9, 1.4)
	rock.scale = Vector3(s, s, s)
	get_parent().add_child(rock)
	rock.global_position = target + Vector3(0.0, 14.0, 0.0)
	var fade: Tween = create_tween()
	fade.tween_property(disc_mat, "albedo_color:a", 0.6, warn)
	var fall: Tween = create_tween()
	fall.tween_property(rock, "global_position:y", target.y + 0.2, warn).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(_impact.bind(target, radius, rock, disc))

func _impact(target: Vector3, radius: float, rock: MeshInstance3D, disc: MeshInstance3D) -> void:
	if _player != null:
		var d: Vector3 = _player.global_position - target
		var flat: float = sqrt(d.x * d.x + d.z * d.z)
		if flat < radius and _player.global_position.y < target.y + 1.6:
			_player.apply_hit(d, GameSettings.pick_f(Tuning.ROCKFALL_KNOCKBACK_NORMAL, Tuning.ROCKFALL_KNOCKBACK_HARD), GameSettings.pick_f(Tuning.ROCKFALL_STAMINA_PENALTY_NORMAL, Tuning.ROCKFALL_STAMINA_PENALTY_HARD), GameSettings.pick_f(Tuning.ROCKFALL_STUN_NORMAL, Tuning.ROCKFALL_STUN_HARD))
			GameInput.notice.emit("A rock slams down beside you!")
	disc.queue_free()
	var vanish: Tween = create_tween()
	vanish.tween_interval(1.0)
	vanish.tween_property(rock, "scale", Vector3(0.01, 0.01, 0.01), 0.8)
	vanish.tween_callback(rock.queue_free)
