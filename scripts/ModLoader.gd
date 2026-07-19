## ModLoader — Discovers, validates, and loads mods from user://mods/.
##
## Autoload #1 — runs before all other autoloads. Scans mod directories,
## parses manifests, resolves dependency order, loads entry scripts.
extends Node

signal mods_loaded(count: int)
signal mod_failed(mod_id: String, reason: String)

const MODS_DIR := "user://mods/"
const BUNDLED_MODS_DIR := "res://user/mods/"
const MANIFEST_FILE := "mod.cfg"

var manifests: Dictionary = {}   # mod_id -> ModManifest dict
var mod_nodes: Dictionary = {}   # mod_id -> Node instance
var load_order: Array[String] = []
var failed_mods: Array[String] = []


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_ensure_mods_dir()
	var discovered := _discover_mods()
	var ordered := _resolve_order(discovered)
	for mod_id in ordered:
		_load_mod(mod_id)
	load_order = ordered
	print("[ModLoader] Loaded %d mods (out of %d discovered). %d failed." % [
		mod_nodes.size(), discovered.size(), failed_mods.size()
	])
	mods_loaded.emit(mod_nodes.size())


func _ensure_mods_dir() -> void:
	if not DirAccess.dir_exists_absolute(MODS_DIR):
		DirAccess.make_dir_recursive_absolute(MODS_DIR)


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

func _discover_mods() -> Array[String]:
	var mod_ids: Array[String] = []
	_scan_mods_dir(MODS_DIR, mod_ids)
	_scan_mods_dir(BUNDLED_MODS_DIR, mod_ids)
	return mod_ids


func _scan_mods_dir(base_dir: String, mod_ids: Array[String]) -> void:
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name != "." and folder_name != "..":
			var mod_path := base_dir + folder_name + "/"
			var manifest_path := mod_path + MANIFEST_FILE
			if FileAccess.file_exists(manifest_path):
				var manifest := _parse_manifest(manifest_path, folder_name, mod_path)
				if not manifest.is_empty():
					var found_id: String = str(manifest.id)
					if manifests.has(found_id):
						print("[ModLoader] Skipping duplicate mod '%s' at %s (already found at %s)" % [
							found_id, mod_path, str(manifests[found_id].path)
						])
					else:
						manifests[found_id] = manifest
						mod_ids.append(found_id)
				else:
					failed_mods.append(folder_name)
					mod_failed.emit(folder_name, "Invalid or unreadable manifest")
		folder_name = dir.get_next()
	dir.list_dir_end()


