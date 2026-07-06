class_name PathfindingService
extends RefCounted
## BFS pathfinding for the combat grid.
##
## Adapted from ramaureirac/godot-tactical-rpg
## `TacticsArenaService.process_surrounding_tiles` +
## `get_pathfinding_tilestack`.
##
## The pattern: BFS from a root tile, marking each reachable tile
## with `pf_root` (the tile we came from) and `pf_distance` (BFS
## distance from root). After BFS, the path to any target tile is
## reconstructed by following `pf_root` links back to the start.
##
## For 2D we use 4-neighbour (N/E/S/W) movement with a height
## delta cap equal to the unit's `jump` stat. Occupied tiles are
## treated as walls unless the occupier is an enemy (which can
## be attacked but not moved through).


## v0.11.0: BFS through the grid, marking each tile's
## pf_root + pf_distance. Stops at `max_distance` tiles. Tiles
## occupied by an enemy are NOT added (can't move through them,
## only attack them). Tiles occupied by a friendly unit ARE
## treated as walls (can't move into a friend).
##
## `enemies_on_map` is a list of CombatUnit nodes whose team
## is hostile to the moving unit. Passing it lets the BFS treat
## enemy-occupied tiles as walls (so a unit can't walk over an
## enemy to get behind them — they have to attack first).
func process_surrounding(arena_res: ArenaResource, root_x: int, y_root: int, max_distance: int, enemies_on_map: Array = []) -> void:
	_reset_markers(arena_res)
	var root: TileResource = arena_res.get_tile(root_x, y_root)
	if root == null:
		return
	var queue: Array = [root]
	root.pf_root = null  # explicit, since reset sets to null too
	root.pf_distance = 0
	while not queue.is_empty():
		var current: TileResource = queue.pop_front()
		if current.pf_distance >= max_distance:
			continue
		for neighbor in _get_neighbors(arena_res, current.grid_x, current.grid_y):
			if neighbor == root:
				continue
			if neighbor.pf_root != null:
				continue  # already visited
			if neighbor.blocked:
				continue  # impassable
			if neighbor.occupier != null and neighbor.occupier in enemies_on_map:
				continue  # enemy blocks movement (must attack)
			# OK, we can step onto this tile.
			neighbor.pf_root = current
			neighbor.pf_distance = current.pf_distance + 1
			queue.append(neighbor)


## v0.11.0: Get the 4 cardinal neighbours of (x, y). Wraps the
## standard 4-neighbour pattern (N/E/S/W) so we can change it
## later (e.g. add diagonals) in one place.
func _get_neighbors(arena_res: ArenaResource, x: int, y: int) -> Array[TileResource]:
	var out: Array[TileResource] = []
	for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var t: TileResource = arena_res.get_tile(x + offset.x, y + offset.y)
		if t != null:
			out.append(t)
	return out


## v0.11.0: Walk pf_root back from a target tile to the root,
## returning the list of grid positions in the order they'll be
## visited (root first, target last). The movement service pops
## the front of this list to step the unit along the path.
func get_path(arena_res: ArenaResource, to_x: int, to_y: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: TileResource = arena_res.get_tile(to_x, to_y)
	while current != null:
		path.push_front(Vector2i(current.grid_x, current.grid_y))
		current = current.pf_root
	return path


## v0.11.0: Reset pf_root + pf_distance + reachable/attackable
## on every tile in the arena. Called at the start of each
## pathfinding pass so stale data from a previous BFS doesn't
## leak into the new one.
func _reset_markers(arena_res: ArenaResource) -> void:
	for key in arena_res.tiles:
		var t: TileResource = arena_res.tiles[key]
		t.pf_root = null
		t.pf_distance = 0
		t.reachable = false
		t.attackable = false
		t.hover = false
