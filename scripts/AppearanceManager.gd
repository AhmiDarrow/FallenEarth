## AppearanceManager — Manages appearance data via res://data files
## Autoload singleton for character visual configuration.

extends Node

signal appearance_loaded(appearance_data: Dictionary)


const APPEARANCE_DATA_PATH := "res://data/appearance.json"
const PLAYER_TEMPLATES_PATH := "res://scripts/data/player_templates.json"  # note: singular filename on disk

var _appearance_data: Dictionary = {}


func _ready() -> void:
	_load_appearance_data()

func _load_appearance_data() -> void:
	load_appearance_from_json()


## Load appearance data from the canonical JSON
func load_appearance_from_json(path: String = "") -> bool:
	var json_path := path if path != "" else APPEARANCE_DATA_PATH
	var file := FileAccess.open(json_path, FileAccess.READ)
	if not is_instance_valid(file):
		push_error("[AppearanceManager] Failed to open %s" % json_path)
		return false

	var text := file.get_as_text()
	file.close()

	var result: Variant = JSON.parse_string(text)
	if not (result is Dictionary):
		push_error("[AppearanceManager] %s did not produce a dictionary." % json_path)
		return false

	_appearance_data = result.duplicate(true)
	appearance_loaded.emit(_appearance_data)
	print("[AppearanceManager] Appearance data loaded from %s." % json_path)
	return true


## Get the current appearance data (frozen copy)
func get_appearance_data() -> Dictionary:
	return _appearance_data.duplicate(true)


## Store a full appearance dict at runtime (e.g. after character creation)
func save_appearance(appearance_dict: Dictionary) -> bool:
	if not appearance_dict is Dictionary:
		push_error("[AppearanceManager] save_appearance() requires a Dictionary, got %s" % typeof(appearance_dict))
		return false

	_appearance_data = appearance_dict.duplicate(true)
	print("[AppearanceManager] Appearance data saved locally.")
	return true


## Convenience getters for specific appearance keys
func get_head_styles() -> Array:
	var heads = _appearance_data.get("head", [])
	return heads if heads is Array else []


func get_body_styles() -> Array:
	var bodies = _appearance_data.get("body", [])
	return bodies if bodies is Array else []


func get_skin_tones() -> Array:
	var tones = _appearance_data.get("skin_tone", [])
	return tones if tones is Array else []


func get_hair_colors() -> Array:
	var colors = _appearance_data.get("hair_color", [])
	return colors if colors is Array else []
