extends Node
## Autoload "GraphicsManager": adaptive graphics for the Mobile renderer.
## 1. Startup assessment: a short benchmark of the REAL world (orbiting camera, HIGH preset,
##    hidden behind the loading screen) -> capability score -> LOW / MEDIUM / HIGH.
## 2. Runtime monitor (AUTO mode only): rolling per-second frame-time summaries with hysteresis.
## 3. Preset table below = the single place to tune quality. WorldManager applies the values to
##    the sun / environment / viewport (in small steps, never in one big hitch).
## Mode: AUTO (-1) or a fixed preset (LOW / MEDIUM / HIGH). Saved through GameSettings.

signal preset_applied(preset: int, immediate: bool)   # WorldManager listens
signal preset_auto_changed(preset: int, reason: String) # HUD message (AUTO changes only)
signal mode_changed(mode: int)

const LOW: int = 0
const MEDIUM: int = 1
const HIGH: int = 2
const MODE_AUTO: int = -1
const PRESET_NAMES: Array = ["LOW", "MEDIUM", "HIGH"]

## All visual numbers per preset. Untested on device: tune freely.
const PRESETS: Dictionary = {
	LOW: {
		"target_fps": 30.0,
		"shadows": true, "shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"shadow_distance": 25.0, "shadow_atlas": 1024, "shadow_blur": 0.6,
		"msaa": Viewport.MSAA_DISABLED, "scale3d": 0.7, "mesh_lod": 3.0, "mip_bias": 1.0,
		"adjust": false, "low_shaders": true,
		"veg_range": 0.7, "grass_range": 0.55,
		"fog_density": 1.12, "fog_detail": 0.6, "ambient": 1.05,
		"sky_radiance": Sky.RADIANCE_SIZE_32,
	},
	MEDIUM: {
		"target_fps": 45.0,
		"shadows": true, "shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"shadow_distance": 60.0, "shadow_atlas": 2048, "shadow_blur": 1.2,
		"msaa": Viewport.MSAA_DISABLED, "scale3d": 0.85, "mesh_lod": 2.0, "mip_bias": 0.5,
		"adjust": true, "low_shaders": false,
		"veg_range": 0.88, "grass_range": 0.8,
		"fog_density": 1.05, "fog_detail": 0.85, "ambient": 1.0,
		"sky_radiance": Sky.RADIANCE_SIZE_64,
	},
	HIGH: {
		"target_fps": 60.0,
		"shadows": true, "shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"shadow_distance": 120.0, "shadow_atlas": 4096, "shadow_blur": 1.3,
		"msaa": Viewport.MSAA_2X, "scale3d": 1.0, "mesh_lod": 1.0, "mip_bias": 0.0,
		"adjust": true, "low_shaders": false,
		"veg_range": 1.0, "grass_range": 1.0,
		"fog_density": 1.0, "fog_detail": 1.0, "ambient": 1.08,
		"sky_radiance": Sky.RADIANCE_SIZE_128,
	},
}

# ---- benchmark tuning ----
const BENCH_WARMUP_MS: int = 900        # shader compile / first-frame hitches are discarded
const BENCH_SAMPLE_MS: int = 1600
const BENCH_TIMEOUT_MS: int = 6500
const BENCH_MIN_SAMPLES: int = 20
const BENCH_ABORT_AVG_MS: float = 50.0  # clearly hopeless at HIGH: stop early
const REF_FRAME_MS: float = 16.67       # score 100 = HIGH preset holds 60 FPS
const SCORE_HIGH: float = 90.0          # load <= ~18.5 ms at HIGH
const SCORE_MEDIUM: float = 55.0        # load <= ~30 ms at HIGH (MEDIUM is cheaper)
# ---- monitor tuning ----
const HITCH_IGNORE_MS: float = 250.0    # stalls (loads, app resume) are not evidence
const DOWN_WINDOW_S: int = 8
const DOWN_BAD_SECONDS: int = 6         # 75% of the window must be bad
const SEVERE_WINDOW_S: int = 3
const SEVERE_FPS_RATIO: float = 0.6
const BAD_TIME_RATIO: float = 1.12      # a second is bad if avg frame > target * this
const BAD_P95_RATIO: float = 1.8
const UP_WINDOW_S: int = 25
const UP_HEADROOM: float = 1.2
const UP_START_BLOCK_S: float = 90.0
const UP_COOLDOWN_BASE_S: float = 120.0
const UP_COOLDOWN_MAX_S: float = 1800.0
const FLAP_WINDOW_S: float = 240.0

