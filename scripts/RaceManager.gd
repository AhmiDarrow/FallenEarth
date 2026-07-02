## RaceManager — Loads and serves race data from res://data/races.json
## Autoload singleton for accessing all races during character creation.

extends Node


signal races_loaded()


const RACES_DATA_PATH := "res://data/races.json"

var _all_races: Dictionary = {"upworld": [], "underworld": []}
var _race_lookup: Dictionary = {}  # key -> race data for fast lookups


func _ready() -> void:
	load_races_from_json()


## Load the canonical races table from JSON at res://data/races.json
func load_races_from_json() -> bool:
	var file := FileAccess.open(RACES_DATA_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		push_error("[RaceManager] Failed to open %s" % RACES_DATA_PATH)
		return false

	var text := file.get_as_text()
	file.close()

	var json_result: Variant = JSON.parse_string(text)
	if not (json_result is Dictionary):
		push_error("[RaceManager] races.json did not produce a dictionary at top level.")
		return false

	_all_races = {}
	_race_lookup = {}

	for origin_key in ["upworld", "underworld"]:
		var list: Array[Dictionary] = []
		if json_result.has(origin_key):
			var value = json_result[origin_key]
			if value is Dictionary:
				# races.json format: {"upworld": {"Human": {...}, ...}} — keys are race names
				for race_id in value:
					var entry: Dictionary = value[race_id].duplicate(true)
					if not entry.has("id"):
						entry["id"] = race_id
					entry["origin"] = origin_key
					list.append(entry)
					_race_lookup[race_id] = entry
			elif value is Array:
				# Fallback if format ever changes to array-of-objects
				for i in range(value.size()):
					var race: Dictionary = (value[i] if value[i] is Dictionary else {}) as Dictionary
					if not race.has("id") and race.has("race"):
						race["id"] = race["race"]
					if not race.has("origin"):
						race["origin"] = origin_key
					list.append(race)
			else:
				push_warning("[RaceManager] Unexpected type for %s in races.json" % origin_key)

			_all_races[origin_key] = list
		else:
			_all_races[origin_key] = []  # missing origin → empty (defensive)

	races_loaded.emit()
	return true


## Return all races grouped by origin ("upworld" / "underworld")
func get_all_races() -> Dictionary:
	return _all_races.duplicate(true)


## Get flattened list of race ids across both origins
func get_all_race_keys() -> Array[String]:
	var keys: Array[String] = []
	for origin_list in _all_races.values():
		if origin_list is Array:
			for r in origin_list:
				if r is Dictionary and r.has("id"):
					keys.append(r["id"] as String)
	return keys


## Look up a single race by its id string (e.g. "Human", "Mutant")
func get_race_by_id(race_id: String) -> Dictionary:
	if _race_lookup.is_empty():
		_build_lookup()
	return _race_lookup.get(race_id, {})


# -- internals --

func _build_lookup() -> void:
	for origin in _all_races:
		var list: Array = _all_races[origin] if _all_races[origin] is Array else []
		for r in list:
			if r is Dictionary and r.has("id"):
				_race_lookup[str(r["id"])] = r
