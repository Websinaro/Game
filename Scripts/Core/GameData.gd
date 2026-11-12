class_name GameData
extends RefCounted
## Small JSON helper used by data-driven systems (quests, story, world layout).

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("GameData: missing data file " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameData: cannot open " + path)
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("GameData: invalid JSON in " + path)
	return {}