var mode: int = MODE_AUTO
var current_preset: int = MEDIUM
var avg_fps: float = 0.0
var last_score: float = -1.0
var device_info: Dictionary = {}
var assessment_text: String = ""

var _auto_preset: int = MEDIUM
var _assessed: bool = false
var _monitoring: bool = false
var _last_usec: int = 0
var _grace_until_ms: int = 0
var _buf: PackedFloat32Array = PackedFloat32Array()
var _buf_ms: float = 0.0
var _summaries: Array = []              # per-second {"fps": float, "p95": float}
var _up_block_until_s: float = UP_START_BLOCK_S
var _up_cooldown_s: float = UP_COOLDOWN_BASE_S
var _last_up_s: float = -1000.0


func _ready() -> void:
	mode = clampi(GameSettings.graphics_mode, MODE_AUTO, HIGH)
	_auto_preset = GameSettings.graphics_auto_preset if GameSettings.graphics_auto_preset >= LOW else MEDIUM
	_auto_preset = clampi(_auto_preset, LOW, HIGH)
	last_score = GameSettings.graphics_score
	current_preset = _auto_preset if mode == MODE_AUTO else mode
	_last_usec = Time.get_ticks_usec()
	_collect_device_info()
	_refresh_assessment_text(false)


# ---- public API ------------------------------------------------------------------------------
func params() -> Dictionary:
	return PRESETS[current_preset] as Dictionary

func preset_name(preset: int = -1) -> String:
	return str(PRESET_NAMES[current_preset if preset < 0 else clampi(preset, LOW, HIGH)])

func mode_name() -> String:
	return "AUTO" if mode == MODE_AUTO else preset_name(mode)

func get_selected_message() -> String:
	return "Graphics: %s (%s)" % [preset_name(), "automatic" if mode == MODE_AUTO else "manual"]

func get_status_text() -> String:
	return "Mode: %s   Preset: %s\nAverage FPS: %s\n%s" % [
		"Automatic" if mode == MODE_AUTO else "Manual", preset_name(),
		("%d" % int(round(avg_fps))) if avg_fps > 0.0 else "-", assessment_text]

## Change mode from Settings. Manual = fixed preset, no monitoring-driven changes.
func set_mode(new_mode: int) -> void:
	new_mode = clampi(new_mode, MODE_AUTO, HIGH)
	if new_mode == mode:
		return
	mode = new_mode
	_summaries.clear()
	_grace_until_ms = Time.get_ticks_msec() + 2500
	_up_block_until_s = _now_s() + UP_START_BLOCK_S
	var target: int = _auto_preset if mode == MODE_AUTO else mode
	if target != current_preset:
		_apply(target, false)
	_persist()
	mode_changed.emit(mode)

## Cycles AUTO -> HIGH -> MEDIUM -> LOW -> AUTO (one settings button).
func cycle_mode() -> void:
	set_mode(HIGH if mode == MODE_AUTO else (mode - 1 if mode > LOW else MODE_AUTO))

func begin_monitoring() -> void:
	_buf.clear()
	_buf_ms = 0.0
	_summaries.clear()
	_grace_until_ms = Time.get_ticks_msec() + 2000
	_monitoring = true

func end_monitoring() -> void:
	_monitoring = false

## Call on region change / scene change: judge the new environment with fresh data.
func notify_context_change(grace_ms: int = 1500) -> void:
	_buf.clear()
	_buf_ms = 0.0
	_summaries.clear()
	_grace_until_ms = Time.get_ticks_msec() + grace_ms

## Runs once per app session (AUTO only). Awaited by Main behind the loading screen.
## Never throws: on any problem the previous / MEDIUM preset stays and the game starts normally.
func run_startup_assessment(cam: Camera3D, centre: Vector3) -> void:
	_collect_device_info()
	if mode != MODE_AUTO or _assessed:
		_refresh_assessment_text(false)
		return
	_assessed = true
	var result: Dictionary = await _run_benchmark(cam, centre)
	var chosen: int
	if result.is_empty():
		chosen = _auto_preset # saved result of an earlier session, else MEDIUM
		assessment_text = "Assessment: unavailable (safe default)"
		push_warning("GraphicsManager: benchmark failed, using " + preset_name(chosen))
	else:
		last_score = float(result["score"])
		chosen = _preset_from_score(last_score)
		_refresh_assessment_text(true, result)
	_auto_preset = chosen
	_up_block_until_s = _now_s() + UP_START_BLOCK_S
	_apply(chosen, true)
	_persist()


