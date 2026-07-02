## ClassManager — Loads and serves character class data from res://data/character_classes.json
## Autoload singleton for accessing classes during character creation.

extends Node

signal classes_loaded()


const CLASSES_DATA_PATH := "res://data/character_classes.json"
const ClassProg = preload("res://scripts/ClassProgression.gd")

var _all_classes: Dictionary = {}  # key → class_data dictionary


func _ready() -> void:
	_load_classes()


## Load the canonical classes from res://data/character_classes.json
func load_classes_from_json() -> bool:
	return _load_classes()


func _load_classes() -> bool:
	var file := FileAccess.open(CLASSES_DATA_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		push_error("[ClassManager] Failed to open %s" % CLASSES_DATA_PATH)
		return false

	var text := file.get_as_text()
	file.close()

	var json_result: Variant = JSON.parse_string(text)
	if json_result is Array:
		# character_classes.json is an array of class objects — build lookup dict
		_all_classes = {}
		for entry: Variant in json_result:
			if entry is Dictionary and (entry as Dictionary).has("name"):
				var e: Dictionary = entry as Dictionary
				_all_classes[e["name"]] = e.duplicate(true)
	elif json_result is Dictionary:
		_all_classes = json_result.duplicate(true)
	else:
		push_error("[ClassManager] character_classes.json did not produce a dictionary or array.")
		return false
	print("[ClassManager] Loaded %d class(es)." % _all_classes.size())
	classes_loaded.emit()
	return true


## Get all classes as a dictionary: key → data dict
func get_all_classes() -> Dictionary:
	return _all_classes.duplicate(true)


## Look up a class by its id (e.g. "Scavenger", "Technician")
func get_class_by_id(class_id: String) -> Dictionary:
	if not _all_classes.has(class_id):
		push_warning("[ClassManager] Unknown class: %s" % class_id)
		return {}
	return _all_classes[class_id].duplicate(true)


## Check whether a given class exists
func has_class(class_id: String) -> bool:
	return _all_classes.has(class_id)


func get_max_level() -> int:
	return ClassProg.MAX_LEVEL


func get_progression(class_id: String) -> Dictionary:
	var cls: Dictionary = get_class_by_id(class_id)
	if cls.is_empty():
		return {"max_level": ClassProg.MAX_LEVEL, "growth": {}}
	return ClassProg.progression_from_class(cls)


## FFT combat profile scaled to class level (default Lv.1).
func get_combat_profile(class_id: String, level: int = 1) -> Dictionary:
	var cls: Dictionary = get_class_by_id(class_id)
	if cls.is_empty():
		return _default_combat_profile()
	return ClassProg.build_combat_profile(cls, level)


func get_abilities(class_id: String, level: int = 1) -> Array[Dictionary]:
	var profile: Dictionary = get_combat_profile(class_id, level)
	var abilities: Variant = profile.get("abilities", [])
	if abilities is Array:
		var out: Array[Dictionary] = []
		for a in abilities:
			if a is Dictionary:
				out.append((a as Dictionary).duplicate(true))
		return out
	return []


func get_stats_at_level(class_id: String, level: int, base_stats: Dictionary) -> Dictionary:
	var cls: Dictionary = get_class_by_id(class_id)
	if cls.is_empty():
		return base_stats.duplicate(true)
	return ClassProg.build_stats_at_level(cls, level, base_stats)


func get_max_hp_at_level(class_id: String, level: int, con: int) -> int:
	var cls: Dictionary = get_class_by_id(class_id)
	if cls.is_empty():
		return 80 + con * 5
	return ClassProg.compute_max_hp(con, level, cls)


func xp_to_next_level(level: int) -> int:
	return ClassProg.xp_required_for_next_level(level)


func _default_combat_profile() -> Dictionary:
	return {
		"role": "adaptive",
		"move_bonus": 0,
		"jump_bonus": 0,
		"speed_bonus": 0,
		"mp_max": 24,
		"weapon_range": 1,
		"attack_bonus": 0,
		"armor_bonus": 0,
		"reaction": "none",
		"abilities": [],
	}
