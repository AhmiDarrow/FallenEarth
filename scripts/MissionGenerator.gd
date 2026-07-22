## MissionGenerator — Procedural mission instances scaled to party average level.
class_name MissionGenerator
extends RefCounted

const TEMPLATES_PATH := "res://data/mission_templates.json"
const WorldGenerator = preload("res://scripts/WorldGenerator.gd")
const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const Difficulty = preload("res://scripts/EncounterDifficulty.gd")
const ClassProg = preload("res://scripts/ClassProgression.gd")

const GENERATION_SALT := "fallen_missions_v1"


static func generate_offer(
	world_seed: String,
	party_avg_level: int,
	tile_map: Dictionary,
	player_q: int,
	player_r: int,
	offer_index: int = 0,
	faction_key: String = "independent",
	giver_npc_id: String = ""
) -> Dictionary:
	var config: Dictionary = _load_config()
	if config.is_empty():
		return {}

	var templates: Array = config.get("templates", []) as Array
	if templates.is_empty():
		return {}

	var scaling: Dictionary = config.get("scaling", {}) as Dictionary
	var lvl: int = ClassProg.clamp_level(party_avg_level)
	var tier: String = Difficulty.difficulty_tier_for_level(lvl)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d|%s|%s" % [world_seed, GENERATION_SALT, lvl, faction_key, giver_npc_id]) + offer_index

	var eligible: Array[Dictionary] = []
	for entry in templates:
		if not entry is Dictionary:
			continue
		var tpl: Dictionary = entry as Dictionary
		if lvl < int(tpl.get("min_party_level", 1)):
			continue
		eligible.append(tpl)
	if eligible.is_empty():
		eligible.append((templates[0] as Dictionary).duplicate(true))

	var template: Dictionary = _pick_weighted(eligible, rng)
	var target: Dictionary = _pick_target_tile(tile_map, player_q, player_r, lvl, scaling, rng)
	if target.is_empty():
		return {}

	var objective_type: String = str(template.get("objective_type", "reach_tile"))
	var biome: String = str(target.get("name", "Ash Wastes"))
	var tile_key: String = str(target.get("key", "0,0"))
	var parts: PackedStringArray = tile_key.split(",")
	var tq: int = int(parts[0]) if parts.size() >= 1 else 0
	var tr: int = int(parts[1]) if parts.size() >= 2 else 0

	var mob: Dictionary = {}
	if bool(template.get("spawn_mob", false)) or objective_type in ["kill_mob", "win_combat_at_tile"]:
		mob = EncounterBuilder.random_overworld_mob(biome, objective_type != "win_combat_at_tile")

	var kill_target: int = _scaled_kill_target(template, lvl, scaling)
	var difficulty_mult: float = float(template.get("base_difficulty", 1.0))
	difficulty_mult += _tier_index(tier) * float(scaling.get("difficulty_mult_per_tier", 0.12))

	var rewards: Dictionary = _build_rewards(template, lvl, scaling, biome)
	var mission_id: String = "mission_%s_%04d" % [str(template.get("id", "job")), rng.randi() % 10000]

	var objective: Dictionary = {
		"type": objective_type,
		"target_tile_key": tile_key,
		"target_biome": biome,
		"target_q": tq,
		"target_r": tr,
		"progress": 0,
		"target_count": kill_target if objective_type == "kill_count" else 1,
		"mob_name": str(mob.get("name", "")),
		"mob_template": mob,
		"rift_id": "",
	}

	if objective_type == "clear_quest_rift":
		objective["rift_id"] = "quest_%s" % mission_id

	var title: String = _build_title(config, template, mob, biome, faction_key, rng)
	var briefing: String = _build_briefing(template, objective, kill_target)

	return {
		"mission_id": mission_id,
		"template_id": str(template.get("id", "job")),
		"display_name": str(template.get("display_name", "Mission")),
		"title": title,
		"briefing": briefing,
		"faction_key": faction_key,
		"giver_npc_id": giver_npc_id,
		"status": "offered",
		"party_avg_level": lvl,
		"difficulty_tier": tier,
		"difficulty_mult": difficulty_mult,
		"objective": objective,
		"rewards": rewards,
		"expires_at": 0.0,
		"accepted_at": 0.0,
		"completed_at": 0.0,
		"seed": "%s:%d" % [world_seed, offer_index],
	}


