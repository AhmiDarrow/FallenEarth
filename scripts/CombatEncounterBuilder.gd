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
const MOBS_PATH := "res://data/mobs.json"
const SPRITE_DATA_PATH := "res://data/mob_sprites.json"

const GENERATION_SALT := "fallen_enemies_v1"

# Enemy archetype weights — separate from NPC archetypes
const ENEMY_WEIGHTS := {
	"quadruped": 4,
	"insectoid": 3,
	"behemoth": 1,
	"aberrant": 2,
	"floater": 2,
	"mechanical": 1,
}

# Mob sprite cache
static var _sprite_cache: Dictionary = {}
static var _sprite_cache_loaded: bool = false
static var _mob_cache: Dictionary = {}

static func generate_procedural_enemy(
	world_seed: String,
	tile_map: Dictionary,
	start_tile_key: String,
	difficulty: Dictionary,
	npc_manager: NPCManager = null,
	spawn_context: String = "upworld",
	biome: String = ""
) -> Dictionary:
	# Difficulty thresholds — adjust per world state
	var min_level: int = int(difficulty.get("min_level", 2))
	var max_level: int = int(difficulty.get("max_level", 8))

	# Load enemy archetypes — file wraps them under an "archetypes" key
	var archetypes_root: Dictionary = _load_json_dict(ENEMY_ARCHETYPES_PATH)
	var archetypes: Dictionary = archetypes_root.get("archetypes", archetypes_root)
	if archetypes.is_empty():
		archetypes = _load_json_dict(ARCHETYPES_PATH).get("archetypes", {})

	var appearance_opts: Dictionary = _load_json_dict(APPEARANCE_PATH)
	var rng := _make_rng(world_seed, GENERATION_SALT)

	# Try to pick a named mob from mobs.json filtered by spawn_context and biome
	var mob_pool: Array[Dictionary] = _get_mob_pool(spawn_context, biome)
	var chosen_mob: Dictionary = {}
	if not mob_pool.is_empty():
		chosen_mob = mob_pool[rng.randi() % mob_pool.size()]

	# Pick an archetype — prefer mob's archetype if we found a named mob
	var archetype_key: String = ""
	if chosen_mob.has("archetype"):
		archetype_key = str(chosen_mob["archetype"])
	elif chosen_mob.has("visual_preset"):
		archetype_key = _preset_to_archetype(str(chosen_mob["visual_preset"]))
	if archetype_key.is_empty():
		archetype_key = _pick_enemy_archetype(archetypes, difficulty, rng)
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
	var gender: String = ["male", "female"][rng.randi() % 2]
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

	# Use chosen mob's name if available
	if chosen_mob.has("name"):
		display_name = str(chosen_mob["name"])

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
		"biome": str(tile.get("name", biome if not biome.is_empty() else "Ash Wastes")),
		"rarity": rarity,
		"status": "spawned",
		"hostile": true,
		"aggression": archetype_def.get("aggression", 0.6),
		"health": level * 10,
		"damage": level * 2,
		"speed": level * 0.3,
		"has_procedural_assets": true,
		"spawn_context": spawn_context,
	}

	# Carry over mob-specific stats if chosen from named pool
	if chosen_mob.has("hp"):
		enemy["health"] = chosen_mob["hp"]
		enemy["base_hp"] = chosen_mob["hp"]
	if chosen_mob.has("attack_damage"):
		enemy["damage"] = chosen_mob["attack_damage"]
	if chosen_mob.has("armor"):
		enemy["armor"] = chosen_mob["armor"]
	if chosen_mob.has("drain_rate"):
		enemy["drain_rate"] = chosen_mob["drain_rate"]
	if chosen_mob.has("swarm_count_min"):
		enemy["swarm_count_min"] = chosen_mob["swarm_count_min"]
		enemy["swarm_count_max"] = chosen_mob.get("swarm_count_max", 3)
	if chosen_mob.has("is_boss"):
		enemy["is_boss"] = chosen_mob["is_boss"]
	if chosen_mob.has("rift_type"):
		enemy["rift_type"] = chosen_mob["rift_type"]

	# Assign sprite_id from mob data or derive from archetype
	if chosen_mob.has("sprite_id"):
		enemy["sprite_id"] = chosen_mob["sprite_id"]
	else:
		enemy["sprite_id"] = archetype_key

	# Apply colorshift from sprite definition if available
	var sprite_data: Dictionary = _get_sprite(enemy.get("sprite_id", ""))
	if not sprite_data.is_empty():
		var color_range: Dictionary = sprite_data.get("color_range", {})
		if not color_range.is_empty():
			enemy["color_range"] = color_range
		# Apply rift tint if in a rift
		if spawn_context == "rift" and sprite_data.has("rift_type"):
			var rift_tint: String = "rift_%s_tint" % str(sprite_data["rift_type"])
			enemy["colorshift_preset"] = rift_tint

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
	var pool: Array[String]
	match archetype_key:
		"behemoth":
			pool = ["fearless", "aggressive"]
		"aberrant":
			pool = ["unhinged", "feral"]
		_:
			pool = ["aggressive", "unhinged", "fearless", "cunning", "feral"]
	return [pool[rng.randi() % pool.size()]] as Array[String]


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
	var archetypes: Array = ["quadruped", "insectoid", "behemoth", "aberrant", "floater", "mechanical"]
	# Derive archetype from enemy_data's type/role hints
	var archetype: String = str(enemy_data.get("archetype", "quadruped")).to_lower()
	if archetype not in archetypes:
		archetype = str(enemy_data.get("role", "quadruped")).to_lower()
		if archetype not in archetypes:
			archetype = "quadruped"
	# Color comes from enemy_data's color field or default
	var color: String = str(enemy_data.get("color", "rags"))
	# Size is optional; ProceduralMob uses 48 if not provided
	var size: Vector2 = Vector2(48, 48)
	var s = enemy_data.get("size", 48)
	if s is Vector2:
		size = s
	elif s is float or s is int:
		size = Vector2(float(s), float(s))
	var proto: Dictionary = {
		"archetype": archetype,
		"color": color,
		"size": size,
		"sprite_id": enemy_data.get("sprite_id", archetype),
	}
	# Pass colorshift data if present
	if enemy_data.has("color_range"):
		proto["color_range"] = enemy_data["color_range"]
	if enemy_data.has("colorshift_preset"):
		proto["colorshift_preset"] = enemy_data["colorshift_preset"]
	return proto


