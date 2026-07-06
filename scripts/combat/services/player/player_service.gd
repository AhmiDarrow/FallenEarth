class_name PlayerService
extends RefCounted
## Player-specific turn logic: select pawn, show moves, attack.
##
## Adapted from ramaureirac/godot-tactical-rpg
## `TacticsPlayerService` — same "show_available_X" / "move_pawn"
## pattern, with the actual input handled by the combat level
## (this service just decides *what* should happen at each stage).
##
## For our 2D project we keep the service stateless — the
## combat level tracks the current state and the service just
## makes decisions based on it.


## v0.11.0: Pick the next player pawn to act (slowest first so
## the fastest unit gets to move later). Returns the CombatUnit
## node or null if no player can act.
func select_pawn(arena: ArenaResource) -> Object:
	var candidates: Array = arena.get_player_units_by_speed()
	for unit in candidates:
		var res: UnitResource = unit.res
		if res.can_move or res.can_act:
			return unit
	return null


## v0.11.0: Mark all tiles within `move` of the current pawn as
## `reachable`, and tiles within `attack_range` (but not in
## `move`) as `attackable`. Used by SHOW_MOVEMENTS and
## DISPLAY_TARGETS stages.
##
## The arena is responsible for the actual visual update; this
## just calls the pathfinder and sets the flags.
func mark_tiles(arena: ArenaResource, pawn, enemies: Array) -> void:
	if pawn == null:
		return
	var pawn_res: UnitResource = pawn.res
	# Reset all tile highlights.
	for key in arena.tiles:
		var t: TileResource = arena.tiles[key]
		t.reachable = false
		t.attackable = false
		t.hover = false
	# BFS for reachable tiles.
	var path_serv: PathfindingService = PathfindingService.new()
	path_serv.process_surrounding(arena, pawn_res.grid_pos.x, pawn_res.grid_pos.y, pawn_res.move, enemies)
	# Mark reachable tiles + tile the pawn is standing on.
	for key in arena.tiles:
		var t: TileResource = arena.tiles[key]
		if t.pf_distance > 0 and t.pf_distance <= pawn_res.move and not t.is_taken():
			t.reachable = true
		elif t.grid_x == pawn_res.grid_pos.x and t.grid_y == pawn_res.grid_pos.y:
			t.reachable = true  # the pawn's own tile
	arena.tile_highlights_changed.emit()
