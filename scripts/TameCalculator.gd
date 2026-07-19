## TameCalculator — Pure static logic for tame chance and max-tamed lookup.
## Phase 2 of the Tameable Mobs system.
class_name TameCalculator
extends RefCounted

const CONFIG_PATH := "res://data/tame_config.json"

static var _config: Dictionary = {}
static var _loaded := false


static func _load_config() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		push_error("[TameCalculator] Failed to open %s" % CONFIG_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var raw: Variant = JSON.parse_string(text)
	if not (raw is Dictionary):
		push_error("[TameCalculator] %s did not produce a dictionary." % CONFIG_PATH)
		return
	_config = raw.get("data", raw) if "data" in raw else raw
	_loaded = true


static func calculate_chance(
	player_level: int,
	mob_level: int,
	mob_current_hp: int,
	mob_max_hp: int,
	tame_difficulty: float
) -> float:
	var diff: float = float(player_level - mob_level)
	var base: float = 0.1 + diff * 0.02
	base = clampf(base, 0.01, 0.50)

	var health_ratio: float = float(mob_current_hp) / float(maxi(1, mob_max_hp))
	var health_mod: float = 1.0 - health_ratio

	var chance: float = base * (1.0 + health_mod) * tame_difficulty
	return clampf(chance, 0.01, 0.95)


static func get_max_tamed(player_level: int) -> int:
	_ensure_loaded()
	if not _loaded:
		return 1
	var tiers: Array = _config.get("max_tamed_per_level_tier", [])
	var result: int = _config.get("max_tamed_base", 1)
	for tier in tiers:
		if not tier is Dictionary:
			continue
		var min_lvl: int = int(tier.get("min_level", 999))
		if player_level >= min_lvl:
			result = int(tier.get("max_tamed", result))
	return result


static func get_cooldown_turns() -> int:
	_ensure_loaded()
	if not _loaded:
		return 3
	return int(_config.get("base_cooldown_turns", 3))


static func _ensure_loaded() -> void:
	if not _loaded:
		_load_config()
