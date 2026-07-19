## EncounterBuilder — Procedural enemy (mob) generation for overworld and rift encounters.
## Constructs hostile mobs matching EncounterDifficulty thresholds.
## Fully independent of NPC system — mobs are enemies only.

class_name EncounterBuilder
extends RefCounted
const WorldGenerator = preload("res://scripts/WorldGenerator.gd")

const ENEMY_ARCHETYPES_PATH := "res://data/enemy_archetypes.json"
const APPEARANCE_PATH := "res://data/appearance.json"
const MOBS_PATH := "res://data/mobs.json"
const SPRITE_DATA_PATH := "res://data/mob_sprites.json"

const GENERATION_SALT := "fallen_enemies_v1"

const ENEMY_WEIGHTS := {
	"quadruped": 4,
	"insectoid": 3,
	"behemoth": 1,
	"aberrant": 2,
	"floater": 2,
	"mechanical": 1,
}

static var _sprite_cache: Dictionary = {}
static var _sprite_cache_loaded: bool = false
static var _mob_cache: Dictionary = {}
static var _json_dict_cache: Dictionary = {}
static var _biomes_cache: Dictionary = {}


static func generate_procedural_enemy(
	world_seed: String,
	tile_map: Dictionary,
	start_tile_key: String,
	difficulty: Dictionary,
	spawn_context: String = "upworld",
	biome: String = ""
) -> Dictionary:
	var min_level: int = int(difficulty.get("min_level", 2))
	var max_level: int = int(difficulty.get("max_level", 8))

	var archetypes_root: Dictionary = _load_json_dict(ENEMY_ARCHETYPES_PATH)
	var archetypes: Dictionary = archetypes_root.get("archetypes", {})

	var appearance_opts: Dictionary = _load_json_dict(APPEARANCE_PATH)
	var rng := _make_rng(world_seed, GENERATION_SALT)

	var mob_pool: Array[Dictionary] = _get_mob_pool(spawn_context, biome)
	var chosen_mob: Dictionary = {}
	if not mob_pool.is_empty():
		chosen_mob = mob_pool[rng.randi() % mob_pool.size()]

	var archetype_key: String = ""
	if chosen_mob.has("visual_preset"):
		archetype_key = _preset_to_archetype(str(chosen_mob["visual_preset"]))
	if archetype_key.is_empty():
		archetype_key = _pick_enemy_archetype(archetypes, difficulty, rng)
	if archetype_key.is_empty():
		return {}

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

	var enemy_id := "enemy_%s_%03d" % [tile_key.left(6), rng.randi() % 1000]
	var display_name: String = _build_enemy_name(appearance, archetype_key, rng)

	if chosen_mob.has("name"):
		display_name = str(chosen_mob["name"])

	var base_hp: int = level * 10
	var base_damage: int = level * 2
	var base_armor: int = 0

	if chosen_mob.has("hp"):
		base_hp = int(chosen_mob["hp"])
	if chosen_mob.has("attack_damage"):
		base_damage = int(chosen_mob["attack_damage"])
	if chosen_mob.has("armor"):
		base_armor = int(chosen_mob["armor"])

	# Apply biome threat_multiplier to stats (scales with danger)
	var threat_mult: float = 1.0
	if not tile.is_empty():
		threat_mult = float(tile.get("wildlife_modifiers", {}).get("threat_multiplier", 1.0))
	if threat_mult != 1.0:
		base_hp = int(base_hp * threat_mult)
		base_damage = int(base_damage * threat_mult)
		base_armor = int(base_armor * threat_mult)

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
		"hp": base_hp,
		"max_hp": base_hp,
		"health": base_hp,
		"attack_damage": base_damage,
		"damage": base_damage,
		"armor": base_armor,
		"speed": level * 0.3,
		"has_procedural_assets": true,
		"spawn_context": spawn_context,
	}

	if chosen_mob.has("drain_rate"):
		enemy["drain_rate"] = chosen_mob["drain_rate"]
	if chosen_mob.has("swarm_count_min"):
		enemy["swarm_count_min"] = chosen_mob["swarm_count_min"]
		enemy["swarm_count_max"] = chosen_mob.get("swarm_count_max", 3)
	if chosen_mob.has("is_boss"):
		enemy["is_boss"] = chosen_mob["is_boss"]
	if chosen_mob.has("rift_type"):
		enemy["rift_type"] = chosen_mob["rift_type"]

	if chosen_mob.has("sprite_id"):
		enemy["sprite_id"] = chosen_mob["sprite_id"]
	else:
		enemy["sprite_id"] = archetype_key

	var sprite_data: Dictionary = _get_sprite(enemy.get("sprite_id", ""))
	if not sprite_data.is_empty():
		var color_range: Dictionary = sprite_data.get("color_range", {})
		if not color_range.is_empty():
			enemy["color_range"] = color_range
		if spawn_context == "rift" and sprite_data.has("rift_type"):
			var rift_tint: String = "rift_%s_tint" % str(sprite_data["rift_type"])
			enemy["colorshift_preset"] = rift_tint

	return enemy


