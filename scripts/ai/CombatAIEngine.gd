## CombatAIEngine — Factory + state builder for AI.
##
## Builds a fresh AI instance for an `ai_archetype` string and
## produces the state dict that AIs consume.
class_name CombatAIEngine

const AggressiveAIScript = preload("res://scripts/ai/AggressiveAI.gd")
const RangedAIScript = preload("res://scripts/ai/RangedAI.gd")
const CasterAIScript = preload("res://scripts/ai/CasterAI.gd")
const DefensiveAIScript = preload("res://scripts/ai/DefensiveAI.gd")
const BossAIScript = preload("res://scripts/ai/BossAI.gd")

const ARCHETYPES := {
	"aggressive": "aggressive",
	"melee": "aggressive",
	"ranged": "ranged",
	"caster": "caster",
	"defensive": "defensive",
	"boss": "boss",
}


## Build an AI instance for the given archetype string. Returns null
## for unknown / empty archetype (caller can fall back to aggressive).
static func build(archetype: String) -> CombatAI:
	var key: String = ARCHETYPES.get(archetype.to_lower(), "aggressive")
	match key:
		"ranged":
			return RangedAIScript.new()
		"caster":
			return CasterAIScript.new()
		"defensive":
			return DefensiveAIScript.new()
		"boss":
			return BossAIScript.new()
		_:
			return AggressiveAIScript.new()


## Build a state dict that the AI can consume. self is the unit
## taking its turn. The engine provides enemies, allies, grid info,
## and computed reachability/attackability arrays.
static func build_state(
	self_unit: Dictionary,
	all_units: Array,
	grid_size: int,
	height_map: Dictionary,
	reachable: Array,
	attackable: Array,
	skillable: Array,
	blocked: Array,
	can_move_now: bool
) -> Dictionary:
	var enemies: Array = []
	var allies: Array = []
	for u in all_units:
		if str(u.get("id", "")) == str(self_unit.get("id", "")):
			continue
		if int(u.get("hp", 0)) <= 0:
			continue
		if str(u.get("team", "enemy")) == str(self_unit.get("team", "enemy")):
			allies.append(u)
		else:
			enemies.append(u)
	var is_walkable: Dictionary = {}
	for y in range(grid_size):
		for x in range(grid_size):
			var blocked_idx: int = y * grid_size + x
			var is_blocked: bool = false
			if blocked_idx < blocked.size():
				is_blocked = bool(blocked[blocked_idx])
			is_walkable["%d,%d" % [x, y]] = not is_blocked
	return {
		"self": self_unit,
		"allies": allies,
		"enemies": enemies,
		"grid_size": grid_size,
		"height_map": height_map,
		"reachable": reachable if can_move_now else [],
		"attackable": attackable,
		"skillable": skillable,
		"is_walkable": is_walkable,
		"can_move": can_move_now,
	}
