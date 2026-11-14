extends Node
## Persistent day/night clock and dynamic sun/sky controller.
## This autoload survives scene changes, so lighting time is not reset when a
## gameplay scene is reloaded or replaced.

const FULL_DAY_SECONDS: float = 1200.0 # One complete 24-hour cycle = 20 real minutes.
const START_HOUR: float = 8.0
const MAX_SUN_ENERGY: float = 1.25
const SKY_UPDATE_INTERVAL: float = 0.5

var time_of_day_hours: float = START_HOUR

var _sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sky_update_timer: float = 0.0
var atmosphere_fog_tint: Color = Color.WHITE
var quality_ambient_scale: float = 1.0 # set by the graphics preset (GraphicsManager via WorldManager)


func _process(delta: float) -> void:
	time_of_day_hours = fposmod(
		time_of_day_hours + (delta * 24.0 / FULL_DAY_SECONDS),
		24.0
	)

	if not is_instance_valid(_sun) or not is_instance_valid(_environment):
		return

	_update_sun()

	# Sky radiance/material updates are deliberately less frequent than the
	# sun transform updates to keep the mobile rendering cost controlled.
	_sky_update_timer += delta
	if _sky_update_timer >= SKY_UPDATE_INTERVAL:
		_sky_update_timer = 0.0
		_update_sky_and_ambient()


func register_lighting(sun_light: DirectionalLight3D, environment: Environment) -> void:
	_sun = sun_light
	_environment = environment
	_sky_material = null

	if _environment.sky != null:
		if _environment.sky.sky_material is ProceduralSkyMaterial:
			_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial

	_sky_update_timer = 0.0
	_update_sun()
	_update_sky_and_ambient()


func set_atmosphere_fog_tint(tint: Color) -> void:
	atmosphere_fog_tint = tint
	_update_sky_and_ambient()


func get_time_string() -> String:
	var total_minutes: int = int(floor(time_of_day_hours * 60.0)) % 1440
	var hour: int = int(total_minutes / 60)
	var minute: int = total_minutes % 60
	return "%02d:%02d" % [hour, minute]


func _update_sun() -> void:
	if not is_instance_valid(_sun):
		return

	var hour: float = time_of_day_hours
	var daylight_progress: float = clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var daylight: float = 0.0

	if hour >= 6.0 and hour <= 18.0:
		daylight = sin(daylight_progress * PI)

	# Fade the sun in and out around sunrise and sunset rather than switching
	# its intensity abruptly at the horizon.
	var sunrise_fade: float = _smooth01((hour - 5.5) / 1.5)
	var sunset_fade: float = 1.0 - _smooth01((hour - 17.0) / 1.5)
	var horizon_fade: float = minf(sunrise_fade, sunset_fade)
	var sun_strength: float = horizon_fade * (0.22 + 0.78 * sqrt(maxf(daylight, 0.0)))

	var elevation_degrees: float = 0.0
	var azimuth_degrees: float = -105.0

	if hour >= 6.0 and hour <= 18.0:
		elevation_degrees = sin(daylight_progress * PI) * 68.0
		azimuth_degrees = lerpf(-105.0, 105.0, daylight_progress)
	else:
		# Keep the sun below the horizon at night.
		elevation_degrees = -8.0
		azimuth_degrees = 105.0 if hour > 18.0 else -105.0

	_sun.rotation_degrees = Vector3(-elevation_degrees, azimuth_degrees, 0.0)
	_sun.light_energy = MAX_SUN_ENERGY * sun_strength
	_sun.light_color = _sample_color(
		hour,
		Color(0.35, 0.43, 0.66),
		Color(1.0, 0.72, 0.48),
		Color(1.0, 0.97, 0.88),
		Color(1.0, 0.52, 0.30)
	)


func _update_sky_and_ambient() -> void:
	if not is_instance_valid(_environment):
		return

	var hour: float = time_of_day_hours

	if _sky_material != null:
		_sky_material.sky_top_color = _sample_color(
			hour,
			Color(0.025, 0.045, 0.11),
			Color(0.30, 0.48, 0.76),
			Color(0.16, 0.38, 0.76),
			Color(0.10, 0.17, 0.34)
		)
		_sky_material.sky_horizon_color = _sample_color(
			hour,
			Color(0.045, 0.065, 0.12),
			Color(0.92, 0.63, 0.43),
			Color(0.72, 0.84, 0.93),
			Color(0.94, 0.39, 0.22)
		)
		_sky_material.ground_horizon_color = _sample_color(
			hour,
			Color(0.035, 0.05, 0.085),
			Color(0.70, 0.64, 0.59),
			Color(0.72, 0.82, 0.88),
			Color(0.62, 0.35, 0.27)
		)
		_sky_material.ground_bottom_color = _sample_color(
			hour,
			Color(0.015, 0.025, 0.055),
			Color(0.25, 0.32, 0.38),
			Color(0.28, 0.40, 0.46),
			Color(0.20, 0.16, 0.20)
		)

	_environment.ambient_light_energy = _sample_float(
		hour, 0.30, 0.82, 1.0, 0.72
	) * quality_ambient_scale
	var time_fog_color: Color = _sample_color(
		hour,
		Color(0.12, 0.16, 0.25),
		Color(0.76, 0.72, 0.70),
		Color(0.72, 0.84, 0.92),
		Color(0.76, 0.48, 0.38)
	)
	_environment.fog_light_color = time_fog_color * atmosphere_fog_tint


func _sample_color(
	hour: float,
	night_color: Color,
	morning_color: Color,
	midday_color: Color,
	evening_color: Color
) -> Color:
	if hour < 6.0:
		return night_color.lerp(morning_color, hour / 6.0)
	if hour < 12.0:
		return morning_color.lerp(midday_color, (hour - 6.0) / 6.0)
	if hour < 18.0:
		return midday_color.lerp(evening_color, (hour - 12.0) / 6.0)
	return evening_color.lerp(night_color, (hour - 18.0) / 6.0)


func _sample_float(
	hour: float,
	night_value: float,
	morning_value: float,
	midday_value: float,
	evening_value: float
) -> float:
	if hour < 6.0:
		return lerpf(night_value, morning_value, hour / 6.0)
	if hour < 12.0:
		return lerpf(morning_value, midday_value, (hour - 6.0) / 6.0)
	if hour < 18.0:
		return lerpf(midday_value, evening_value, (hour - 12.0) / 6.0)
	return lerpf(evening_value, night_value, (hour - 18.0) / 6.0)


func _smooth01(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