# ---- internals -------------------------------------------------------------------------------
func _now_s() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _refresh_hz() -> float:
	var hz: float = DisplayServer.screen_get_refresh_rate()
	return 60.0 if hz < 30.0 else hz # -1 = unknown

func _collect_device_info() -> void:
	var size: Vector2i = DisplayServer.window_get_size()
	device_info = {
		"os": OS.get_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"resolution": "%dx%d" % [size.x, size.y],
		"refresh_hz": _refresh_hz(),
		"cpu_cores": OS.get_processor_count(),
	}

func _refresh_assessment_text(fresh: bool, result: Dictionary = {}) -> void:
	if last_score < 0.0:
		assessment_text = "Assessment: not measured yet"
	elif fresh and not result.is_empty():
		assessment_text = "Assessment: score %d -> %s (%.1f ms/frame at High)" % [int(round(last_score)), preset_name(_preset_from_score(last_score)), float(result["load_ms"])]
	else:
		assessment_text = "Assessment: score %d -> %s (previous session)" % [int(round(last_score)), preset_name(_preset_from_score(last_score))]

func _preset_from_score(score: float) -> int:
	if score >= SCORE_HIGH:
		return HIGH
	if score >= SCORE_MEDIUM:
		return MEDIUM
	return LOW

func _apply(preset: int, immediate: bool) -> void:
	current_preset = clampi(preset, LOW, HIGH)
	preset_applied.emit(current_preset, immediate)

func _persist() -> void:
	GameSettings.set_graphics(mode, _auto_preset, last_score)