# -------------------------------------------------------------------------
# Mob pool and sprite helpers
# -------------------------------------------------------------------------

static func _get_mob_pool(spawn_context: String, biome: String = "") -> Array[Dictionary]:
	"""Get named mobs from mobs.json filtered by spawn_context and optional biome."""
	if _mob_cache.is_empty():
		_load_mob_cache()
	var pool: Array[Dictionary] = []
	# Search overworld.neutral, overworld.aggressive, and rift_only
	for category in ["neutral", "aggressive"]:
		var mobs: Array = _mob_cache.get("overworld", {}).get(category, [])
		for mob in mobs:
			if mob is Dictionary:
				var ctx: String = str(mob.get("spawn_context", "upworld"))
				if ctx == spawn_context or ctx == "both":
					if _biome_matches(mob, biome):
						pool.append(mob)
	# Also check rift_only for rift context
	if spawn_context == "rift":
		var rift_mobs: Array = _mob_cache.get("rift_only", [])
		for mob in rift_mobs:
			if mob is Dictionary:
				if _biome_matches(mob, biome):
					pool.append(mob)
	return pool


static func _biome_matches(mob: Dictionary, biome: String) -> bool:
	"""Check if a mob can spawn in the given biome (if biome filter is set)."""
	if biome.is_empty():
		return true
	if not mob.has("preferred_biomes"):
		return true  # No biome preference = can spawn anywhere
	var preferred: Variant = mob["preferred_biomes"]
	if preferred is Array:
		for b in preferred:
			if str(b) == biome:
				return true
		return false
	return true


