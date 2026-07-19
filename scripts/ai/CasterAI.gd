## CasterAI — Prefers skills when MP is available, attacks otherwise.
## Position itself to maximize AOE skill targets when possible.
class_name CasterAI extends CombatAI


func decide(state: Dictionary) -> Dictionary:
	var self_unit: Dictionary = state.get("self", {})
	var enemies: Array = state.get("enemies", []) as Array
	if enemies.is_empty():
		return {"type": "wait", "score": 0.0}
	var my_pos: Vector2i = self_unit.get("pos", Vector2i.ZERO)
	var abilities: Array = self_unit.get("abilities", []) as Array
	var mp: int = int(self_unit.get("mp", 0))
	var skillable: Array = state.get("skillable", []) as Array
	var reachable: Array = state.get("reachable", []) as Array
	var attackable: Array = state.get("attackable", []) as Array

	# 1. Try to use the most expensive skill we can afford.
	if not abilities.is_empty():
		var best_skill: Dictionary = {}
		var best_skill_score: float = -1.0
		for ab in abilities:
			if not ab is Dictionary:
				continue
			var cost: int = int(ab.get("mp_cost", 99))
			if cost > mp:
				continue
			var range_: int = int(ab.get("range", 3))
			# Find the tile in skillable with the most targets in AOE.
			for tile in skillable:
				var hits: int = _count_targets_in_radius(tile, int(ab.get("radius", 1)), enemies)
				if hits == 0:
					continue
				var s: float = float(hits) * 50.0 - float(cost) * 0.5
				# Bias for skills with bigger area.
				s += float(int(ab.get("radius", 1))) * 10.0
				if s > best_skill_score:
					best_skill_score = s
					best_skill = {
						"id": ab.get("id", ""),
						"target": tile,
						"score": s,
					}
		if not best_skill.is_empty():
			return {
				"type": "skill",
				"skill_id": best_skill.get("id", ""),
				"target": best_skill.get("target", Vector2i.ZERO),
				"score": best_skill_score,
			}

	# 2. Attack if in range.
	if not attackable.is_empty():
		var best_target: Vector2i = attackable[0]
		var best_score: float = -1.0
		var height_map: Dictionary = state.get("height_map", {})
		for tile in attackable:
			for e in enemies:
				if e.get("pos", Vector2i(-99, -99)) == tile:
					var s: float = score_attack(my_pos, e, height_map)
					if s > best_score:
						best_score = s
						best_target = tile
		return {"type": "attack", "target": best_target, "score": best_score}

	# 3. Move closer to be in range for next turn.
	if not reachable.is_empty():
		var closest: Dictionary = _closest_enemy(my_pos, enemies)
		if not closest.is_empty():
			var enemy_pos: Vector2i = closest.get("pos", Vector2i.ZERO)
			var best_tile: Vector2i = my_pos
			var best_d: int = INF_DISTANCE
			for tile in reachable:
				if tile == my_pos:
					continue
				var d: int = chebyshev(tile, enemy_pos)
				if d < best_d:
					best_d = d
					best_tile = tile
			if best_tile != my_pos:
				return {"type": "move", "target": best_tile, "score": -float(best_d)}
	return {"type": "wait", "score": 0.0}


func _count_targets_in_radius(center: Vector2i, radius: int, enemies: Array) -> int:
	var count: int = 0
	for e in enemies:
		if int(e.get("hp", 0)) <= 0:
			continue
		if chebyshev(center, e.get("pos", Vector2i.ZERO)) <= radius:
			count += 1
	return count


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