static func _make_rng(world_seed: String, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s" % [world_seed, salt])
	return rng


static func _load_json_dict(path: String) -> Dictionary:
	if _json_dict_cache.has(path):
		return _json_dict_cache[path]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not is_instance_valid(file):
		push_warning("[EncounterBuilder] Missing data: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var result: Dictionary = parsed if parsed is Dictionary else {}
	_json_dict_cache[path] = result
	return result


static func _pick_enemy_archetype(
	archetypes: Dictionary,
	difficulty: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var pool: Array[String] = []
	var weights: Dictionary = ENEMY_WEIGHTS.duplicate()

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


static func _pick_enemy_race(archetype_key: String, _rng: RandomNumberGenerator) -> String:
	match archetype_key:
		"insectoid": return "Chthon"
		"behemoth": return "Nullborn"
		"aberrant": return "Vesperid"
		_: return "Human"


static func _pick_enemy_class(archetype_key: String, _rng: RandomNumberGenerator) -> String:
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


# -------------------------------------------------------------------------
# Mob pool and sprite helpers
# -------------------------------------------------------------------------

static func _get_mob_pool(spawn_context: String, biome: String = "") -> Array[Dictionary]:
	if _mob_cache.is_empty():
		_load_mob_cache()
	var pool: Array[Dictionary] = []
	for category in ["neutral", "aggressive"]:
		var mobs: Array = _mob_cache.get("overworld", {}).get(category, [])
		for mob in mobs:
			if mob is Dictionary:
				var ctx: String = str(mob.get("spawn_context", "upworld"))
				if ctx == spawn_context or ctx == "both":
					if _biome_matches(mob, biome):
						pool.append(mob)
	if spawn_context == "rift":
		var rift_mobs: Array = _mob_cache.get("rift_only", [])
		for mob in rift_mobs:
			if mob is Dictionary:
				if _biome_matches(mob, biome):
					pool.append(mob)
	return pool


static func _biome_matches(mob: Dictionary, biome: String) -> bool:
	if biome.is_empty():
		return true
	if not mob.has("preferred_biomes"):
		return true
	var preferred: Variant = mob["preferred_biomes"]
	if preferred is Array:
		for b in preferred:
			if str(b) == biome:
				return true
		return false
	return true


static func _load_mob_cache() -> void:
	var file: FileAccess = FileAccess.open(MOBS_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_mob_cache = parsed.duplicate(true)


static func _get_sprite(sprite_id: String) -> Dictionary:
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
	match preset:
		"beast_quadruped": return "quadruped"
		"beast_insectoid": return "insectoid"
		"beast_behemoth": return "behemoth"
		"beast_floater": return "floater"
		"mechanical_default": return "mechanical"
		"rift_void", "rift_life", "rift_energy": return "aberrant"
		_: return "quadruped"


# -------------------------------------------------------------------------
# Encounter payloads — consumed by CombatManager / TacticalCombat / GameState
# -------------------------------------------------------------------------

const SOURCE_OVERWORLD := "overworld"
const SOURCE_RIFT := "rift"
const SOURCE_MISSION := "mission"

static func random_overworld_mob(biome: String = "Ash Wastes", prefer_hostile: bool = true) -> Dictionary:
	var world_seed := "owm_" + str(Time.get_unix_time_from_system())
	var dummy_tile_map := {
		"0,0": {"name": biome, "rift_chance": 0.4}
	}
	var difficulty := {"min_level": 1, "max_level": 4, "danger_threshold": 0.5}
	var enemy := generate_procedural_enemy(world_seed, dummy_tile_map, "0,0", difficulty, "upworld", biome)
	if enemy.is_empty():
		enemy = {
			"id": "mob_fallback_" + str(randi() % 1000),
			"name": "Wild " + (["Beast", "Scavenger", "Aberration"][randi() % 3]),
			"archetype": "quadruped",
			"level": 2,
			"hostile": prefer_hostile,
			"hp": 18,
			"max_hp": 18,
			"health": 18,
			"attack_damage": 3,
			"damage": 3,
			"armor": 0,
			"speed": 0.4,
			"has_procedural_assets": true,
			"biome": biome,
			"spawn_context": "upworld",
			"sprite_id": "quadruped"
		}
	return enemy

static func build_overworld(char_data: Dictionary, mob: Dictionary, tile_key: String, biome: String, equip_stats: Dictionary = {}) -> Dictionary:
	var enemies: Array = []
	if not mob.is_empty():
		enemies.append(mob)
	# Inject equipment-derived attack/defense into char_data if the caller
	# provided equip_stats from EquipmentManager.get_combat_stats("player").
	# This ensures combat reads real gear stats, not just base character values.
	var equip_data: Dictionary = char_data.duplicate(true) if char_data else {}
	if not equip_stats.is_empty():
		if not equip_data.has("attack") or int(equip_data.get("attack", 0)) == 0:
			equip_data["attack"] = int(equip_stats.get("attack", 0))
		if not equip_data.has("defense") or int(equip_data.get("defense", 0)) == 0:
			equip_data["defense"] = int(equip_stats.get("defense", 0))
	return {
		"character_data": equip_data,
		"enemy_templates": enemies,
		"source": SOURCE_OVERWORLD,
		"tile_key": tile_key,
		"biome": biome,
		"grid_size": 20,
		"player_start": Vector2i(3, 5),
		"height_seed": abs(tile_key.hash()),
		"class_combat": {},
		"return_context": {
			"remove_mob_on_victory": true,
			"tile_key": tile_key,
		},
	}

static func build_mission(
	character_data: Dictionary,
	mob: Dictionary,
	tile_key: String,
	biome: String,
	mission: Dictionary = {},
	equip_stats: Dictionary = {}
) -> Dictionary:
	var enc := build_overworld(character_data, mob, tile_key, biome, equip_stats)
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
	ly: int = -1,
	equip_stats: Dictionary = {}
) -> Dictionary:
	# Look up biome level_range and wildlife_modifiers from biomes.json
	var biome_level_range: Dictionary = {"min_level": 2, "max_level": 7}
	var wildlife_mods: Dictionary = {}
	if _biomes_cache.has(biome):
		var cached: Dictionary = _biomes_cache[biome]
		biome_level_range = cached.get("level_range", biome_level_range)
		wildlife_mods = cached.get("wildlife_modifiers", {})
	elif not _biomes_cache.has("_loaded"):
		var biomes_file: FileAccess = FileAccess.open("res://data/biomes.json", FileAccess.READ)
		if biomes_file:
			var biomes_parsed: Variant = JSON.parse_string(biomes_file.get_as_text())
			biomes_file.close()
			if biomes_parsed is Array:
				for b in biomes_parsed:
					if b is Dictionary:
						_biomes_cache[str(b.get("name", ""))] = b
				_biomes_cache["_loaded"] = true
				if _biomes_cache.has(biome):
					var cached2: Dictionary = _biomes_cache[biome]
					biome_level_range = cached2.get("level_range", biome_level_range)
					wildlife_mods = cached2.get("wildlife_modifiers", {})
	var diff := {"min_level": int(biome_level_range.get("min_level", 2)), "max_level": int(biome_level_range.get("max_level", 7)), "danger_threshold": 0.85}
	if encounter_type == "boss":
		diff["danger_threshold"] = 0.95
		diff["max_level"] = int(biome_level_range.get("max_level", 7)) + 3
	var tm := {}
	tm[tile_key] = {"name": biome, "rift_chance": 0.95, "wildlife_modifiers": wildlife_mods}
	var enemy := generate_procedural_enemy("rift_" + rift_id, tm, tile_key, diff, "rift", biome)
	if encounter_type == "boss" and not enemy.is_empty() and not enemy.get("is_boss", false):
		enemy["is_boss"] = true
	var enc := build_overworld(char_data, enemy if not enemy.is_empty() else {}, tile_key, biome, equip_stats)
	enc["source"] = SOURCE_RIFT
	enc["rift_id"] = rift_id
	enc["encounter_type"] = encounter_type
	enc["entry"] = {"q": q, "r": r, "local_x": lx, "local_y": ly}
	enc["return_context"] = {"rift_id": rift_id, "encounter_type": encounter_type}
	return enc
