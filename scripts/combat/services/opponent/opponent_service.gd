class_name OpponentService
extends RefCounted
## Opponent (AI) turn logic.
##
## Adapted from ramaureirac/godot-tactical-rpg
## `TacticsOpponentService` — same "chase nearest enemy" +
## "weakest target" pattern. The actual AI brain (aggressive,
## defensive, boss, caster, ranged) lives in the existing
## `scripts/ai/` folder; this service just drives the opponent
## through the same state machine as the player.

## v0.11.0: Find the nearest player unit to the given enemy unit.
## Used to pick a chase target.
func nearest_player(arena: ArenaResource, enemy) -> Object:
	if enemy == null or arena == null:
		return null
	var enemy_res: UnitResource = enemy.res
	var best: Object = null
	var best_dist: int = 999999
	for unit_id in arena.units:
		var u: Object = arena.units[unit_id]
		if u == null or not is_instance_valid(u):
			continue
		var u_res: UnitResource = u.res
		if u_res.team != "player" or not u_res.is_alive():
			continue
		var dx: int = abs(enemy_res.grid_pos.x - u_res.grid_pos.x)
		var dy: int = abs(enemy_res.grid_pos.y - u_res.grid_pos.y)
		var dist: int = dx + dy  # Manhattan
		if dist < best_dist:
			best = u
			best_dist = dist
	return best


## v0.11.0: AI-driven pawn selection for the opponent. Picks the
## first living opponent-side unit that can act. Returns the
## CombatUnit node or null if no opponent can act.
func select_pawn(arena: ArenaResource) -> Object:
	var candidates: Array = arena.get_opponent_units_by_speed()
	for unit in candidates:
		var res: UnitResource = unit.res
		if res.can_move or res.can_act:
			return unit
	return null


## v0.11.0: Pick a destination tile for the AI pawn — the tile
## adjacent to the nearest player unit, reachable in `move` steps.
## Returns the destination grid pos or null if unreachable.
func pick_move_target(arena: ArenaResource, pawn) -> Vector2i:
	if pawn == null:
		return Vector2i(-1, -1)
	var pawn_res: UnitResource = pawn.res
	var target: Object = nearest_player(arena, pawn)
	if target == null:
		return Vector2i(-1, -1)
	# BFS around the pawn, looking for the tile closest to the
	# target that we can reach.
	var path_serv: PathfindingService = PathfindingService.new()
	path_serv.process_surrounding(arena, pawn_res.grid_pos.x, pawn_res.grid_pos.y, pawn_res.move, [target])
	# Among reachable tiles, find the one closest (in Manhattan
	# distance) to the target.
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 999999
	for key in arena.tiles:
		var t: TileResource = arena.tiles[key]
		if not t.reachable:
			continue
		var dx: int = abs(t.grid_x - target.res.grid_pos.x)
		var dy: int = abs(t.grid_y - target.res.grid_pos.y)
		var dist: int = dx + dy
		# Adjacent = within 1 tile.
		if dist < best_dist:
			best = Vector2i(t.grid_x, t.grid_y)
			best_dist = dist
	return best
