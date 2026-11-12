extends Node
## Autoload "StoryManager". Narrative text (res://Data/story.json), lore panels,
## story flags and the phase-complete event.

signal lore_requested(title: String, body: String)
@warning_ignore("unused_signal")
signal lore_closed()
signal phase_complete(title: String, banner: String, subtitle: String)

var lore_open: bool = false
var flags: Dictionary = {}
var _story: Dictionary = {}

func _ready() -> void:
	_story = GameData.load_json("res://Data/story.json")
	QuestManager.quest_completed.connect(_on_quest_completed)

func get_intro() -> Dictionary:
	return _story.get("intro", {}) as Dictionary

func get_lore(lore_id: String) -> Dictionary:
	var lore: Dictionary = _story.get("lore", {}) as Dictionary
	return lore.get(lore_id, {}) as Dictionary

func show_lore(lore_id: String, extra_body: String = "") -> void:
	var entry: Dictionary = get_lore(lore_id)
	if entry.is_empty():
		return
	show_text(str(entry.get("title", "")), str(entry.get("body", "")) + extra_body)

func show_text(title: String, body: String) -> void:
	lore_open = true
	lore_requested.emit(title, body)

## Called by the HUD when the player dismisses the lore panel.
func notify_lore_closed() -> void:
	lore_open = false
	lore_closed.emit()

func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value

func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))

func _on_quest_completed(_quest_id: String) -> void:
	if lore_open:
		await lore_closed
	var data: Dictionary = _story.get("phase_complete", {}) as Dictionary
	phase_complete.emit(str(data.get("title", "")), str(data.get("banner", "")), str(data.get("subtitle", "")))

func get_tablet_lines() -> Array:
	return _story.get("tablet_lines", []) as Array
