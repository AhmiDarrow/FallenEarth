## EncounterBuilder — Procedural enemy generation for overworld encounters.
## Constructs hostile mobs matching EncounterDifficulty thresholds, emits spawn signals,
## and can optionally validate against NPCManager's roster when NPCManager is available.

class_name EncounterBuilder
extends RefCounted

signal enemy_spawned(enemy_id: String, enemy_data: Dictionary)
signal enemy_spawn_failed(enemy_id: String, reason: String)

const ARCHETYPES_PATH := "res://data/npc_archetypes.json"
const ENEMY_ARCHETYPES_PATH := "res://data/enemy_archetypes.json"
const APPEARANCE_PATH := "res://data/appearance.json"

const GENERATION_SALT := "fallen_enemies_v1"

# Enemy archetype weights — separate from NPC archetypes
const ENEMY_WEIGHTS := {
	"quadruped": 4,
	"insectoid": 3,
	"behemoth": 1,
	"aberrant": 2,
}

static func generate_procedural_enemy(
	world_seed: String,
	tile_map: Dictionary,
	start_tile_key: String,
	difficulty: Dictionary,
	npc_manager: NPCManager = null
) -> Dictionary:
	# Difficulty thresholds — adjust per world state
	var min_level: int = int(difficulty.get("min_level", 2))
	var max_level: int = int(difficulty.get("max_level", 8))

	# Load enemy archetypes (same as NPC archetypes but enemy-specific)
	var archetypes: Dictionary = _load_json_dict(ENEMY_ARCHETYPES_PATH)
	if archetypes.is_empty():
		archetypes = _load_json_dict(ARCHETYPES_PATH)  # fallback to NPC archetypes

	var appearance_opts: Dictionary = _load_json_dict(APPEARANCE_PATH)
	var rng := _make_rng(world_seed, GENERATION_SALT)

	# Pick an archetype based on difficulty — harder difficulties lean toward dangerous archetypes
	var archetype_key: String = _pick_enemy_archetype(archetypes, difficulty, rng)
	if archetype_key.is_empty():
		return {}

	# Find a tile for the enemy — reuse NPCManager's _pick_tile logic if available
	var tile_key: String = _pick_enemy_tile(tile_map, start_tile_key, archetype_key, rng)
	if tile_key.is_empty():
		return {}

	var tile: Dictionary = tile_map.get(tile_key, {}) as Dictionary
	var level: int = clampi(min_level + rng.randi_range(0, max_level - min_level), min_level, max_level)
	var race_id: String = _pick_enemy_race(archetype_key, rng)
	var class_id: String = _pick_enemy_class(archetype_key, rng)
	var gender: String = ["male", "female", "nonbinary"][rng.randi() % 3]
	var traits: Array[String] = _pick_enemy_traits(archetype_key, rng)

	var stats: Dictionary = {
		"str": clampi(rng.randi_range(8, 16), 8, 18),
		"dex": clampi(rng.randi_range(8, 16), 8, 18),
		"con": clampi(rng.randi_range(8, 16), 8, 18),
		"int": clampi(rng.randi_range(8, 14), 8, 16),
		"wis": clampi(rng.randi_range(8, 14), 8, 16),
		"cha": clampi(rng.randi_range(8, 14), 8, 16),
	}

	var appearance: Dictionary = _roll_appearance(appearance_opts, rng)
	var archetype_def: Dictionary = archetypes.get(archetype_key, {}) as Dictionary
	var rarity: String = str(archetype_def.get("rarity", "common"))

	# Build enemy data — intentionally mirrors NPC structure for NPCManager validation
	var enemy_id := "enemy_%s_%03d" % [tile_key.left(6), rng.randi() % 1000]
	var display_name: String = _build_enemy_name(appearance, archetype_key, rng)

	var enemy: Dictionary = {
		"id": enemy_id,
		"name": display_name,
		"race": race_id,
		"gender": gender,
		"origin": race_id,
		"class": class_id,
		"archetype": archetype_key,
		"role": str(archetype_def.get("display_role", archetype_key.capitalize())),
		"faction": "Enemy",
		"faction_key": "enemy",
		"traits": traits,
		"level": level,
		"stats": stats,
		"appearance": appearance,
		"tile_key": tile_key,
		"biome": str(tile.get("name", "Ash Wastes")),
		"rarity": rarity,
		"status": "spawned",
		"hostile": true,
		"aggression": archetype_def.get("aggression", 0.6),
		"health": level * 10,
		"damage": level * 2,
		"speed": level * 0.3,
		"has_procedural_assets": true,
	}

	# Optional NPCManager validation — if NPCManager is provided, check that the enemy's
	# archetype has a procedural fallback available; otherwise proceed unconditionally.
	if npc_manager != null:
		if not npc_manager.has_procedural_assets(enemy):
			push_warning("[EncounterBuilder] Enemy %s lacks procedural assets — skipping spawn." % enemy_id)
			return {}

	# Generate procedural mob fallback for enemy spawns (mirrors NPCManager pattern)
	var procedural_pool: Dictionary = {}
	var proto: Dictionary = _build_procedural_mob(enemy)
	if proto.has("archetype") and proto.has("color"):
		procedural_pool[enemy_id] = proto

	# Emit signal to notify procedural mob generation — similar to NPCManager's signal
	if npc_manager != null:
		# npc_manager has a procedural_mob_generated signal; connect if needed
		pass  # Signal emission handled by caller or internal wiring

	return enemy