static func _load_mob_cache() -> void:
	"""Cache mobs.json data for pool filtering."""
	var file: FileAccess = FileAccess.open(MOBS_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_mob_cache = parsed.duplicate(true)


static func _get_sprite(sprite_id: String) -> Dictionary:
	"""Get a sprite definition by ID from mob_sprites.json."""
	if not _sprite_cache_loaded:
		_load_sprite_cache_static()
	return _sprite_cache.get(sprite_id, {})


static func _load_sprite_cache_static() -> void:
	var file: FileAccess = FileAccess.open(SPRITE_DATA_PATH, FileAccess.READ)
	if not file:
		_sprite_cache_loaded = true
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_sprite_cache = parsed.get("sprites", {}).duplicate(true)
	_sprite_cache_loaded = true


static func _preset_to_archetype(preset: String) -> String:
	"""Map a visual_preset name to a ProceduralMob archetype."""
	match preset:
		"beast_quadruped": return "quadruped"
		"beast_insectoid": return "insectoid"
		"beast_behemoth": return "behemoth"
		"beast_floater": return "floater"
		"mechanical_default": return "mechanical"
		"rift_void", "rift_life", "rift_energy": return "aberrant"
		_: return "quadruped"


# -------------------------------------------------------------------------
# Missing static entry points referenced by MissionManager, HubWorld, RiftInstance, TacticalCombat, MissionGenerator.
# These produce encounter payloads compatible with CombatManager / GameState / TacticalCombat.
# -------------------------------------------------------------------------

const SOURCE_OVERWORLD := "overworld"
const SOURCE_RIFT := "rift"
const SOURCE_MISSION := "mission"

static func random_overworld_mob(biome: String = "Ash Wastes", prefer_hostile: bool = true) -> Dictionary:
	# Use the existing generator for a procedural enemy/mob as "overworld mob"
	var world_seed := "owm_" + str(Time.get_unix_time_from_system())
	var dummy_tile_map := {
		"0,0": {"name": biome, "rift_chance": 0.4}
	}
	var difficulty := {"min_level": 1, "max_level": 4, "danger_threshold": 0.5}
	var enemy := generate_procedural_enemy(world_seed, dummy_tile_map, "0,0", difficulty, null, "upworld", biome)
	if enemy.is_empty():
		enemy = {
			"id": "mob_fallback_" + str(randi() % 1000),
			"name": "Wild " + (["Beast", "Scavenger", "Aberration"][randi() % 3]),
			"archetype": "quadruped",
			"level": 2,
			"hostile": prefer_hostile,
			"health": 18,
			"damage": 3,
			"speed": 0.4,
			"has_procedural_assets": true,
			"biome": biome,
			"spawn_context": "upworld",
			"sprite_id": "quadruped"
		}
	return enemy

static func build_overworld(char_data: Dictionary, mob: Dictionary, tile_key: String, biome: String) -> Dictionary:
	var enemies: Array = []
	if not mob.is_empty():
		enemies.append(mob)
	return {
		"character_data": char_data.duplicate(true) if char_data else {},
		"enemy_templates": enemies,
		"source": SOURCE_OVERWORLD,
		"tile_key": tile_key,
		"biome": biome,
		"grid_size": 7,
		"player_start": Vector2i(3, 5),
		"height_seed": abs(tile_key.hash()),
		"class_combat": {}
	}

static func build_mission(
	character_data: Dictionary,
	mob: Dictionary,
	tile_key: String,
	biome: String,
	mission: Dictionary = {}
) -> Dictionary:
	var enc := build_overworld(character_data, mob, tile_key, biome)
	enc["source"] = SOURCE_MISSION
	enc["mission"] = mission.duplicate(true) if mission else {}
	enc["return_context"] = {"mission_id": mission.get("id", "")}
	return enc

static func build_rift_room(
	char_data: Dictionary,
	biome: String,
	rift_id: String,
	q: int, r: int,
	encounter_type: String,
	tile_key: String,
	lx: int = -1,
	ly: int = -1
) -> Dictionary:
	var diff := {"min_level": 2, "max_level": 7, "danger_threshold": 0.85}
	# Boss encounters use higher difficulty
	if encounter_type == "boss":
		diff["danger_threshold"] = 0.95
		diff["max_level"] = 10
	var tm := {}
	tm[tile_key] = {"name": biome, "rift_chance": 0.95}
	var enemy := generate_procedural_enemy("rift_" + rift_id, tm, tile_key, diff, null, "rift", biome)
	# For boss rooms, mark as boss if the mob isn't already
	if encounter_type == "boss" and not enemy.is_empty() and not enemy.get("is_boss", false):
		enemy["is_boss"] = true
	var enc := build_overworld(char_data, enemy if not enemy.is_empty() else {}, tile_key, biome)
	enc["source"] = SOURCE_RIFT
	enc["rift_id"] = rift_id
	enc["encounter_type"] = encounter_type
	enc["entry"] = {"q": q, "r": r, "local_x": lx, "local_y": ly}
	enc["return_context"] = {"rift_id": rift_id, "encounter_type": encounter_type}
	return enc
