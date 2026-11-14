extends Node
## Autoload "GameSettings": difficulty (Normal / Hard) and the saved graphics choice (see GraphicsManager).
## Persisted in user://settings.cfg. Numbers that depend on difficulty live in Tuning.gd.

signal settings_changed()

const SETTINGS_PATH: String = "user://settings.cfg"
const DIFFICULTY_NORMAL: int = 0
const DIFFICULTY_HARD: int = 1

var difficulty: int = DIFFICULTY_NORMAL
var graphics_mode: int = -1         # -1 = AUTO, 0 LOW, 1 MEDIUM, 2 HIGH (GraphicsManager owns the meaning)
var graphics_auto_preset: int = -1  # last preset chosen by AUTO (benchmark / runtime adaptation)
var graphics_score: float = -1.0    # last benchmark score, -1 = never measured

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()

func is_hard() -> bool:
	return difficulty == DIFFICULTY_HARD

func difficulty_name() -> String:
	return "Hard" if is_hard() else "Normal"

func pick_f(normal_value: float, hard_value: float) -> float:
	return hard_value if is_hard() else normal_value

func pick_i(normal_value: int, hard_value: int) -> int:
	return hard_value if is_hard() else normal_value

func pick_b(normal_value: bool, hard_value: bool) -> bool:
	return hard_value if is_hard() else normal_value

func set_difficulty(value: int) -> void:
	if value == difficulty:
		return
	difficulty = value
	_save_settings()
	settings_changed.emit()

func set_graphics(mode: int, auto_preset: int, score: float) -> void:
	graphics_mode = mode
	graphics_auto_preset = auto_preset
	graphics_score = score
	_save_settings()

func _load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	difficulty = clampi(int(cfg.get_value("game", "difficulty", DIFFICULTY_NORMAL)), DIFFICULTY_NORMAL, DIFFICULTY_HARD)
	if cfg.has_section_key("graphics", "mode"):
		graphics_mode = clampi(int(cfg.get_value("graphics", "mode", -1)), -1, 2)
	elif bool(cfg.get_value("graphics", "low", false)):
		graphics_mode = 0 # migrate the old "Low" toggle
	graphics_auto_preset = clampi(int(cfg.get_value("graphics", "auto_preset", -1)), -1, 2)
	graphics_score = float(cfg.get_value("graphics", "score", -1.0))

func _save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("graphics", "mode", graphics_mode)
	cfg.set_value("graphics", "auto_preset", graphics_auto_preset)
	cfg.set_value("graphics", "score", graphics_score)
	var err: Error = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("GameSettings: could not save settings (error %d)" % int(err))
