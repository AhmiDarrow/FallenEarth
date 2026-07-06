## DefensiveAI — Guards low-HP allies. Uses height advantage and
## retreats at < 30% HP. Stays near allies.
class_name DefensiveAI extends CombatAI


const LOW_HP_THRESHOLD := 0.3
const GUARD_RADIUS := 2


func decide(state: Dictionary) -> Dictionary:
	var self_unit: Dictionary = state.get("self", {})
	var allies: Array = state.get("allies", []) as Array
	var enemies: Array = state.get("enemies", []) as Array
	if enemies.is_empty():
		return {"type": "wait", "score": 0.0}
	var my_pos: Vector2i = self_unit.get("pos", Vector2i.ZERO)
	var my_hp: int = int(self_unit.get("hp", 0))
	var my_max: int = int(self_unit.get("max_hp", my_hp))
	var my_ratio: float = float(my_hp) / float(maxi(1, my_max))
	var reachable: Array = state.get("reachable", []) as Array
	var attackable: Array = state.get("attackable", []) as Array
	var height_map: Dictionary = state.get("height_map", {})

	# 1. If critically low HP, retreat away from all enemies.
	if my_ratio < LOW_HP_THRESHOLD:
		var best_tile: Vector2i = my_pos
		var best_dist: int = 0
		for tile in reachable:
			if tile == my_pos:
				continue
			var min_d: int = 1000
			for e in enemies:
				if int(e.get("hp", 0)) <= 0:
					continue
				min_d = mini(min_d, chebyshev(tile, e.get("pos", Vector2i.ZERO)))
			if min_d > best_dist:
				best_dist = min_d
				best_tile = tile
		if best_tile != my_pos:
			return {"type": "move", "target": best_tile, "score": float(best_dist) * 10.0}

	# 2. Attack if a free shot is available.
	if not attackable.is_empty():
		var best_target: Vector2i = attackable[0]
		var best_score: float = -1.0
		for tile in attackable:
			for e in enemies:
				if e.get("pos", Vector2i(-99, -99)) == tile:
					var s: float = score_attack(my_pos, e, height_map)
					if s > best_score:
						best_score = s
						best_target = tile
		return {"type": "attack", "target": best_target, "score": best_score}

	# 3. Move toward a low-HP ally that needs guarding, or toward a
	# height advantage tile near enemies.
	var guarded_ally: Dictionary = _lowest_hp_ally_near(my_pos, allies)
	var target_pos: Vector2i = my_pos
	if not guarded_ally.is_empty():
		target_pos = guarded_ally.get("pos", my_pos)
	else:
		# Default: stay between enemies and allies
		for e in enemies:
			if int(e.get("hp", 0)) <= 0:
				continue
			target_pos = e.get("pos", my_pos)
			break

	var best_tile2: Vector2i = my_pos
	var best_score2: float = -1e9
	for tile in reachable:
		if tile == my_pos:
			continue
		var d_to_target: int = chebyshev(tile, target_pos)
		var d_to_enemy: int = 1000
		for e in enemies:
			if int(e.get("hp", 0)) <= 0:
				continue
			d_to_enemy = mini(d_to_enemy, chebyshev(tile, e.get("pos", Vector2i.ZERO)))
		var h: int = int(height_map.get("%d,%d" % [tile.x, tile.y], 0))
		var s: float = 0.0
		# Prefer close to guarded ally, far from enemies, on high ground.
		s = -float(d_to_target) * 5.0
		s += float(d_to_enemy) * 3.0
		s += float(h) * 20.0
		if s > best_score2:
			best_score2 = s
			best_tile2 = tile
	if best_tile2 != my_pos:
		return {"type": "move", "target": best_tile2, "score": best_score2}
	return {"type": "wait", "score": 0.0}


func _lowest_hp_ally_near(from_pos: Vector2i, allies: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_ratio: float = 1.0
	for a in allies:
		if int(a.get("hp", 0)) <= 0:
			continue
		var d: int = chebyshev(from_pos, a.get("pos", Vector2i.ZERO))
		if d > GUARD_RADIUS:
			continue
		var hp: int = int(a.get("hp", 0))
		var max_hp: int = int(a.get("max_hp", hp))
		var r: float = float(hp) / float(maxi(1, max_hp))
		if r < best_ratio:
			best_ratio = r
			best = a
	return best
