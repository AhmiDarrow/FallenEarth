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


## ---- Procedural entity visual resolution (Phase 2) ---------------------

## Resolve an entity data dictionary (mob/npc/rift/item/player appearance
## block) into a concrete visual_presets entry from appearance.json.
##
## Resolution order:
##   1. data["visual_preset"] if it names a known preset
##   2. data["mob_type"] / data["type"] looked up in mob_type_visual_map
##   3. fallback "humanoid_default"
## Returns a fresh duplicate so callers can mutate freely.
func resolve_entity_visual(data: Dictionary) -> Dictionary:
	if not data.is_empty() and _appearance_data.is_empty():
		_load_appearance_data()
	var presets: Dictionary = _appearance_data.get("visual_presets", {})
	if presets.is_empty():
		return {"base_type": "humanoid", "material": {"type": "organic"}}

	var preset_name: String = ""
	if data.has("visual_preset") and presets.has(str(data["visual_preset"])):
		preset_name = str(data["visual_preset"])
	elif data.has("mob_type"):
		var vmap: Dictionary = _appearance_data.get("mob_type_visual_map", {})
		var mapped: String = vmap.get(str(data["mob_type"]), "")
		if presets.has(mapped):
			preset_name = mapped
	elif data.has("type"):
		# Check resource map first (resource nodes), then mob map.
		var rmap: Dictionary = _appearance_data.get("resource_node_visual_map", {})
		var rmap_name: String = rmap.get(str(data["type"]), "")
		if presets.has(rmap_name):
			preset_name = rmap_name
		else:
			var vmap: Dictionary = _appearance_data.get("mob_type_visual_map", {})
			var mapped: String = vmap.get(str(data["type"]), "")
			if presets.has(mapped):
				preset_name = mapped

	if preset_name.is_empty():
		preset_name = "humanoid_default"

	var preset: Dictionary = presets.get(preset_name, {}).duplicate(true)
	# Carry through any explicit per-entity overrides.
	if data.has("variation_seed"):
		preset["variation_seed"] = int(data["variation_seed"])
	elif data.has("id"):
		preset["variation_seed"] = str(data["id"]).hash()
	return preset


## Direct preset lookup by name (e.g. "rift_void").
func get_visual_preset(name: String) -> Dictionary:
	var presets: Dictionary = _appearance_data.get("visual_presets", {})
	if presets.has(name):
		return presets[name].duplicate(true)
	return {}


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