static func _build_rewards(
	template: Dictionary,
	party_level: int,
	scaling: Dictionary,
	biome: String
) -> Dictionary:
	var xp: int = int(scaling.get("xp_base", 35)) + party_level * int(scaling.get("xp_per_level", 7))
	var rep: int = int(scaling.get("rep_base", 4)) + party_level * int(scaling.get("rep_per_level", 1))
	var loot: int = int(scaling.get("loot_base", 1)) + int(party_level / float(int(scaling.get("loot_every_n_levels", 12))))
	if str(template.get("objective_type", "")) == "clear_quest_rift":
		xp = int(xp * 1.35)
		loot += 1
	return {
		"xp": xp,
		"faction_rep": rep,
		"loot_count": clampi(loot, 1, 5),
		"biome_key": biome,
	}


static func _scaled_kill_target(template: Dictionary, party_level: int, _scaling: Dictionary) -> int:
	var base: int = int(template.get("kill_target_base", 2))
	var per_lvl: int = int(template.get("kill_per_level", 12))
	if per_lvl <= 0:
		return base
	return clampi(base + party_level / per_lvl, 2, 8)


static func _pick_target_tile(
	tile_map: Dictionary,
	player_q: int,
	player_r: int,
	party_level: int,
	scaling: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	if tile_map.is_empty():
		return {}

	var min_dist: int = int(scaling.get("distance_min_hex", 2))
	var max_dist: int = int(scaling.get("distance_max_hex_base", 4)) + int(float(party_level) * float(scaling.get("distance_per_level", 0.06)))
	max_dist = clampi(max_dist, min_dist + 1, 12)

	var candidates: Array[Dictionary] = []
	for key in tile_map.keys():
		var tile: Dictionary = (tile_map[key] as Dictionary).duplicate(true)
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() < 2:
			continue
		var q: int = int(parts[0])
		var r: int = int(parts[1])
		var dist: int = WorldGenerator.graph_distance(key, "%d,%d" % [player_q, player_r])
		if dist < min_dist or dist > max_dist:
			continue
		tile["key"] = str(key)
		tile["q"] = q
		tile["r"] = r
		tile["_dist"] = dist
		candidates.append(tile)

	if candidates.is_empty():
		for key in tile_map.keys():
			var tile: Dictionary = (tile_map[key] as Dictionary).duplicate(true)
			var parts: PackedStringArray = str(key).split(",")
			if parts.size() < 2:
				continue
			var q: int = int(parts[0])
			var r: int = int(parts[1])
			if WorldGenerator.graph_distance(key, "%d,%d" % [player_q, player_r]) < 1:
				continue
			tile["key"] = str(key)
			tile["q"] = q
			tile["r"] = r
			candidates.append(tile)

	if candidates.is_empty():
		return {}

	return candidates[rng.randi() % candidates.size()].duplicate(true)


static func _pick_weighted(pool: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for entry in pool:
		total += int(entry.get("weight", 1))
	if total <= 0:
		return pool[0].duplicate(true)
	var roll: int = rng.randi_range(1, total)
	var acc: int = 0
	for entry in pool:
		acc += int(entry.get("weight", 1))
		if roll <= acc:
			return entry.duplicate(true)
	return pool[0].duplicate(true)


static func _build_title(
	config: Dictionary,
	template: Dictionary,
	mob: Dictionary,
	biome: String,
	faction_key: String,
	rng: RandomNumberGenerator
) -> String:
	var prefixes: Array = config.get("title_prefixes", ["Contract"]) as Array
	var prefix: String = str(prefixes[rng.randi() % prefixes.size()]) if not prefixes.is_empty() else "Contract"
	var display: String = str(template.get("display_name", "Mission"))
	var mob_name: String = str(mob.get("name", ""))
	if not mob_name.is_empty() and str(template.get("objective_type", "")) in ["kill_mob", "win_combat_at_tile"]:
		return "%s: %s (%s)" % [prefix, display, mob_name]
	return "%s: %s — %s" % [prefix, display, biome]


static func _build_briefing(template: Dictionary, objective: Dictionary, kill_count: int) -> String:
	var text: String = str(template.get("briefing", "Complete the objective."))
	text = text.replace("{biome}", str(objective.get("target_biome", "the wastes")))
	text = text.replace("{q}", str(objective.get("target_q", 0)))
	text = text.replace("{r}", str(objective.get("target_r", 0)))
	text = text.replace("{count}", str(kill_count))
	text = text.replace("{mob}", str(objective.get("mob_name", "hostile")))
	return text


static func _tier_index(tier: String) -> int:
	match tier:
		"trained":
			return 1
		"seasoned":
			return 2
		"veteran":
			return 3
		"elite":
			return 4
		"nightmare":
			return 5
		_:
			return 0


static func _load_config() -> Dictionary:
	var file: FileAccess = FileAccess.open(TEMPLATES_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		push_warning("[MissionGenerator] Missing templates at %s" % TEMPLATES_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}