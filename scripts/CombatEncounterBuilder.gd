## Builds unified combat encounter payloads for overworld and rift fights.
class_name CombatEncounterBuilder
extends RefCounted

const MOB_DATA_PATH := "res://data/mobs.json"
const CLASSES_PATH := "res://data/character_classes.json"
const ClassProg = preload("res://scripts/ClassProgression.gd")
const Difficulty = preload("res://scripts/EncounterDifficulty.gd")

const SOURCE_OVERWORLD := "overworld"
const SOURCE_RIFT := "rift"
const SOURCE_MISSION := "mission"

const RETURN_HUB := "res://scenes/HubWorld.tscn"
const RETURN_RIFT := "res://scenes/RiftInstance.tscn"


static func build_mission(
	character_data: Dictionary,
	mob_template: Dictionary,
	tile_key: String,
	biome_key: String,
	mission: Dictionary
) -> Dictionary:
	var encounter: Dictionary = _base_encounter(7, character_data, biome_key)
	var party_level: int = Difficulty.party_average_level(character_data)
	var mult: float = float(mission.get("difficulty_mult", 1.0))
	encounter["source"] = SOURCE_MISSION
	encounter["return_scene"] = RETURN_HUB
	encounter["return_context"] = {
		"tile_key": tile_key,
		"mission_id": str(mission.get("mission_id", "")),
		"remove_mob_on_victory": true,
	}
	encounter["party_avg_level"] = party_level
	encounter["mission_title"] = str(mission.get("title", "Mission"))
	var scaled: Array[Dictionary] = Difficulty.scale_enemy_templates(
		[mob_template.duplicate(true)], party_level, SOURCE_MISSION
	)
	if not scaled.is_empty():
		var enemy: Dictionary = scaled[0]
		enemy["hp"] = maxi(1, int(round(float(enemy.get("hp", 50)) * mult)))
		enemy["attack_damage"] = maxi(1, int(round(float(enemy.get("attack_damage", 8)) * mult)))
		enemy["armor"] = maxi(0, int(round(float(enemy.get("armor", 0)) * mult)))
		scaled[0] = enemy
	encounter["enemy_templates"] = scaled
	encounter["victory_loot"] = false
	encounter["loot_count"] = 0
	return encounter


static func build_overworld(
	character_data: Dictionary,
	mob_template: Dictionary,
	tile_key: String,
	biome_key: String = "Ash Wastes"
) -> Dictionary:
	var grid_size: int = 7
	var encounter: Dictionary = _base_encounter(grid_size, character_data, biome_key)
	encounter["source"] = SOURCE_OVERWORLD
	encounter["return_scene"] = RETURN_HUB
	encounter["return_context"] = {
		"tile_key": tile_key,
		"remove_mob_on_victory": true,
	}
	var party_level: int = Difficulty.party_average_level(character_data)
	encounter["party_avg_level"] = party_level
	encounter["enemy_templates"] = Difficulty.scale_enemy_templates(
		[mob_template.duplicate(true)], party_level, SOURCE_OVERWORLD
	)
	encounter["victory_loot"] = true
	encounter["loot_count"] = 2
	return encounter


static func build_rift_room(
	character_data: Dictionary,
	biome_key: String,
	rift_id: String,
	entry_q: int,
	entry_r: int,
	encounter_type: String,
	tile_key: String = "",
	entry_local_x: int = 256,
	entry_local_y: int = 256
) -> Dictionary:
	var is_boss: bool = encounter_type == "boss"
	var encounter: Dictionary = _base_encounter(7, character_data, biome_key)
	encounter["source"] = SOURCE_RIFT
	encounter["return_scene"] = RETURN_RIFT
	encounter["return_context"] = {
		"rift_id": rift_id,
		"biome_key": biome_key,
		"entry_q": entry_q,
		"entry_r": entry_r,
		"entry_local_x": entry_local_x,
		"entry_local_y": entry_local_y,
		"encounter_type": encounter_type,
		"dungeon_tile_key": tile_key,
		"mark_dungeon_on_victory": true,
	}
	var party_level: int = Difficulty.party_average_level(character_data)
	encounter["party_avg_level"] = party_level
	if is_boss:
		var boss: Dictionary = _rift_boss_template(biome_key)
		encounter["enemy_templates"] = Difficulty.scale_enemy_templates(
			[boss], party_level, SOURCE_RIFT
		)
	else:
		var count: int = Difficulty.rift_enemy_count(party_level)
		var raw: Array[Dictionary] = _pick_room_enemies(biome_key, count, party_level)
		encounter["enemy_templates"] = Difficulty.scale_enemy_templates(
			raw, party_level, SOURCE_RIFT
		)
	encounter["victory_loot"] = is_boss
	encounter["loot_count"] = 3 if is_boss else 0
	return encounter