static func _p95(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	return sorted[mini(int(float(sorted.size()) * 0.95), sorted.size() - 1)]

## Renders the real world at the HIGH preset while orbiting the camera, so the score reflects
## actual GPU/CPU cost of this game on this device. Score = 100 * 16.67 ms / load_ms (max 100),
## load_ms = max(0.7*avg + 0.3*p95 frame time, 1.15 * GPU render time if the driver reports it).
func _run_benchmark(cam: Camera3D, centre: Vector3) -> Dictionary:
	var vp: Viewport = get_viewport()
	var rid: RID = vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	_apply(HIGH, true)
	var saved_xform: Transform3D = Transform3D.IDENTITY
	var cam_ok: bool = is_instance_valid(cam)
	if cam_ok:
		saved_xform = cam.global_transform
	var samples: PackedFloat32Array = PackedFloat32Array()
	var gpu_sum: float = 0.0
	var gpu_n: int = 0
	var angle: float = 0.0
	var start_ms: int = Time.get_ticks_msec()
	var last_us: int = Time.get_ticks_usec()
	var sum_ms: float = 0.0
	while true:
		await get_tree().process_frame
		var now_us: int = Time.get_ticks_usec()
		var dt_ms: float = float(now_us - last_us) / 1000.0
		last_us = now_us
		var elapsed: int = Time.get_ticks_msec() - start_ms
		if cam_ok and is_instance_valid(cam):
			angle += 0.6 * minf(dt_ms, 100.0) / 1000.0
			cam.global_position = centre + Vector3(sin(angle) * 10.0, 3.5, cos(angle) * 10.0)
			cam.look_at(centre + Vector3(0.0, 1.5, 0.0), Vector3.UP)
		if elapsed >= BENCH_TIMEOUT_MS:
			break
		if elapsed < BENCH_WARMUP_MS:
			continue
		samples.append(minf(dt_ms, 100.0))
		sum_ms += minf(dt_ms, 100.0)
		var g: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
		if g > 0.0:
			gpu_sum += g
			gpu_n += 1
		if samples.size() >= 12 and sum_ms / float(samples.size()) > BENCH_ABORT_AVG_MS:
			break
		if elapsed >= BENCH_WARMUP_MS + BENCH_SAMPLE_MS:
			break
	RenderingServer.viewport_set_measure_render_time(rid, false)
	if cam_ok and is_instance_valid(cam):
		cam.global_transform = saved_xform
	if samples.size() < BENCH_MIN_SAMPLES and not (samples.size() >= 12 and sum_ms / float(samples.size()) > BENCH_ABORT_AVG_MS):
		return {}
	var avg_ms: float = sum_ms / float(samples.size())
	var frame_ms: float = 0.7 * avg_ms + 0.3 * _p95(samples)
	var gpu_ms: float = gpu_sum / float(gpu_n) if gpu_n > 0 else 0.0
	var load_ms: float = maxf(frame_ms, gpu_ms * 1.15)
	if load_ms <= 0.0:
		return {}
	return {
		"score": clampf(100.0 * REF_FRAME_MS / load_ms, 0.0, 100.0),
		"load_ms": load_ms, "avg_ms": avg_ms, "gpu_ms": gpu_ms, "samples": samples.size(),
	}


# ---- runtime monitor -------------------------------------------------------------------------
func _process(_delta: float) -> void:
	var now_us: int = Time.get_ticks_usec()
	var dt_ms: float = float(now_us - _last_usec) / 1000.0
	_last_usec = now_us
	if not _monitoring:
		return
	if dt_ms > HITCH_IGNORE_MS or Time.get_ticks_msec() < _grace_until_ms:
		return
	_buf.append(dt_ms)
	_buf_ms += dt_ms
	if _buf_ms >= 1000.0:
		_close_second()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		notify_context_change(3000)

func _close_second() -> void:
	var fps: float = 1000.0 * float(_buf.size()) / _buf_ms
	_summaries.append({"fps": fps, "p95": _p95(_buf)})
	if _summaries.size() > 60:
		_summaries.pop_front()
	_buf.clear()
	_buf_ms = 0.0
	avg_fps = fps if avg_fps <= 0.0 else lerpf(avg_fps, fps, 0.35)
	if mode == MODE_AUTO:
		_evaluate()

func _is_bad(s: Dictionary, target_fps: float) -> bool:
	var target_ms: float = 1000.0 / target_fps
	return (1000.0 / float(s["fps"])) > target_ms * BAD_TIME_RATIO or float(s["p95"]) > target_ms * BAD_P95_RATIO

func _evaluate() -> void:
	var n: int = _summaries.size()
	var target: float = float((PRESETS[current_preset] as Dictionary)["target_fps"])
	# Quality down: sustained trouble only. One slow frame / one bad second never counts.
	if current_preset > LOW:
		if n >= SEVERE_WINDOW_S:
			var severe: int = 0
			for i: int in range(n - SEVERE_WINDOW_S, n):
				if float((_summaries[i] as Dictionary)["fps"]) < target * SEVERE_FPS_RATIO:
					severe += 1
			if severe == SEVERE_WINDOW_S:
				_change_preset(current_preset - 1, "sustained very low FPS")
				return
		if n >= DOWN_WINDOW_S:
			var bad: int = 0
			for i: int in range(n - DOWN_WINDOW_S, n):
				if _is_bad(_summaries[i] as Dictionary, target):
					bad += 1
			if bad >= DOWN_BAD_SECONDS:
				_change_preset(current_preset - 1, "sustained low FPS")
				return
	# Quality up: long, clear headroom for the NEXT preset, and not blocked by cooldown.
	if current_preset < HIGH and n >= UP_WINDOW_S and _now_s() >= _up_block_until_s:
		var next_target: float = float((PRESETS[current_preset + 1] as Dictionary)["target_fps"])
		var need_fps: float = minf(next_target * UP_HEADROOM, _refresh_hz() * 0.97)
		var good: int = 0
		for i: int in range(n - UP_WINDOW_S, n):
			var s: Dictionary = _summaries[i] as Dictionary
			if float(s["fps"]) >= need_fps and float(s["p95"]) <= (1000.0 / need_fps) * 1.5:
				good += 1
		if good >= int(float(UP_WINDOW_S) * 0.9):
			_change_preset(current_preset + 1, "stable performance")

func _change_preset(new_preset: int, reason: String) -> void:
	var now: float = _now_s()
	if new_preset > current_preset:
		_last_up_s = now
	else:
		# Dropped soon after an upgrade = the upgrade was too ambitious: wait longer next time.
		if now - _last_up_s < FLAP_WINDOW_S:
			_up_cooldown_s = minf(_up_cooldown_s * 2.0, UP_COOLDOWN_MAX_S)
		_up_block_until_s = maxf(_up_block_until_s, now + _up_cooldown_s)
	_auto_preset = new_preset
	_summaries.clear()
	_grace_until_ms = Time.get_ticks_msec() + 2500 # let the gradual change finish
	_apply(new_preset, false)
	_persist()
	preset_auto_changed.emit(new_preset, reason)
