## MobSpawner — Spawn rules, biome density tables, RNG seeding.
## Extracted from EncounterBuilder._get_mob_pool / HubWorld._seed_local_mobs.
## Produces Array[MobData] for a given hex — no scene nodes created.
class_name MobSpawner
extends RefCounted
const MobDataRef = preload("res://scripts/mob/MobData.gd")

const MOBS_PATH := "res://data/mobs.json"

static var _mob_cache: Dictionary = {}
static var _cache_loaded: bool = false


static func ensure_cache() -> void:
	if _cache_loaded:
		return
	var file := FileAccess.open(MOBS_PATH, FileAccess.READ)
	if not file:
		push_error("[MobSpawner] Cannot open %s" % MOBS_PATH)
		_cache_loaded = true
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_mob_cache = parsed.duplicate(true)
	_cache_loaded = true


## Pick a random mob template from the pool matching spawn_context + biome + wildlife_class(es)
## allowed_classes: comma-separated list (e.g. "beast,mount") or empty for no filter
static func pick_mob_template(spawn_context: String, biome: String, allowed_classes: String = "") -> Dictionary:
	ensure_cache()
	var pool: Array[Dictionary] = _build_pool(spawn_context, biome, allowed_classes)
	if pool.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return pool[rng.randi() % pool.size()].duplicate(true)


## Build mob pool from cache filtered by context + biome + wildlife_class(es)
static func _build_pool(spawn_context: String, biome: String, allowed_classes: String = "") -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var class_filter: PackedStringArray = allowed_classes.split(",", false) if not allowed_classes.is_empty() else PackedStringArray()
	for category in ["neutral", "aggressive"]:
		var mobs: Array = _mob_cache.get("overworld", {}).get(category, [])
		for mob in mobs:
			if mob is Dictionary:
				var spawn_ctx_val = mob.get("spawn_context", "upworld")
				var ctx: String
				if spawn_ctx_val is Dictionary:
					ctx = str(spawn_ctx_val.get("zone", "upworld"))
				else:
					ctx = str(spawn_ctx_val)
				if ctx == spawn_context or ctx == "both":
					if _biome_matches(mob, biome):
						if _class_matches(mob, class_filter):
							if spawn_context != "rift" and (mob.get("is_boss", false) or mob.has("rift_type")):
								continue
							pool.append(mob)
	if spawn_context == "rift":
		var rift_mobs: Array = _mob_cache.get("rift_only", [])
		for mob in rift_mobs:
			if mob is Dictionary and _biome_matches(mob, biome):
				if _class_matches(mob, class_filter):
					pool.append(mob)
	return pool


static func _class_matches(mob: Dictionary, class_filter: PackedStringArray) -> bool:
	if class_filter.is_empty():
		return true
	var wc: String = str(mob.get("wildlife_class", ""))
	if wc.is_empty():
		return true
	for c in class_filter:
		if c.strip_edges() == wc:
			return true
	return false


static func _biome_matches(mob: Dictionary, biome: String) -> bool:
	if biome.is_empty():
		return true
	if mob.has("preferred_biomes"):
		var preferred = mob["preferred_biomes"]
		if preferred is Array:
			for b in preferred:
				if str(b) == biome:
					return true
			return false
	var sc: Variant = mob.get("spawn_context", {})
	if sc is Dictionary and sc.has("biome"):
		return str(sc["biome"]) == biome
	return true


