## AggressiveAI — Default melee AI. Walks straight at the nearest
## enemy and attacks when in range. Prefers flanking (back/side bonus)
## and finishing off low-HP targets.
class_name AggressiveAI extends CombatAI


func decide(state: Dictionary) -> Dictionary:
	var self_unit: Dictionary = state.get("self", {})
	var enemies: Array = state.get("enemies", []) as Array
	if enemies.is_empty():
		return {"type": "wait", "score": 0.0}
	var my_pos: Vector2i = self_unit.get("pos", Vector2i.ZERO)
	var weapon_range: int = int(self_unit.get("weapon_range", 1))
	var height_map: Dictionary = state.get("height_map", {})
	var reachable: Array = state.get("reachable", []) as Array
	var attackable: Array = state.get("attackable", []) as Array

	# 1. If we can attack someone now, pick the best target.
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

	# 2. Otherwise, advance toward the best-positioned reachable tile.
	# The best tile maximizes flanking on the closest enemy.
	var closest_enemy: Dictionary = _closest_enemy(my_pos, enemies)
	if closest_enemy.is_empty():
		return {"type": "wait", "score": 0.0}
	var enemy_pos: Vector2i = closest_enemy.get("pos", Vector2i.ZERO)
	var enemy_facing: int = int(closest_enemy.get("facing", 2))
	var best_tile: Vector2i = my_pos
	var best_tile_score: float = -1e9
	for tile in reachable:
		if tile == my_pos:
			continue
		# Don't move into blocked cells.
		if not state.get("is_walkable", {}).get(_pos_key(tile), true):
			continue
		# Score this tile: would it put us in attack range, or close to flanking?
		var d: int = chebyshev(tile, enemy_pos)
		var in_range_score: float = 100.0 if d <= weapon_range else 0.0
		# Flanking bonus — if we end up at this tile, will we be at the
		# target's back or side?
		var flank_score: float = facing_bonus(tile, enemy_pos, enemy_facing) * 50.0
		# Prefer closer tiles.
		var dist_score: float = -float(d) * 5.0
		var s: float = in_range_score + flank_score + dist_score
		if s > best_tile_score:
			best_tile_score = s
			best_tile = tile
	if best_tile != my_pos:
		return {"type": "move", "target": best_tile, "score": best_tile_score}
	# 3. Stuck — wait.
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


static func _pos_key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]