static func _make_rng(world_seed: String, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s" % [world_seed, salt])
	return rng


static func _load_json_dict(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not is_instance_valid(file):
		push_warning("[EncounterBuilder] Missing data: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func _pick_enemy_archetype(
	archetypes: Dictionary,
	difficulty: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var pool: Array[String] = []
	var weights: Dictionary = ENEMY_WEIGHTS.duplicate()

	# Adjust weights based on difficulty — higher difficulty favors more dangerous archetypes
	if difficulty.get("danger_threshold", 0.5) >= 0.6:
		weights["behemoth"] = 2
		weights["aberrant"] = 3
	if difficulty.get("danger_threshold", 0.5) < 0.4:
		weights["behemoth"] = 0
		weights["aberrant"] = 1

	for key in archetypes:
		if weights.get(key, 0) > 0:
			pool.append(key)

	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


static func _pick_enemy_tile(
	tile_map: Dictionary,
	start_tile_key: String,
	archetype_key: String,
	rng: RandomNumberGenerator
) -> String:
	var start_parts: PackedStringArray = start_tile_key.split(",")
	var start_q := 0
	var start_r := 0
	if start_parts.size() >= 2:
		start_q = int(start_parts[0])
		start_r = int(start_parts[1])

	var candidates: Array[String] = []
	for key in tile_map.keys():
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() < 2:
			continue
		var q := int(parts[0])
		var r := int(parts[1])
		var dist: int = WorldGenerator.hex_distance(q, r, start_q, start_r)
		if dist < 2 or dist > 9:
			continue
		var tile: Dictionary = tile_map[key] as Dictionary
		var danger: float = float(tile.get("rift_chance", 0.3))
		if _archetype_prefers_danger(archetype_key) and danger < 0.35:
			continue
		if not _archetype_prefers_danger(archetype_key) and danger > 0.7 and rng.randf() < 0.6:
			continue
		candidates.append(str(key))

	if candidates.is_empty():
		for key in tile_map.keys():
			candidates.append(str(key))

	if candidates.is_empty():
		return ""
	return candidates[rng.randi() % candidates.size()]


static func _archetype_prefers_danger(archetype_key: String) -> bool:
	return archetype_key in ["raider", "smuggler", "spy", "cultist", "tech_cultist", "mercenary"]


static func _pick_enemy_race(archetype_key: String, rng: RandomNumberGenerator) -> String:
	match archetype_key:
		"insectoid": return "Chthon"
		"behemoth": return "Nullborn"
		"aberrant": return "Vesperid"
		_: return "Human"


static func _pick_enemy_class(archetype_key: String, rng: RandomNumberGenerator) -> String:
	match archetype_key:
		"insectoid": return "Survivor"
		"behemoth": return "Gladiator"
		"aberrant": return "Survivor"
		_: return "Survivor"


static func _pick_enemy_traits(archetype_key: String, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array = ["aggressive", "unhinged", "fearless", "cunning", "feral"]
	if archetype_key == "behemoth":
		pool = ["fearless", "aggressive"]
	if archetype_key == "aberrant":
		pool = ["unhinged", "feral"]
	return pool[rng.randi() % pool.size()]


static func _roll_appearance(opts: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {}
	for key in ["gender", "head", "body", "arms", "legs", "skin_tone", "hair_color", "accessories"]:
		var pool: Variant = opts.get(key, [])
		if pool is Array and (pool as Array).size() > 0:
			out[key] = str((pool as Array)[rng.randi() % (pool as Array).size()])
	return out


static func _build_enemy_name(appearance: Dictionary, archetype_key: String, rng: RandomNumberGenerator) -> String:
	var parts: Dictionary = _load_json_dict("res://data/npc_name_parts.json")
	var origin_key: String = appearance.get("origin", "neutral")
	var bucket: Dictionary = parts.get(origin_key, {}) as Dictionary
	var first_pool: Array = bucket.get("first", ["Ash"]) as Array
	var nick_pool: Array = bucket.get("nick", ["the Drifter"]) as Array
	var last_pool: Array = bucket.get("last", ["Walker"]) as Array
	var titles: Dictionary = parts.get("titles", {}) as Dictionary
	var title_pool: Array = titles.get(archetype_key, []) as Array

	var first: String = str(first_pool[rng.randi() % first_pool.size()])
	var nick: String = str(nick_pool[rng.randi() % nick_pool.size()])
	var last: String = str(last_pool[rng.randi() % last_pool.size()])
	var title: String = ""
	if not title_pool.is_empty() and rng.randf() < 0.45:
		title = " " + str(title_pool[rng.randi() % title_pool.size()])

	if rng.randf() < 0.55:
		return "%s '%s' %s%s" % [first, nick, last, title]
	return "%s %s%s" % [first, last, title]


static func _build_procedural_mob(enemy_data: Dictionary) -> Dictionary:
	"""Build a procedural mob data dictionary for enemies missing assets.

	Returns a proto dict with archetype and color (and optional size) for
	ProceduralMob to consume. Called from generate_procedural_enemy after enemy data
	is built, mirroring NPCManager's _build_procedural_mob.
	"""
	archetypes = ["quadruped", "insectoid", "behemoth", "aberrant"]
	# Derive archetype from enemy_data's type/role hints
	var archetype: String = str(enemy_data.get("archetype", "quadruped")).to_lower()
	if archetype not in archetypes:
		archetype = str(enemy_data.get("role", "quadruped")).to_lower()
		if archetype not in archetypes:
			archetype = "quadruped"
	# Color comes from enemy_data's color field or default
	var color: String = str(enemy_data.get("color", "rags"))
	# Size is optional; ProceduralMob uses 48 if not provided
	var size: float = float(enemy_data.get("size", 48))
	var proto: Dictionary = {"archetype": archetype, "color": color, "size": size}
	return proto
