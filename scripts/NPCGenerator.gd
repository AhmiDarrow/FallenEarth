## NPCGenerator — Deterministic procedural NPC roster for each world seed.
class_name NPCGenerator
extends RefCounted

const ARCHETYPES_PATH := "res://data/npc_archetypes.json"
const NAME_PARTS_PATH := "res://data/npc_name_parts.json"
const FACTIONS_PATH := "res://data/factions.json"
const APPEARANCE_PATH := "res://data/appearance.json"

const GENERATION_SALT := "fallen_npcs_v1"
const WANDERER_COUNT := 4

const STAT_KEYS := ["str", "dex", "con", "int", "wis", "cha"]
const GENDERS := ["male", "female"]

const VENDOR_TEMPLATES := {
	"weapons": ["Rustblade", "Scrap Pike", "Reinforced Baton", "Salvaged Rifle"],
	"tech_parts": ["Capacitor Coil", "Drone Core", "Pulse Cell", "Servo Arm"],
	"ritual_goods": ["Void Candle", "Bone Charm", "Rift Ash", "Echo Relic"],
	"herbs_and_charms": ["Spore Salve", "Ashroot Tonic", "Veil Charm", "Mire Moss"],
	"contraband": ["Black Route Map", "Smuggled Cells", "Stolen Cores", "Forged Papers"],
	"lore_scrolls": ["Pre-Fall Journal", "Faction Ledger", "Rift Survey", "Echo Fragment"],
	"cybernetics": ["Chrome Graft", "Neural Lace", "Optic Implant", "Servo Hand"],
	"supplies": ["Med-Gel Pack", "Ration Brick", "Filter Mask", "Water Cell"],
	"general_goods": ["Scrap Bundle", "Patch Kit", "Travel Rations", "Tool Crate"],
	"intel": ["Faction Rumor", "Route Intel", "Hidden Cache Map", "Threat Report"],
}

static func generate_world_roster(
	world_seed: String,
	tile_map: Dictionary,
	start_tile_key: String,
	factions: Array = []
) -> Dictionary:
	var rng := _make_rng(world_seed, GENERATION_SALT)
	var archetypes: Dictionary = _load_json_dict(ARCHETYPES_PATH)
	var name_parts: Dictionary = _load_json_dict(NAME_PARTS_PATH)
	var appearance_opts: Dictionary = _load_json_dict(APPEARANCE_PATH)

	if factions.is_empty():
		factions = _load_factions_array()

	var roster: Dictionary = {}
	var used_tiles: Dictionary = {}
	var npc_index := 0

	for faction_entry in factions:
		if not faction_entry is Dictionary:
			continue
		var faction: Dictionary = faction_entry as Dictionary
		var faction_name: String = str(faction.get("name", "Unknown"))
		var faction_key: String = _slugify(faction_name)
		var origin_key: String = str(faction.get("origin_key", "independent"))
		var npc_types: Array = faction.get("npc_types", []) as Array
		if npc_types.is_empty():
			continue

		var count: int = 1 + rng.randi_range(0, 1)
		for _i in range(count):
			var archetype_key: String = str(npc_types[rng.randi() % npc_types.size()])
			var npc: Dictionary = _build_npc(
				rng, npc_index, archetype_key, faction_name, faction_key, origin_key,
				tile_map, start_tile_key, used_tiles, archetypes, name_parts, appearance_opts
			)
			if npc.is_empty():
				continue
			roster[npc["id"]] = npc
			used_tiles[npc["tile_key"]] = true
			npc_index += 1

	for _w in range(WANDERER_COUNT):
		var wanderer: Dictionary = _build_npc(
			rng, npc_index, "wanderer", "Independent", "independent", "neutral",
			tile_map, start_tile_key, used_tiles, archetypes, name_parts, appearance_opts
		)
		if wanderer.is_empty():
			continue
		roster[wanderer["id"]] = wanderer
		used_tiles[wanderer["tile_key"]] = true
		npc_index += 1

	return roster