func _parse_manifest(path: String, fallback_id: String, mod_path: String) -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		push_warning("[ModLoader] Cannot load manifest: %s (error %d)" % [path, err])
		return {}
	var mod_id: String = str(cfg.get_value("mod", "id", fallback_id))
	if mod_id.is_empty():
		push_warning("[ModLoader] Manifest missing 'id': %s" % path)
		return {}
	# Validate mod_id characters
	for c in mod_id:
		if not (c in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
			push_warning("[ModLoader] Invalid mod_id '%s' — only a-z, 0-9, _, - allowed" % mod_id)
			return {}
	var version: String = str(cfg.get_value("mod", "version", "0.0.0"))
	var name_str: String = str(cfg.get_value("mod", "name", mod_id))
	var author: String = str(cfg.get_value("mod", "author", ""))
	var description: String = str(cfg.get_value("mod", "description", ""))
	var dependencies_str: String = str(cfg.get_value("mod", "dependencies", ""))
	var dependencies: Array[String] = []
	if not dependencies_str.is_empty():
		for dep in dependencies_str.split(",", false):
			dependencies.append(dep.strip_edges())
	var load_order_val: int = int(cfg.get_value("mod", "load_order", 100))
	var entry_script: String = str(cfg.get_value("mod", "entry_script", ""))
	# Parse settings section
	var settings: Dictionary = {}
	if cfg.has_section("settings"):
		for key in cfg.get_section_keys("settings"):
			settings[key] = cfg.get_value("settings", key)
	return {
		"id": mod_id,
		"name": name_str,
		"version": version,
		"author": author,
		"description": description,
		"dependencies": dependencies,
		"load_order": load_order_val,
		"entry_script": entry_script,
		"settings": settings,
		"path": mod_path,
	}


# ---------------------------------------------------------------------------
# Dependency resolution (topological sort)
# ---------------------------------------------------------------------------

func _resolve_order(mod_ids: Array[String]) -> Array[String]:
	if mod_ids.is_empty():
		return []
	# Build adjacency: mod_id -> [dependency ids]
	var graph: Dictionary = {}
	var in_degree: Dictionary = {}
	for mod_id in mod_ids:
		graph[mod_id] = []
		in_degree[mod_id] = 0
	for mod_id in mod_ids:
		var manifest = manifests.get(mod_id)
		if manifest == null:
			continue
		for dep_entry in manifest.dependencies:
			var dep_id: String = str(dep_entry).split("@")[0].strip_edges()
			if not graph.has(dep_id):
				# Dependency not installed — skip, will be caught in validation
				continue
			graph[dep_id].append(mod_id)
			in_degree[mod_id] += 1
	# Kahn's algorithm
	var queue: Array[String] = []
	for mod_id in mod_ids:
		if in_degree[mod_id] == 0:
			queue.append(mod_id)
	# Sort initial queue by load_order
	queue.sort_custom(func(a, b):
		var oa = manifests.get(a, {}).get("load_order", 100)
		var ob = manifests.get(b, {}).get("load_order", 100)
		if oa == ob:
			return a < b
		return oa < ob
	)
	var result: Array[String] = []
	while not queue.is_empty():
		var current: String = queue.pop_front()
		result.append(current)
		for neighbor in graph[current]:
			in_degree[neighbor] -= 1
			if in_degree[neighbor] == 0:
				queue.append(neighbor)
		# Re-sort by load_order
		queue.sort_custom(func(a, b):
			var oa = manifests.get(a, {}).get("load_order", 100)
			var ob = manifests.get(b, {}).get("load_order", 100)
			if oa == ob:
				return a < b
			return oa < ob
		)
	if result.size() != mod_ids.size():
		# Cycle detected or missing dependencies
		var missing: Array[String] = []
		for mod_id in mod_ids:
			if not result.has(mod_id):
				missing.append(mod_id)
		push_error("[ModLoader] Dependency cycle or missing deps detected. Unresolvable mods: %s" % ", ".join(missing))
		for m in missing:
			failed_mods.append(m)
	return result


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

func _load_mod(mod_id: String) -> void:
	var manifest = manifests.get(mod_id)
	if manifest == null:
		return
	# Check dependencies are satisfied
	for dep_entry in manifest.dependencies:
		var dep_id: String = str(dep_entry).split("@")[0].strip_edges()
		if not mod_nodes.has(dep_id):
			push_warning("[ModLoader] Mod '%s' depends on '%s' which is not loaded. Skipping." % [mod_id, dep_id])
			failed_mods.append(mod_id)
			mod_failed.emit(mod_id, "Missing dependency: %s" % dep_id)
			return
	# Load entry script
	var entry_script_path: String = manifest.entry_script
	if entry_script_path.is_empty():
		# No entry script — mod is loaded but has no code
		print("[ModLoader] Mod '%s' v%s loaded (no entry script)" % [mod_id, manifest.version])
		return
	# Relative paths resolve against the mod's own folder
	if not entry_script_path.contains("://"):
		entry_script_path = str(manifest.path) + entry_script_path
	if not ResourceLoader.exists(entry_script_path):
		push_warning("[ModLoader] Mod '%s' entry script not found: %s" % [mod_id, entry_script_path])
		failed_mods.append(mod_id)
		mod_failed.emit(mod_id, "Entry script not found: %s" % entry_script_path)
		return
	var script = load(entry_script_path)
	if script == null:
		push_warning("[ModLoader] Mod '%s' failed to load script: %s" % [mod_id, entry_script_path])
		failed_mods.append(mod_id)
		mod_failed.emit(mod_id, "Failed to load script: %s" % entry_script_path)
		return
	var node: Node = script.new()
	if not node is Node:
		push_warning("[ModLoader] Mod '%s' entry script does not extend Node" % mod_id)
		failed_mods.append(mod_id)
		mod_failed.emit(mod_id, "Entry script does not extend Node")
		return
	node.name = "Mod_%s" % mod_id
	add_child(node)
	mod_nodes[mod_id] = node
	# Register as autoload if the mod requests it
	if Engine.has_singleton(mod_id):
		push_warning("[ModLoader] Mod '%s' — singleton name conflicts with existing autoload" % mod_id)
	print("[ModLoader] Mod '%s' v%s loaded successfully (order: %d)" % [mod_id, manifest.version, manifest.load_order])


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_installed_mods_summary() -> Dictionary:
	var installed: Array[String] = []
	for mod_id in mod_nodes:
		var manifest = manifests.get(mod_id)
		if manifest != null:
			installed.append("%s@%s" % [mod_id, manifest.version])
	return {"installed": installed, "load_order": load_order}


func get_manifest(mod_id: String) -> Dictionary:
	return manifests.get(mod_id, {})


func is_mod_loaded(mod_id: String) -> bool:
	return mod_nodes.has(mod_id)


func get_mod_node(mod_id: String) -> Node:
	return mod_nodes.get(mod_id)


func get_mod_path(mod_id: String) -> String:
	var manifest = manifests.get(mod_id)
	if manifest != null:
		return manifest.path
	return ""
