## MobManager — Loads mob data from res://data/mobs.json and manages spawning
## Autoload singleton for overworld/underearth mob management.

class_name MobManager extends Node


signal mob_spawned(mob_data: Dictionary)
signal mob_defeated(mob_id: String)


const MOB_DATA_PATH := "res://data/mobs.json"
const SPRITE_DATA_PATH := "res://data/mob_sprites.json"

var overworld_cache: Dictionary = {"neutral": [], "aggressive": []}
var rift_only_cache: Array[Dictionary] = []
var underearth_defs: Array[Dictionary] = []
var tameable_fruits: Array[Dictionary] = []
var sprite_cache: Dictionary = {}

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
	
	# Parse rift-only mobs
	if result.has("rift_only"):
		var rift_var: Variant = result["rift_only"]
		if rift_var is Array:
			rift_only_cache = rift_var as Array[Dictionary]
	
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
	
	# Load sprite definitions
	_load_sprites()
	
	var total_mobs: int = overworld_cache["neutral"].size() + overworld_cache["aggressive"].size() + rift_only_cache.size()
	print("[MobManager] Loaded %d mob types (%d upworld, %d rift-only), %d underearth templates, %d tameable fruits, %d sprites." % [
		total_mobs,
		overworld_cache["neutral"].size() + overworld_cache["aggressive"].size(),
		rift_only_cache.size(),
		underearth_defs.size(),
		tameable_fruits.size(),
		sprite_cache.size()
	])
	return true


func _load_sprites() -> void:
	var file := FileAccess.open(SPRITE_DATA_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		push_warning("[MobManager] Could not open %s — sprites unavailable." % SPRITE_DATA_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result is Dictionary:
		sprite_cache = (result.get("sprites", {}) if result.get("sprites") is Dictionary else {}) as Dictionary


## Return all available mob types (neutral + aggressive + rift_only) from cached data
func get_all_mobs() -> Array[Dictionary]:
	var all_mobs: Array[Dictionary] = []
	for mobility in ["neutral", "aggressive"]:
		if overworld_cache.has(mobility):
			for m in overworld_cache[mobility]:
				if m is Dictionary:
					all_mobs.append(m.duplicate(true))
	for m in rift_only_cache:
		if m is Dictionary:
			all_mobs.append(m.duplicate(true))
	return all_mobs


## Return mobs filtered by spawn_context ("upworld", "rift", or "both")
func get_mobs_by_context(context: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mobility in ["neutral", "aggressive"]:
		if overworld_cache.has(mobility):
			for m in overworld_cache[mobility]:
				if m is Dictionary and m.get("spawn_context", "upworld") == context:
					result.append(m.duplicate(true))
	if context == "rift":
		for m in rift_only_cache:
			if m is Dictionary:
				result.append(m.duplicate(true))
	return result


## Get a sprite definition by ID
func get_sprite(sprite_id: String) -> Dictionary:
	return sprite_cache.get(sprite_id, {})


## Spawn a mob instance from template (adds randomization to stats)
func spawn_mob(template: Dictionary) -> Dictionary:
	var mob := {
		"id": "%s_%d" % [template.get("name", "Unknown"), randi()],
		"name": template.get("name", "Unknown"),
		"type": template.get("type", "unknown"),
		"hp": clampi(template.get("hp", 50) + randi_range(-5, 5), 1, 9999),
		"armor": maxi(template.get("armor", 0) + randi_range(0, 2), 0),
		"threat_range": template.get("threat_range", 5),
		"spawn_context": template.get("spawn_context", "upworld"),
		"sprite_id": template.get("sprite_id", template.get("type", "")),
	}
	
	# Carry over any extra properties from the template (attack_damage, etc.)
	for key in ["attack_damage", "drain_rate", "swarm_count_min", "swarm_count_max", "drop_item", "rift_type", "is_boss", "preferred_biomes"]:
		if template.has(key):
			mob[key] = template[key]
	
	# Attach sprite data if available
	var sid: String = str(mob.get("sprite_id", ""))
	if not sid.is_empty() and sprite_cache.has(sid):
		mob["sprite_data"] = sprite_cache[sid].duplicate(true)
	
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


## Look up a mob template by its sprite_id (UUID) across all caches.
## Returns the template dictionary (empty if not found).
func get_mob_by_sprite_id(sprite_id: String) -> Dictionary:
	for mobility in ["neutral", "aggressive"]:
		if overworld_cache.has(mobility):
			for m in overworld_cache[mobility]:
				if m is Dictionary and str(m.get("sprite_id", "")) == sprite_id:
					return m.duplicate(true)
	for m in rift_only_cache:
		if m is Dictionary and str(m.get("sprite_id", "")) == sprite_id:
			return m.duplicate(true)
	return {}


## Look up a mob template by its id field across all caches.
## Returns the template dictionary (empty if not found).
func get_mob(id: String) -> Dictionary:
	for mobility in ["neutral", "aggressive"]:
		if overworld_cache.has(mobility):
			for m in overworld_cache[mobility]:
				if m is Dictionary and str(m.get("id", "")) == id:
					return m.duplicate(true)
	for m in rift_only_cache:
		if m is Dictionary and str(m.get("id", "")) == id:
			return m.duplicate(true)
	return {}


## Get count of currently spawned (active) mobs
func get_active_mob_count() -> int:
	return _spawned_mobs.size()
