## EncounterDifficulty — Scale enemy stats and counts from party average level.
class_name EncounterDifficulty
extends RefCounted

const ClassProg = preload("res://scripts/ClassProgression.gd")

const SOURCE_OVERWORLD := "overworld"
const SOURCE_RIFT := "rift"

const HP_GROWTH := 0.06
const ATTACK_GROWTH := 0.04
const ARMOR_GROWTH := 0.035
const SPEED_GROWTH := 0.012

const MOD_OVERWORLD := 1.0
const MOD_RIFT_ROOM := 1.08
const MOD_RIFT_BOSS := 1.25
const MOD_MISSION := 1.06
const SOURCE_MISSION := "mission"


static func party_average_level(character_data: Dictionary) -> int:
	if character_data.is_empty():
		return ClassProg.MIN_LEVEL

	var levels: Array[int] = []
	var main_level: int = int(character_data.get("level", ClassProg.MIN_LEVEL))
	levels.append(maxi(1, main_level))

	var party: Variant = character_data.get("party", [])
	if party is Array:
		for member in party:
			if not member is Dictionary:
				continue
			var member_level: int = int((member as Dictionary).get("level", 0))
			if member_level > 0:
				levels.append(member_level)

	var companions: Variant = character_data.get("companions", [])
	if companions is Array:
		for companion in companions:
			if not companion is Dictionary:
				continue
			var companion_level: int = int((companion as Dictionary).get("level", 0))
			if companion_level > 0:
				levels.append(companion_level)

	var total: int = 0
	for lvl in levels:
		total += lvl
	return ClassProg.clamp_level(int(round(float(total) / float(levels.size()))))


static func source_modifier(source: String, is_boss: bool) -> float:
	if source == SOURCE_RIFT:
		return MOD_RIFT_BOSS if is_boss else MOD_RIFT_ROOM
	if source == SOURCE_MISSION:
		return MOD_RIFT_BOSS if is_boss else MOD_MISSION
	return MOD_OVERWORLD


static func difficulty_tier_for_level(avg_level: int) -> String:
	return _difficulty_tier(avg_level)


static func level_scale(avg_level: int, growth: float, modifier: float = 1.0) -> float:
	var lvl: int = ClassProg.clamp_level(avg_level)
	return (1.0 + float(lvl - 1) * growth) * modifier


static func scale_enemy_template(
	template: Dictionary,
	party_avg_level: int,
	source: String = SOURCE_OVERWORLD,
	is_boss: bool = false
) -> Dictionary:
	var scaled: Dictionary = template.duplicate(true)
	var modifier: float = source_modifier(source, is_boss)
	var hp_mult: float = level_scale(party_avg_level, HP_GROWTH, modifier)
	var atk_mult: float = level_scale(party_avg_level, ATTACK_GROWTH, modifier)
	var armor_mult: float = level_scale(party_avg_level, ARMOR_GROWTH, modifier)
	var speed_mult: float = level_scale(party_avg_level, SPEED_GROWTH, modifier)

	var base_hp: int = int(template.get("hp", 50))
	var base_attack: int = int(template.get("attack_damage", 8))
	var base_armor: int = int(template.get("armor", 0))
	var base_speed: int = int(template.get("speed", 7))

	scaled["base_hp"] = base_hp
	scaled["base_attack_damage"] = base_attack
	scaled["base_armor"] = base_armor
	scaled["base_speed"] = base_speed
	scaled["hp"] = maxi(1, int(round(float(base_hp) * hp_mult)))
	scaled["attack_damage"] = maxi(1, int(round(float(base_attack) * atk_mult)))
	scaled["armor"] = maxi(0, int(round(float(base_armor) * armor_mult)))
	scaled["speed"] = clampi(int(round(float(base_speed) * speed_mult)), 3, 20)
	scaled["level"] = party_avg_level
	scaled["difficulty_tier"] = _difficulty_tier(party_avg_level)
	if is_boss:
		scaled["is_boss"] = true
	return scaled


static func scale_enemy_templates(
	templates: Array,
	party_avg_level: int,
	source: String = SOURCE_OVERWORLD
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in templates:
		if not entry is Dictionary:
			continue
		var template: Dictionary = entry as Dictionary
		var is_boss: bool = bool(template.get("is_boss", false))
		out.append(scale_enemy_template(template, party_avg_level, source, is_boss))
	return out


static func rift_enemy_count(party_avg_level: int) -> int:
	var lvl: int = ClassProg.clamp_level(party_avg_level)
	var extra: int = lvl / 48
	return clampi(1 + extra + randi() % 2, 1, 6)


static func pick_mobs_for_level(pool: Array[Dictionary], count: int, party_avg_level: int) -> Array[Dictionary]:
	if pool.is_empty():
		return []
	var sorted: Array[Dictionary] = pool.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("hp", 0)) < int(b.get("hp", 0))
	)
	var tier_start: int = int(
		clampf(float(party_avg_level - 1) / 64.0, 0.0, 1.0) * float(maxi(0, sorted.size() - 1))
	)
	var window: int = maxi(1, mini(3, sorted.size() - tier_start))
	var picks: Array[Dictionary] = []
	for _i in range(count):
		var idx: int = tier_start + randi() % window
		picks.append(sorted[idx].duplicate(true))
	return picks


static func _difficulty_tier(avg_level: int) -> String:
	var lvl: int = ClassProg.clamp_level(avg_level)
	if lvl >= 192:
		return "nightmare"
	if lvl >= 128:
		return "elite"
	if lvl >= 64:
		return "veteran"
	if lvl >= 20:
		return "seasoned"
	if lvl >= 8:
		return "trained"
	return "rookie"