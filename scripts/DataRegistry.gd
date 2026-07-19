## DataRegistry — Centralized JSON data loading with mod overlay merge.
extends Node

var _base_data: Dictionary = {}
var _overlays: Dictionary = {}
var _overlay_strategies: Dictionary = {}
var _merge_cache: Dictionary = {}
var _base_loaded: bool = false

const BASE_FILES := {
	"items": "res://data/items.json",
	"weapons": "res://data/weapons.json",
	"armor": "res://data/armor.json",
	"accessories": "res://data/accessories.json",
	"tools": "res://data/tools.json",
	"recipes": "res://data/recipes.json",
	"mobs": "res://data/mobs.json",
	"biomes": "res://data/biomes.json",
	"resource_nodes": "res://data/resource_nodes.json",
	"factions": "res://data/factions.json",
	"dialogue": "res://data/dialogue.json",
	"missions": "res://data/mission_templates.json",
	"races": "res://data/races.json",
	"classes": "res://data/character_classes.json",
	"appearance": "res://data/appearance.json",
	"towns": "res://data/towns.json",
	"base": "res://data/base.json",
	"base_shops": "res://data/base_shops.json",
	"loot_tables": "res://data/loot_tables.json",
	"tips": "res://data/tips.json",
	"joinable_npc_templates": "res://data/joinable_npc_templates.json",
	"npc_name_parts": "res://data/npc_name_parts.json",
	"npc_archetypes": "res://data/npc_archetypes.json",
	"enemy_archetypes": "res://data/enemy_archetypes.json",
	"mob_sprites": "res://data/mob_sprites.json",
	"settlement_rooms": "res://data/settlement_rooms.json",
	"riftspire_layout": "res://data/riftspire_layout.json",
	"seeds": "res://data/seeds.json",
	"story_chapters": "res://data/story_chapters.json",
	"dynamic_threat": "res://data/dynamic_threat.json",
	"tame_config": "res://data/tame_config.json",
}


func _ready() -> void:
	_load_all_base_data()
	_register_mod_overlays()


func _load_all_base_data() -> void:
	for key in BASE_FILES:
		var path: String = BASE_FILES[key]
		var data = _load_json_file(path)
		if data != null:
			_base_data[key] = data
	_base_loaded = true
	print("[DataRegistry] Loaded %d base data files" % _base_data.size())


func _load_json_file(path: String) -> Variant:
	if not ResourceLoader.exists(path):
		push_warning("[DataRegistry] File not found: %s" % path)
		return null
	var resource = load(path)
	if resource == null:
		return null
	var data: Variant = null
	if resource is Dictionary:
		data = resource
	elif "data" in resource:
		var d = resource.data
		if d is Dictionary:
			data = d
		elif d != null:
			data = d
	if data == null:
		push_warning("[DataRegistry] Failed to parse: %s" % path)
	return data


func _register_mod_overlays() -> void:
	var ml := get_node_or_null("/root/ModLoader")
	if ml == null:
		return
	for mod_id in ml.load_order:
		var manifest = ml.get_manifest(mod_id)
		if manifest.is_empty():
			continue
		var data_dir: String = manifest.path + "data/"
		if not DirAccess.dir_exists_absolute(data_dir):
			continue
		_scan_mod_data_dir(mod_id, data_dir)