static func _base_encounter(grid_size: int, character_data: Dictionary, biome_key: String) -> Dictionary:
	var class_id: String = str(character_data.get("class", "Survivor"))
	var party_level: int = Difficulty.party_average_level(character_data)
	return {
		"grid_size": grid_size,
		"biome_key": biome_key,
		"character_data": character_data.duplicate(true),
		"party_avg_level": party_level,
		"class_combat": _class_combat_for(class_id, party_level),
		"player_start": Vector2i(grid_size / 2, grid_size - 1),
		"height_seed": biome_key.hash(),
	}


static func _class_combat_for(class_id: String, level: int = 1) -> Dictionary:
	var cls: Dictionary = _load_class_entry(class_id)
	if cls.is_empty():
		return {}
	return ClassProg.build_combat_profile(cls, level)


static func _load_class_entry(class_id: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(CLASSES_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary and str((entry as Dictionary).get("name", "")) == class_id:
				return (entry as Dictionary).duplicate(true)
	return {}


static func _pick_room_enemies(_biome_key: String, count: int, party_avg_level: int = 1) -> Array[Dictionary]:
	var aggressive: Array[Dictionary] = _load_mob_pool("aggressive")
	if aggressive.is_empty():
		aggressive.append({"name": "Charnel Stalker", "hp": 90, "armor": 5, "attack_damage": 15, "speed": 8})
	return Difficulty.pick_mobs_for_level(aggressive, count, party_avg_level)


static func _rift_boss_template(biome_key: String) -> Dictionary:
	var aggressive: Array[Dictionary] = _load_mob_pool("aggressive")
	var base: Dictionary = aggressive[0].duplicate(true) if not aggressive.is_empty() else {
		"name": "Rift Horror", "hp": 120, "armor": 6, "attack_damage": 18, "speed": 8,
	}
	base["name"] = "%s Rift Lord" % biome_key.split(" ")[0]
	base["hp"] = int(base.get("hp", 100)) * 2
	base["attack_damage"] = int(base.get("attack_damage", 12)) + 10
	base["armor"] = int(base.get("armor", 4)) + 5
	base["speed"] = int(base.get("speed", 7)) + 1
	base["is_boss"] = true
	return base


static func random_overworld_mob(biome_key: String, aggressive_only: bool = false) -> Dictionary:
	var pool_key: String = "aggressive" if aggressive_only or randf() < _danger_chance(biome_key) else "neutral"
	var pool: Array[Dictionary] = _load_mob_pool(pool_key)
	if pool.is_empty():
		return {"name": "Charnel Stalker", "hp": 90, "armor": 5, "attack_damage": 15, "speed": 8}
	return pool[randi() % pool.size()].duplicate(true)


static func _danger_chance(biome_key: String) -> float:
	match biome_key:
		"Dead City Outskirts", "Stormspire Highlands":
			return 0.85
		"Rust Canyons", "Corpse Fields", "Toxin Marshes":
			return 0.65
		"Glass Dunes", "Neon Bogs":
			return 0.5
		_:
			return 0.35


static func _load_mob_pool(pool_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file: FileAccess = FileAccess.open(MOB_DATA_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return result
	var ow: Variant = parsed.get("overworld", {})
	if ow is Dictionary:
		var arr: Variant = ow.get(pool_key, [])
		if arr is Array:
			for m in arr:
				if m is Dictionary:
					var d: Dictionary = (m as Dictionary).duplicate(true)
					if not d.has("speed"):
						d["speed"] = 7 if pool_key == "aggressive" else 5
					result.append(d)
	return result