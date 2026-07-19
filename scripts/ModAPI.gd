## ModAPI — Central extension registry for all mod interactions.
##
## Autoload #2 — mods call register_*() methods to add content.
## Provides data overlays, save keys, UI extensions, settings, and logging.
extends Node

signal setting_changed(mod_id: String, key: String, value: Variant)

var _overlays: Dictionary = {}
var _overlay_strategies: Dictionary = {}
var _snapshot_managers: Array[Dictionary] = []
var _save_keys: Dictionary = {}
var _extensions: Dictionary = {
	"character_menu_tabs": [],
	"hud_overlays": [],
	"pause_menu_entries": [],
}
var _settings: Dictionary = {}
var log_lines: Array[Dictionary] = []
const LOG_DIR := "user://mods/"


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func register_data_overlay(mod_id: String, data_key: String, overlay_data: Variant, strategy: String = "merge") -> void:
	if not _overlays.has(mod_id):
		_overlays[mod_id] = {}
	_overlays[mod_id][data_key] = overlay_data
	if not _overlay_strategies.has(mod_id):
		_overlay_strategies[mod_id] = {}
	_overlay_strategies[mod_id][data_key] = strategy
	var dr := get_node_or_null("/root/DataRegistry")
	if dr != null and dr.has_method("clear_cache"):
		dr.clear_cache()


func get_overlay(mod_id: String, data_key: String) -> Variant:
	if _overlays.has(mod_id) and _overlays[mod_id].has(data_key):
		return _overlays[mod_id][data_key]
	return null


func get_overlay_strategy(mod_id: String, data_key: String) -> String:
	if _overlay_strategies.has(mod_id) and _overlay_strategies[mod_id].has(data_key):
		return _overlay_strategies[mod_id][data_key]
	return "merge"


func get_all_overlay_mods() -> Array[String]:
	var result: Array[String] = []
	for mod_id in _overlays:
		result.append(mod_id)
	return result


func register_snapshot_manager(mod_id: String, manager_path: String, key: String, wrapper_key: String = "") -> void:
	_snapshot_managers.append({
		"mod_id": mod_id,
		"path": manager_path,
		"key": key,
		"wrapper_key": wrapper_key,
	})


func get_snapshot_managers() -> Array[Dictionary]:
	return _snapshot_managers.duplicate(true)


func register_save_key(mod_id: String, key: String, getter: Callable, setter: Callable) -> void:
	if not _save_keys.has(mod_id):
		_save_keys[mod_id] = {}
	_save_keys[mod_id][key] = {"getter": getter, "setter": setter}


func get_mod_save_data() -> Dictionary:
	var result: Dictionary = {}
	for mod_id in _save_keys:
		result[mod_id] = {}
		for key in _save_keys[mod_id]:
			var callable: Callable = _save_keys[mod_id][key]["getter"]
			if callable.is_valid():
				result[mod_id][key] = callable.call()
	return result


func apply_mod_save_data(data: Dictionary) -> void:
	for mod_id in data:
		if _save_keys.has(mod_id):
			for key in data[mod_id]:
				if _save_keys[mod_id].has(key):
					var callable: Callable = _save_keys[mod_id][key]["setter"]
					if callable.is_valid():
						callable.call(data[mod_id][key])


func add_tab(tab_id: String, label: String, scene_path: String, icon: Texture2D = null) -> void:
	_extensions["character_menu_tabs"].append({
		"id": tab_id,
		"label": label,
		"scene_path": scene_path,
		"icon": icon,
	})


func add_hud_overlay(overlay_id: String, scene_path: String, anchor: String = "top_right") -> void:
	_extensions["hud_overlays"].append({
		"id": overlay_id,
		"scene_path": scene_path,
		"anchor": anchor,
	})


func add_pause_menu_entry(entry_id: String, label: String, callback: Callable) -> void:
	_extensions["pause_menu_entries"].append({
		"id": entry_id,
		"label": label,
		"callback": callback,
	})


func get_extensions(extension_type: String) -> Array:
	return _extensions.get(extension_type, [])


func add_scene_to(parent_path: String, scene_path: String) -> void:
	var parent := get_node_or_null(parent_path)
	if parent == null:
		push_warning("[ModAPI] Parent node not found: %s" % parent_path)
		return
	if not ResourceLoader.exists(scene_path):
		push_warning("[ModAPI] Scene not found: %s" % scene_path)
		return
	var scene = load(scene_path).instantiate()
	parent.add_child(scene)


func register_setting(mod_id: String, key: String, default_value: Variant, display_name: String, type: String = "float") -> void:
	if not _settings.has(mod_id):
		_settings[mod_id] = {}
	_settings[mod_id][key] = {
		"value": default_value,
		"default_value": default_value,
		"display_name": display_name,
		"type": type,
	}
	var saved: Variant = _load_setting(mod_id, key)
	if saved != null:
		_settings[mod_id][key]["value"] = saved


func get_setting(mod_id: String, key: String) -> Variant:
	if _settings.has(mod_id) and _settings[mod_id].has(key):
		return _settings[mod_id][key]["value"]
	return null


func set_setting(mod_id: String, key: String, value: Variant) -> void:
	if _settings.has(mod_id) and _settings[mod_id].has(key):
		_settings[mod_id][key]["value"] = value
		_save_setting(mod_id, key, value)
		setting_changed.emit(mod_id, key, value)


func get_all_settings() -> Dictionary:
	return _settings


func _save_setting(mod_id: String, key: String, value: Variant) -> void:
	var path := "user://mods/%s/settings.cfg" % mod_id
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(path):
		cfg.load(path)
	cfg.set_value("settings", key, value)
	cfg.save(path)


func _load_setting(mod_id: String, key: String) -> Variant:
	var path := "user://mods/%s/settings.cfg" % mod_id
	if not FileAccess.file_exists(path):
		return null
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return null
	return cfg.get_value("settings", key)


func log(mod_id: String, message: String, level: int = 0) -> void:
	var entry := {
		"mod_id": mod_id,
		"message": message,
		"level": level,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	log_lines.append(entry)
	if log_lines.size() > 1000:
		log_lines = log_lines.slice(-500)
	var prefix := "[%s] " % mod_id
	match level:
		0: print(prefix + message)
		1: push_warning(prefix + message)
		2: push_error(prefix + message)
	_write_log_file(mod_id, entry)


func _write_log_file(mod_id: String, entry: Dictionary) -> void:
	var log_dir := LOG_DIR + mod_id + "/logs/"
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_recursive_absolute(log_dir)
	var date_str := Time.get_date_string_from_system()
	var log_file_path := log_dir + date_str + ".log"
	var file := FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	var level_str: String = ["INFO", "WARN", "ERROR"][clampi(entry.level, 0, 2)]
	file.store_line("[%s] [%s] %s" % [entry.timestamp, level_str, entry.message])
	file.close()
