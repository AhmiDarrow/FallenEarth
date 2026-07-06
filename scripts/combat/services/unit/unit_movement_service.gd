class_name UnitMovementService
extends RefCounted
## Movement logic for a single unit: step along a precomputed path,
## detect arrival, emit movement-completed signal.
##
## Adapted from ramaureirac/godot-tactical-rpg
## `TacticsPawnMovementService.move_along_path` — but for 2D
## (no jump / gravity; the height system is deferred).
##
## The movement is tween-based: each frame the unit moves a
## fraction of the way toward the next tile in the path. When
## it's close enough, pop the path stack and start moving to
## the next tile. When the path is empty, the unit has arrived
## and we call back to the combat level.

const TILE_SIZE: float = 40.0
const STEP_DURATION: float = 0.22  ## seconds per tile step


## v0.11.0: Start moving the unit along the given path. Stores
## the path on the unit's resource and zeroes the step tween
## accumulator. Called by CombatLevel.on_select_location once
## the player clicks a destination tile.
func start_move(unit, path: Array[Vector2i]) -> void:
	if unit == null or path.is_empty():
		return
	var unit_res: UnitResource = unit.res
	unit_res.move_path = path.duplicate()
	unit_res.has_moved = true  ## mark as moved immediately so the
	## other pathfinding/highlight services stop considering it
	# Set the unit's visual position to the first tile immediately
	# (so the rest of the path animates from there).
	if not path.is_empty():
		var first: Vector2i = path[0]
		unit.position = Vector2(first.x * TILE_SIZE + TILE_SIZE * 0.5, first.y * TILE_SIZE + TILE_SIZE * 0.5)


## v0.11.0: Advance the unit along its path by `delta` seconds.
## Returns true if the unit is still moving, false if the path
## is complete (the unit has arrived at its destination).
##
## Each frame we:
## 1. Look at the next tile in the path (front of move_path).
## 2. Lerp from the current position toward that tile's center.
## 3. If we're close enough, pop the front of move_path and
##    snap to that tile. If move_path is now empty, we're done.
func step(unit, delta: float) -> bool:
	if unit == null:
		return false
	var unit_res: UnitResource = unit.res
	if unit_res.move_path.is_empty():
		unit_res.grid_pos = unit_res.grid_pos  # already at destination
		unit.is_moving = false
		return false
	var next: Vector2i = unit_res.move_path[0]
	var target: Vector2 = Vector2(next.x * TILE_SIZE + TILE_SIZE * 0.5, next.y * TILE_SIZE + TILE_SIZE * 0.5)
	var step_distance: float = (TILE_SIZE / STEP_DURATION) * delta
	unit.position = unit.position.move_toward(target, step_distance)
	if unit.position.distance_to(target) < 1.0:
		# Arrived at this tile — pop and continue.
		unit_res.move_path.pop_front()
		unit_res.grid_pos = next
		# Update tile occupancy.
		var arena: ArenaResource = unit.arena_resource
		if arena != null:
			var old_tile: TileResource = arena.get_tile(next.x, next.y)
			if old_tile != null:
				old_tile.occupier = unit
		if unit_res.move_path.is_empty():
			unit.is_moving = false
			return false
	unit.is_moving = true
	return true