## Generate an array of MobData for a hex. Returns empty on failure.
static func spawn_for_hex(
	world_seed: String,
	tile_map: Dictionary,
	hex_q: int, hex_r: int,
	local_map: Dictionary,
	player_local_x: int, player_local_y: int,
	rng_seed: int
) -> Array[MobDataRef]:
	var hex_key := "%d,%d" % [hex_q, hex_r]
	var tile: Dictionary = tile_map.get(hex_key, {})
	var biome: String = str(tile.get("name", "Ash Wastes"))
	var danger: float = float(tile.get("rift_chance", 0.25))
	var level_range: Dictionary = tile.get("level_range", {"min_level": 2, "max_level": 6})
	var spawn_context: String = "upworld"

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var count := rng.randi_range(8, 12 + int(danger * 8))
	var result: Array[MobDataRef] = []

	# Overworld mob distribution: 80% wildlife, 10% mounts, 10% humanoid NPC (handled by EncounterBuilder)

	# 2 guaranteed near-spawn mobs
	for _i in range(2):
		var tries := 0
		while tries < 16:
			tries += 1
			var ndx := rng.randi_range(-20, 20)
			var ndy := rng.randi_range(-15, 15)
			if abs(ndx) + abs(ndy) < 3:
				continue
			var nlx := clampi(player_local_x + ndx, 4, 504)
			var nly := clampi(player_local_y + ndy, 4, 504)
			if _is_cell_blocked(local_map, nlx, nly):
				continue
			var class_filter := _roll_class_filter(rng)
			if class_filter == "humanoid_npc":
				break
			var enemy := _generate_enemy(rng, world_seed, tile_map, hex_key,
				{"min_level": level_range.get("min_level", 2), "max_level": mini(level_range.get("min_level", 2) + 3, level_range.get("max_level", 5))},
				spawn_context, biome, class_filter)
			if enemy.is_empty():
				continue
			result.append(MobDataRef.from_enemy_dict(enemy, nlx, nly))
			break

	# Regular mobs
	for i in range(count):
		var class_filter := _roll_class_filter(rng)
		if class_filter == "humanoid_npc":
			continue
		var lx := rng.randi_range(10, 500)
		var ly := rng.randi_range(10, 500)
		if _is_cell_blocked(local_map, lx, ly):
			continue
		if abs(lx - player_local_x) + abs(ly - player_local_y) < 2:
			continue
		var difficulty := {"min_level": level_range.get("min_level", 2), "max_level": level_range.get("max_level", 6)}
		var enemy := _generate_enemy(rng, world_seed, tile_map, hex_key, difficulty, spawn_context, biome, class_filter)
		if enemy.is_empty():
			continue
		result.append(MobDataRef.from_enemy_dict(enemy, lx, ly))

	return result


static func _is_cell_blocked(local_map: Dictionary, x: int, y: int) -> bool:
	var map_size: int = int(local_map.get("size", 512))
	if x < 0 or y < 0 or x >= map_size or y >= map_size:
		return true
	var terrain_key := "terrain"
	var terrain_data: PackedByteArray = local_map.get(terrain_key, PackedByteArray())
	if terrain_data.is_empty():
		return false
	var idx := y * map_size + x
	if idx < 0 or idx >= terrain_data.size():
		return true
	var t := int(terrain_data[idx])
	return t == LocalMapGenerator.TERRAIN_BLOCKED or t == LocalMapGenerator.TERRAIN_WATER


## Roll class filter for the 80/10/10 overworld distribution.
## Returns "" (any class) for wildlife, "mount" for mounts, or "humanoid_npc" to skip.
static func _roll_class_filter(rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(0, 99)
	if roll < 80:
		return ""
	if roll < 90:
		return "mount"
	return "humanoid_npc"


static func _generate_enemy(
	rng: RandomNumberGenerator,
	world_seed: String,
	tile_map: Dictionary,
	start_tile_key: String,
	difficulty: Dictionary,
	spawn_context: String,
	biome: String,
	class_filter: String = ""
) -> Dictionary:
	var chosen := pick_mob_template(spawn_context, biome, class_filter)
	if chosen.is_empty():
		return {}

	var min_level := int(difficulty.get("min_level", 2))
	var max_level := int(difficulty.get("max_level", 6))
	var level := clampi(min_level + rng.randi_range(0, max_level - min_level), min_level, max_level)

	var base_stats: Dictionary = chosen.get("base_stats", {}) if chosen.get("base_stats") is Dictionary else {}
	var base_hp := int(chosen.get("hp", base_stats.get("health", level * 10)))
	var base_damage := int(chosen.get("attack_damage", chosen.get("dps", level * 2)))
	var base_armor := int(chosen.get("armor", base_stats.get("armor", 0)))

	var tile: Dictionary = tile_map.get(start_tile_key, {})
	var threat_mult := float(tile.get("wildlife_modifiers", {}).get("threat_multiplier", 1.0))
	if threat_mult != 1.0:
		base_hp = int(base_hp * threat_mult)
		base_damage = int(base_damage * threat_mult)
		base_armor = int(base_armor * threat_mult)

	var enemy := {
		"id": "%s_%d" % [chosen.get("id", "mob"), rng.randi() % 10000],
		"name": str(chosen.get("name", "Mob")),
		"sprite_id": str(chosen.get("sprite_id", chosen.get("id", ""))),
		"level": level,
		"hp": base_hp,
		"max_hp": base_hp,
		"attack_damage": base_damage,
		"armor": base_armor,
		"mob_type": str(chosen.get("ai_archetype", "aggressive")),
		"aggro_range": int(chosen.get("threat_range", 5)),
		"threat_mult": threat_mult,
		"spawn_context": spawn_context,
		"wildlife_class": str(chosen.get("wildlife_class", "beast")),
	}
	for key in ["drain_rate", "is_boss", "rift_type", "drops"]:
		if chosen.has(key):
			enemy[key] = chosen[key]
	return enemy
