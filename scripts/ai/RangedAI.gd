## RangedAI — Maintains optimal distance. If the enemy is in range,
## attacks. If too close, retreats. If too far, advances cautiously.
class_name RangedAI extends CombatAI


const MIN_RANGE_RATIO := 0.5
const IDEAL_RANGE := 3


func decide(state: Dictionary) -> Dictionary:
	var self_unit: Dictionary = state.get("self", {})
	var enemies: Array = state.get("enemies", []) as Array
	if enemies.is_empty():
		return {"type": "wait", "score": 0.0}
	var my_pos: Vector2i = self_unit.get("pos", Vector2i.ZERO)
	var weapon_range: int = int(self_unit.get("weapon_range", 3))
	var height_map: Dictionary = state.get("height_map", {})
	var reachable: Array = state.get("reachable", []) as Array
	var attackable: Array = state.get("attackable", []) as Array

	# 1. If in range, attack the best target.
	var best_attack: Dictionary = {}
	var best_score: float = -1.0
	for e in enemies:
		if int(e.get("hp", 0)) <= 0:
			continue
		var e_pos: Vector2i = e.get("pos", Vector2i.ZERO)
		if not attackable.has(e_pos):
			continue
		var s: float = score_attack(my_pos, e, height_map)
		if s > best_score:
			best_score = s
			best_attack = e
	if not best_attack.is_empty():
		return {
			"type": "attack",
			"target": best_attack.get("pos", Vector2i.ZERO),
			"score": best_score,
		}

	# 2. Choose a movement tile that moves us toward the ideal range.
	var closest_enemy: Dictionary = _closest_enemy(my_pos, enemies)
	if closest_enemy.is_empty():
		return {"type": "wait", "score": 0.0}
	var enemy_pos: Vector2i = closest_enemy.get("pos", Vector2i.ZERO)
	var current_d: int = chebyshev(my_pos, enemy_pos)
	var best_tile: Vector2i = my_pos
	var best_tile_score: float = -1e9
	for tile in reachable:
		if tile == my_pos:
			continue
		var d: int = chebyshev(tile, enemy_pos)
		# Score: prefer distance >= weapon_range and <= weapon_range + 2
		var in_range: bool = d <= weapon_range
		var too_close: bool = d < int(float(weapon_range) * MIN_RANGE_RATIO)
		var s: float = 0.0
		if in_range and not too_close:
			# Best tile: in range but not too close.
			s = 100.0 - absf(float(d) - float(IDEAL_RANGE)) * 10.0
		elif too_close:
			# Retreating is good.
			s = 50.0 + float(current_d - d) * 5.0
		else:
			# Advancing toward range.
			s = -float(d) * 3.0
		if s > best_tile_score:
			best_tile_score = s
			best_tile = tile
	if best_tile != my_pos:
		return {"type": "move", "target": best_tile, "score": best_tile_score}
	return {"type": "wait", "score": 0.0}


func _closest_enemy(from_pos: Vector2i, enemies: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 1000
	for e in enemies:
		if int(e.get("hp", 0)) <= 0:
			continue
		var d: int = chebyshev(from_pos, e.get("pos", Vector2i.ZERO))
		if d < best_d:
			best_d = d
			best = e
	return best
