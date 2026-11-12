extends Node
## Autoload "QuestManager". Data driven from res://Data/quests.json.
## Objectives are sequential; only the active objective can be completed.

signal quest_started(quest_id: String)
signal objective_changed(text: String)
signal objective_completed(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)
signal objective_notice(text: String)

var _quests: Dictionary = {}
var _active_quest: String = ""
var _index: int = 0
var _progress: int = 0
var _finished: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = GameData.load_json("res://Data/quests.json")
	var list: Array = data.get("quests", []) as Array
	for entry: Variant in list:
		if entry is Dictionary:
			var q: Dictionary = entry as Dictionary
			_quests[str(q.get("id", ""))] = q

func reset() -> void:
	_active_quest = ""
	_index = 0
	_progress = 0
	_finished.clear()

func start_quest(quest_id: String) -> void:
	if not _quests.has(quest_id):
		push_error("QuestManager: unknown quest " + quest_id)
		return
	_active_quest = quest_id
	_index = 0
	_progress = 0
	quest_started.emit(quest_id)
	objective_changed.emit(get_objective_text())
	var q: Dictionary = _quests[quest_id] as Dictionary
	var start_note: String = str(q.get("start_notify", ""))
	if start_note != "":
		objective_notice.emit(start_note)

func _objectives() -> Array:
	if _active_quest == "":
		return []
	var q: Dictionary = _quests[_active_quest] as Dictionary
	return q.get("objectives", []) as Array

func _current() -> Dictionary:
	var objs: Array = _objectives()
	if _index < 0 or _index >= objs.size():
		return {}
	return objs[_index] as Dictionary

func get_active_objective_id() -> String:
	return str(_current().get("id", ""))

func is_objective_active(objective_id: String) -> bool:
	return get_active_objective_id() == objective_id

func is_quest_finished(quest_id: String) -> bool:
	return _finished.has(quest_id)

func get_objective_text() -> String:
	var obj: Dictionary = _current()
	if obj.is_empty():
		return ""
	var text: String = str(obj.get("text", ""))
	var required: int = int(obj.get("required", 1))
	if required > 1:
		text += " (%d/%d)" % [_progress, required]
	return text

func get_progress() -> int:
	return _progress

## Completes the active objective if it matches objective_id.
func complete_objective(objective_id: String) -> bool:
	if not is_objective_active(objective_id):
		return false
	var finished_quest: String = _active_quest
	objective_completed.emit(finished_quest, objective_id)
	_index += 1
	_progress = 0
	var next_obj: Dictionary = _current()
	if next_obj.is_empty():
		_finished[finished_quest] = true
		_active_quest = ""
		objective_changed.emit("")
		quest_completed.emit(finished_quest)
		return true
	objective_changed.emit(get_objective_text())
	var note: String = str(next_obj.get("notify", ""))
	if note != "":
		objective_notice.emit(note)
	return true

## Adds one unit of progress to a counted objective (e.g. 2/3 fragments).
func progress_objective(objective_id: String) -> void:
	if not is_objective_active(objective_id):
		return
	var required: int = int(_current().get("required", 1))
	_progress += 1
	if _progress >= required:
		complete_objective(objective_id)
	else:
		objective_changed.emit(get_objective_text())
		objective_notice.emit("Progress: %d/%d" % [_progress, required])