static func _build_npc(
	rng: RandomNumberGenerator,
	index: int,
	archetype_key: String,
	faction_name: String,
	faction_key: String,
	origin_key: String,
	tile_map: Dictionary,
	start_tile_key: String,
	used_tiles: Dictionary,
	archetypes: Dictionary,
	name_parts: Dictionary,
	appearance_opts: Dictionary
) -> Dictionary:
	var archetype: Dictionary = archetypes.get(archetype_key, {}) as Dictionary
	if archetype.is_empty():
		archetype = archetypes.get("wanderer", {}) as Dictionary
		archetype_key = "wanderer"

	var race_origin: String = _race_origin_for_faction(origin_key, rng)
	var race_id: String = _pick_race(race_origin, rng)
	var class_id: String = _pick_class(archetype, rng)
	var gender: String = GENDERS[rng.randi() % GENDERS.size()]
	var traits: Array[String] = _pick_traits(archetype, rng)
	var tile_key: String = _pick_tile(tile_map, start_tile_key, used_tiles, archetype_key, rng)
	if tile_key.is_empty():
		return {}

	var tile: Dictionary = tile_map.get(tile_key, {}) as Dictionary
	var level: int = clampi(1 + rng.randi_range(0, 4), 1, 8)
	var stats: Dictionary = _roll_stats(race_id, class_id, level, rng)
	var appearance: Dictionary = _roll_appearance(appearance_opts, rng)
	var vendor: Dictionary = _roll_vendor(archetype, rng)
	var recruitment: Dictionary = {
		"rep_required": int(archetype.get("rep_required", 15)),
		"level_required": int(archetype.get("level_required", 1)),
	}

	var npc_id := "npc_%s_%03d" % [faction_key.left(6), index]
	var display_name: String = _build_name(name_parts, race_origin if race_origin != "" else "neutral", archetype_key, rng)

	return {
		"id": npc_id,
		"name": display_name,
		"race": race_id,
		"gender": gender,
		"origin": race_origin if race_origin != "" else "neutral",
		"class": class_id,
		"archetype": archetype_key,
		"role": str(archetype.get("display_role", archetype_key.capitalize())),
		"faction": faction_name,
		"faction_key": faction_key,
		"traits": traits,
		"personality_summary": _personality_summary(traits, str(archetype.get("display_role", "traveler"))),
		"level": level,
		"stats": stats,
		"appearance": appearance,
		"tile_key": tile_key,
		"biome": str(tile.get("name", "Ash Wastes")),
		"recruitment": recruitment,
		"vendor": vendor,
		"rarity": str(archetype.get("rarity", "common")),
		"status": "available",
		"recruited": false,
	}