func _scan_mod_data_dir(mod_id: String, data_dir: String) -> void:
	var dir := DirAccess.open(data_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path := data_dir + file_name
			var data_key := file_name.trim_suffix(".json")
			_load_mod_overlay(mod_id, data_key, file_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_mod_overlay(mod_id: String, data_key: String, file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("[ModLoader] Cannot open overlay file: %s" % file_path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("[ModLoader] Overlay file not a dictionary: %s" % file_path)
		return
	var strategy: String = parsed.get("strategy", "merge")
	var overlay_data: Variant = parsed.get("data", null)
	if overlay_data == null:
		push_warning("[ModLoader] Overlay file missing 'data' key: %s" % file_path)
		return
	if strategy not in ["merge", "append", "override", "patch"]:
		push_warning("[ModLoader] Invalid strategy '%s' in %s" % [strategy, file_path])
		return
	if not _overlays.has(mod_id):
		_overlays[mod_id] = {}
	_overlays[mod_id][data_key] = overlay_data
	if not _overlay_strategies.has(mod_id):
		_overlay_strategies[mod_id] = {}
	_overlay_strategies[mod_id][data_key] = strategy
	_merge_cache.erase(data_key)
	ModAPI.log(mod_id, "Registered overlay for '%s' (strategy: %s)" % [data_key, strategy])


func get_data(data_key: String) -> Variant:
	if _merge_cache.has(data_key):
		return _merge_cache[data_key]
	var result = _base_data.get(data_key)
	if result == null:
		return null
	var ml := get_node_or_null("/root/ModLoader")
	if ml == null:
		return result
	for mod_id in ml.load_order:
		if _overlays.has(mod_id) and _overlays[mod_id].has(data_key):
			var strategy: String = _overlay_strategies.get(mod_id, {}).get(data_key, "merge")
			var overlay = _overlays[mod_id][data_key]
			result = _merge_overlay(result, overlay, strategy)
	_merge_cache[data_key] = result
	return result


func get_base(data_key: String) -> Variant:
	return _base_data.get(data_key)


func clear_cache(data_key: String = "") -> void:
	if data_key.is_empty():
		_merge_cache.clear()
	else:
		_merge_cache.erase(data_key)


func reload_mod_overlays(mod_id: String) -> void:
	_overlays.erase(mod_id)
	_overlay_strategies.erase(mod_id)
	_merge_cache.clear()
	var ml := get_node_or_null("/root/ModLoader")
	if ml == null:
		return
	var manifest = ml.get_manifest(mod_id)
	if manifest.is_empty():
		return
	var data_dir: String = manifest.path + "data/"
	if DirAccess.dir_exists_absolute(data_dir):
		_scan_mod_data_dir(mod_id, data_dir)


func _merge_overlay(base: Variant, overlay: Variant, strategy: String) -> Variant:
	match strategy:
		"merge":
			if base is Dictionary and overlay is Dictionary:
				return _deep_merge(base, overlay)
			return overlay
		"append":
			return _array_append(base, overlay)
		"override":
			if overlay is Dictionary:
				return overlay.duplicate(true)
			return overlay
		"patch":
			if base is Dictionary and overlay is Array:
				return _apply_json_patch(base, overlay)
			return base
	return base


func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overlay:
		if result.has(key) and result[key] is Dictionary and overlay[key] is Dictionary:
			result[key] = _deep_merge(result[key], overlay[key])
		else:
			if overlay[key] is Dictionary:
				result[key] = overlay[key].duplicate(true)
			else:
				result[key] = overlay[key]
	return result


func _array_append(base: Variant, overlay: Variant) -> Variant:
	if base is Dictionary and overlay is Dictionary:
		var result: Dictionary = base.duplicate(true)
		for key in overlay:
			if result.has(key) and result[key] is Array and overlay[key] is Array:
				var arr: Array = result[key].duplicate()
				arr.append_array(overlay[key])
				result[key] = arr
			else:
				if overlay[key] is Dictionary:
					result[key] = overlay[key].duplicate(true)
				else:
					result[key] = overlay[key]
		return result
	return base


func _apply_json_patch(base: Dictionary, patch: Array) -> Dictionary:
	var result := base.duplicate(true)
	for operation in patch:
		if not (operation is Dictionary):
			continue
		var op: String = str(operation.get("op", ""))
		var path: String = str(operation.get("path", ""))
		var value: Variant = operation.get("value")
		match op:
			"add":
				_json_patch_add(result, path, value)
			"remove":
				_json_patch_remove(result, path)
			"replace":
				_json_patch_replace(result, path, value)
	return result


func _json_patch_add(target: Dictionary, path: String, value: Variant) -> void:
	var parts := path.trim_prefix("/").split("/")
	var current = target
	for i in range(parts.size() - 1):
		var part: String = parts[i]
		if part.is_valid_int():
			var idx: int = int(part)
			if current is Array and idx >= 0 and idx < current.size():
				current = current[idx]
			else:
				return
		else:
			if current is Dictionary and current.has(part):
				current = current[part]
			else:
				return
	var last_key: String = parts[parts.size() - 1]
	if current is Dictionary:
		current[last_key] = value
	elif current is Array and last_key.is_valid_int():
		var idx: int = int(last_key)
		if idx >= 0 and idx <= current.size():
			current.insert(idx, value)


func _json_patch_remove(target: Dictionary, path: String) -> void:
	var parts := path.trim_prefix("/").split("/")
	var current = target
	for i in range(parts.size() - 1):
		var part: String = parts[i]
		if part.is_valid_int():
			var idx: int = int(part)
			if current is Array and idx >= 0 and idx < current.size():
				current = current[idx]
			else:
				return
		else:
			if current is Dictionary and current.has(part):
				current = current[part]
			else:
				return
	var last_key: String = parts[parts.size() - 1]
	if current is Dictionary:
		current.erase(last_key)
	elif current is Array and last_key.is_valid_int():
		var idx: int = int(last_key)
		if idx >= 0 and idx < current.size():
			current.remove_at(idx)


func _json_patch_replace(target: Dictionary, path: String, value: Variant) -> void:
	_json_patch_remove(target, path)
	_json_patch_add(target, path, value)
