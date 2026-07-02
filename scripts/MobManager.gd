## MobManager — Loads mob data from res://data/mobs.json and manages spawning
## Autoload singleton for overworld/underearth mob management.

class_name MobManager extends Node


signal mob_spawned(mob_data: Dictionary)
signal mob_defeated(mob_id: String)


const MOB_DATA_PATH := "res://data/mobs.json"

var overworld_cache: Dictionary = {"neutral": [], "aggressive": []}
var underearth_defs: Array[Dictionary] = []
var tameable_fruits: Array[Dictionary] = []

# Runtime state tracking (not from JSON, populated at runtime)
var _spawned_mobs: Array[Dictionary] = []


func _ready() -> void:
	_load_mob_data()


## Load mob data from res://data/mobs.json
func load_mob_data(path: String = "") -> bool:
	return _load_mob_data(path)


func _load_mob_data(path: String = "") -> bool:
	var json_path := path if path != "" else MOB_DATA_PATH
	
	var file := FileAccess.open(json_path, FileAccess.READ)
	if not is_instance_valid(file):
		push_error("[MobManager] Failed to open %s" % json_path)
		return false
	
	var text := file.get_as_text()
	file.close()
	
	var result: Variant = JSON.parse_string(text)
	if not (result is Dictionary):
		push_error("[MobManager] mobs.json did not produce a dictionary at top level.")
		return false
	
	# Parse overworld data
	if result.has("overworld"):
		var ow: Variant = result["overworld"]
		if ow is Dictionary:
			overworld_cache["neutral"] = (ow.get("neutral", []) if ow.get("neutral") is Array else []) as Array
			overworld_cache["aggressive"] = (ow.get("aggressive", []) if ow.get("aggressive") is Array else []) as Array
	
	# Parse underearth parts (raw template list)
	if result.has("underearth_parts"):
		var parts: Variant = result["underearth_parts"]
		if parts is Dictionary:
			for key in ["head_types", "body_types", "limb_types", "tail_types"]:
				if parts.has(key):
					underearth_defs.append({
						"type": key,
						"options": (parts[key] if parts[key] is Array else []) as Array
					})
	
	# Parse tameable fruits
	if result.has("tameable_fruits"):
		var fruits: Variant = result["tameable_fruits"]
		tameable_fruits = (fruits if fruits is Array else []) as Array[Dictionary]
	
	print("[MobManager] Loaded %d overworld mob types, %d underearth templates, %d tameable fruits." % [
		overworld_cache["neutral"].size() + overworld_cache["aggressive"].size(),
		underearth_defs.size(),
		tameable_fruits.size()
	])
	return true


## Return all available mob types (neutral + aggressive) from cached data
func get_all_mobs() -> Array[Dictionary]:
	var all_mobs: Array[Dictionary] = []
	for mobility in ["neutral", "aggressive"]:
		if overworld_cache.has(mobility):
			for m in overworld_cache[mobility]:
				if m is Dictionary:
					all_mobs.append(m.duplicate(true))
	return all_mobs


## Spawn a mob instance from template (adds randomization to stats)
func spawn_mob(template: Dictionary) -> Dictionary:
	var mob := {
		"id": "%s_%d" % [template.get("name", "Unknown"), randi()],
		"name": template.get("name", "Unknown"),
		"type": template.get("type", "unknown"),
		"hp": clampi(template.get("hp", 50) + randi_range(-5, 5), 1, 9999),
		"armor": maxi(template.get("armor", 0) + randi_range(0, 2), 0),
		"threat_range": template.get("threat_range", 5),
	}
	
	# Carry over any extra properties from the template (attack_damage, etc.)
	for key in ["attack_damage", "drain_rate", "swarm_count_min", "swarm_count_max", "drop_item"]:
		if template.has(key):
			mob[key] = template[key]
	
	_spawned_mobs.append(mob)
	mob_spawned.emit(mob)
	return mob


## Get all underearth part types (for procedural generation references)
func get_underearth_parts() -> Dictionary:
	var parts := {}
	for item in underearth_defs:
		if item.has("type"):
			parts[item["type"]] = item.get("options", [])
	return parts


## Generate procedural mob using underearth visual part templates
## The stats are derived from base_template; visuals are randomized.
func generate_procedural_mob(base_template: Dictionary) -> Dictionary:
	var mob := base_template.duplicate(true)
	
	for key in ["head_types", "body_types", "limb_types"]:
		if underearth_defs.is_empty():
			continue
		for part_def in underearth_defs:
			if part_def.get("type") == key and part_def.has("options"):
				var options = part_def["options"] as Array
				if not options.is_empty():
					mob[key] = options[randi() % options.size()]
	
	return mob


## Get the list of tameable fruits (for taming UI/combat)
func get_tameable_fruits() -> Array[Dictionary]:
	return tameable_fruits.duplicate()


## Remove a defeated mob from spawned tracking
func remove_mob(mob_id: String) -> bool:
	for i in range(_spawned_mobs.size()):
		if _spawned_mobs[i].get("id") == mob_id:
			_spawned_mobs.remove_at(i)
			mob_defeated.emit(mob_id)
			print("[MobManager] Removed mob: %s (%d remaining)" % [mob_id, _spawned_mobs.size()])
			return true
	
	var found = false
	for key in overworld_cache:
		for m in overworld_cache[key]:
			if m.get("name") == mob_id:
				found = true
				break
		if found:
			break
	
	if not found:
		push_error("[MobManager] Attempted to remove non-existent mob: %s" % mob_id)
	return false


## Get count of currently spawned (active) mobs
func get_active_mob_count() -> int:
	return _spawned_mobs.size()