static func _make_rng(world_seed: String, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s" % [world_seed, salt])
	return rng


static func _load_json_dict(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not is_instance_valid(file):
		push_warning("[NPCGenerator] Missing data: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func _load_factions_array() -> Array:
	var file: FileAccess = FileAccess.open(FACTIONS_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Array else []


static func _slugify(name: String) -> String:
	return name.to_lower().replace(" ", "_").replace("'", "")


static func _race_origin_for_faction(origin_key: String, rng: RandomNumberGenerator) -> String:
	match origin_key:
		"upworld":
			return "upworld"
		"underworld":
			return "underworld"
		"neutral":
			return "neutral"
		_:
			return ["upworld", "underworld", "neutral"][rng.randi() % 3]


static func _pick_race(origin: String, rng: RandomNumberGenerator) -> String:
	var rm: RaceManager = Engine.get_main_loop().root.get_node_or_null("/root/RaceManager") as RaceManager
	if is_instance_valid(rm):
		var pool: Array[String] = []
		if origin == "neutral":
			for o in ["upworld", "underworld"]:
				for race_entry in rm.get_all_races().get(o, []):
					if race_entry is Dictionary:
						pool.append(str((race_entry as Dictionary).get("id", "")))
		else:
			for race_entry in rm.get_all_races().get(origin, []):
				if race_entry is Dictionary:
					pool.append(str((race_entry as Dictionary).get("id", "")))
		if not pool.is_empty():
			return pool[rng.randi() % pool.size()]

	var fallback_up := ["Human", "Mutant", "Cyborg", "SentientAI"]
	var fallback_under := ["Chthon", "Vesperid", "Nullborn", "Revenant"]
	match origin:
		"underworld":
			return fallback_under[rng.randi() % fallback_under.size()]
		"neutral":
			var merged: Array = fallback_up + fallback_under
			return str(merged[rng.randi() % merged.size()])
		_:
			return fallback_up[rng.randi() % fallback_up.size()]


static func _pick_class(archetype: Dictionary, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = archetype.get("class_weights", {}) as Dictionary
	if weights.is_empty():
		return "Survivor"
	var total := 0
	for k in weights:
		total += int(weights[k])
	if total <= 0:
		return "Survivor"
	var roll := rng.randi_range(1, total)
	var acc := 0
	for k in weights:
		acc += int(weights[k])
		if roll <= acc:
			return str(k)
	return "Survivor"


static func _pick_traits(archetype: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array = archetype.get("trait_pool", []) as Array
	if pool.is_empty():
		return ["restless"]
	var picked: Array[String] = []
	var count: int = mini(3, pool.size())
	while picked.size() < count:
		var trait_name: String = str(pool[rng.randi() % pool.size()])
		if trait_name not in picked:
			picked.append(trait_name)
	return picked


static func _pick_tile(
	tile_map: Dictionary,
	start_tile_key: String,
	used_tiles: Dictionary,
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
		if used_tiles.has(key):
			continue
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
			if not used_tiles.has(key):
				candidates.append(str(key))

	if candidates.is_empty():
		return ""
	return candidates[rng.randi() % candidates.size()]


static func _archetype_prefers_danger(archetype_key: String) -> bool:
	return archetype_key in ["raider", "smuggler", "spy", "cultist", "tech_cultist", "mercenary"]


static func _roll_stats(race_id: String, class_id: String, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var base: Dictionary = {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}
	var rm: RaceManager = Engine.get_main_loop().root.get_node_or_null("/root/RaceManager") as RaceManager
	if is_instance_valid(rm):
		var race_data: Dictionary = rm.get_race_by_id(race_id)
		if not race_data.is_empty():
			base = race_data.get("base_stats", base).duplicate(true)

	var cm: ClassManager = Engine.get_main_loop().root.get_node_or_null("/root/ClassManager") as ClassManager
	if is_instance_valid(cm):
		var cls: Dictionary = cm.get_class_by_id(class_id)
		var mods: Dictionary = cls.get("stat_mods", {})
		for stat in STAT_KEYS:
			base[stat] = int(base.get(stat, 10)) + int(mods.get(stat, 0))

	for stat in STAT_KEYS:
		base[stat] = clampi(int(base.get(stat, 10)) + rng.randi_range(-1, 1), 6, 18)

	if is_instance_valid(cm):
		return cm.get_stats_at_level(class_id, level, base)
	return base


static func _roll_appearance(opts: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {}
	for key in ["gender", "head", "body", "arms", "legs", "skin_tone", "hair_color", "accessories"]:
		var pool: Variant = opts.get(key, [])
		if pool is Array and (pool as Array).size() > 0:
			out[key] = str((pool as Array)[rng.randi() % (pool as Array).size()])
	return out


static func _roll_vendor(archetype: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var specialty: String = str(archetype.get("vendor_specialty", "general_goods"))
	var templates: Array = VENDOR_TEMPLATES.get(specialty, VENDOR_TEMPLATES["general_goods"])
	var stock: Array[Dictionary] = []
	var count: int = 2 + rng.randi_range(0, 2)
	for i in range(count):
		var base_name: String = str(templates[rng.randi() % templates.size()])
		stock.append({
			"id": "stock_%d_%d" % [rng.randi(), i],
			"name": "%s Mk.%d" % [base_name, 1 + rng.randi_range(0, 3)],
			"specialty": specialty,
			"price_scrap": 10 + rng.randi_range(0, 40),
			"tier": 1 + rng.randi_range(0, 2),
		})
	return {"specialty": specialty, "stock": stock}


static func _build_name(parts: Dictionary, origin: String, archetype_key: String, rng: RandomNumberGenerator) -> String:
	var origin_key: String = origin if parts.has(origin) else "neutral"
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


static func _build_procedural_mob(npc_data: Dictionary) -> Dictionary:
	var archetype: String = str(npc_data.get("archetype", "quadruped"))
	var color: String = str(npc_data.get("appearance", {}).get("hair_color", "rags"))
	var size: Vector2 = Vector2(48, 48)

	return {
		"archetype": archetype,
		"color": color,
		"size": size,
		"has_procedural_assets": true,
	}

static func _personality_summary(traits: Array[String], role: String) -> String:
	if traits.is_empty():
		return "A %s with an unreadable past." % role.to_lower()
	var joined := ", ".join(traits)
	return "A %s known for being %s." % [role.to_lower(), joined]