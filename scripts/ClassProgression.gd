## ClassProgression — Level 1–256 class XP, stat growth, and ability unlocks.
class_name ClassProgression
extends RefCounted

const MAX_LEVEL := 256
const MIN_LEVEL := 1


static func clamp_level(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)


static func xp_required_for_next_level(current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return 0
	# Steep FFT-style curve: early fast, late grind
	return int(15.0 * pow(float(current_level), 1.72))


static func total_xp_for_level(target_level: int) -> int:
	var lvl: int = clamp_level(target_level)
	var total: int = 0
	for l in range(MIN_LEVEL, lvl):
		total += xp_required_for_next_level(l)
	return total


static func apply_xp(current_level: int, current_xp: int, grant: int) -> Dictionary:
	var lvl: int = clamp_level(current_level)
	var xp: int = maxi(0, current_xp + grant)
	var gained: int = 0
	while lvl < MAX_LEVEL:
		var need: int = xp_required_for_next_level(lvl)
		if need <= 0 or xp < need:
			break
		xp -= need
		lvl += 1
		gained += 1
	return {"level": lvl, "xp": xp, "levels_gained": gained}


static func build_stats_at_level(class_data: Dictionary, level: int, base_stats: Dictionary) -> Dictionary:
	var lvl: int = clamp_level(level)
	var prog: Dictionary = _progression(class_data)
	var growth: Dictionary = prog.get("growth", {}) as Dictionary
	var out: Dictionary = base_stats.duplicate(true)
	for stat in ["str", "dex", "con", "int", "wis", "cha"]:
		var base: int = int(base_stats.get(stat, 10))
		var per_lvl: float = float(growth.get(stat, 0.1))
		out[stat] = base + int(per_lvl * float(lvl - 1))
	return out


static func compute_max_hp(con: int, level: int, class_data: Dictionary) -> int:
	var lvl: int = clamp_level(level)
	var prog: Dictionary = _progression(class_data)
	var growth: Dictionary = prog.get("growth", {}) as Dictionary
	var hp_per: int = int(growth.get("hp", 6))
	return 80 + con * 5 + hp_per * (lvl - 1)


static func build_combat_profile(class_data: Dictionary, level: int) -> Dictionary:
	var lvl: int = clamp_level(level)
	var combat: Dictionary = (class_data.get("combat", {}) as Dictionary).duplicate(true)
	var prog: Dictionary = _progression(class_data)
	var growth: Dictionary = prog.get("growth", {}) as Dictionary

	combat["mp_max"] = int(combat.get("mp_max", 24)) + int(growth.get("mp", 1)) * (lvl - 1)
	combat["attack_bonus"] = int(combat.get("attack_bonus", 0)) + int(float(growth.get("attack_bonus", 0.05)) * float(lvl - 1))
	combat["armor_bonus"] = int(combat.get("armor_bonus", 0)) + int(float(growth.get("armor_bonus", 0.04)) * float(lvl - 1))
	combat["speed_bonus"] = int(combat.get("speed_bonus", 0)) + int(float(growth.get("speed_bonus", 0.03)) * float(lvl - 1))
	combat["move_bonus"] = int(combat.get("move_bonus", 0)) + int(float(growth.get("move_bonus", 0.02)) * float(lvl - 1) / 4.0)
	combat["abilities"] = get_unlocked_abilities(class_data, lvl)
	combat["class_level"] = lvl
	combat["max_level"] = int(prog.get("max_level", MAX_LEVEL))
	return combat


static func get_unlocked_abilities(class_data: Dictionary, level: int) -> Array[Dictionary]:
	var lvl: int = clamp_level(level)
	var combat: Dictionary = class_data.get("combat", {}) as Dictionary
	var all_abs: Variant = combat.get("abilities", [])
	var out: Array[Dictionary] = []
	if all_abs is Array:
		for entry in all_abs:
			if not entry is Dictionary:
				continue
			var ab: Dictionary = (entry as Dictionary).duplicate(true)
			var unlock: int = int(ab.get("unlock_level", 1))
			if lvl >= unlock:
				out.append(ab)
	return out


static func combat_xp_reward(encounter: Dictionary, victory: bool) -> int:
	if not victory:
		return 0
	var char_data: Dictionary = encounter.get("character_data", {}) as Dictionary
	var party_level: int = int(encounter.get("party_avg_level", char_data.get("level", 1)))
	var base: int = 20
	var source: String = str(encounter.get("source", ""))
	if source == "rift":
		var ctx: Dictionary = encounter.get("return_context", {}) as Dictionary
		if str(ctx.get("encounter_type", "")) == "boss":
			return 350 + party_level * 8
		base = 45
	elif source == "overworld":
		base = 28
	var enemies: Array = encounter.get("enemy_templates", []) as Array
	base += enemies.size() * 12
	for e in enemies:
		if e is Dictionary:
			base += int((e as Dictionary).get("hp", 50)) / 25
	base += party_level / 4
	return base


static func progression_from_class(class_data: Dictionary) -> Dictionary:
	return _progression(class_data)


static func _progression(class_data: Dictionary) -> Dictionary:
	var prog: Variant = class_data.get("progression", {})
	if prog is Dictionary:
		return prog as Dictionary
	return {"max_level": MAX_LEVEL, "growth": {}}