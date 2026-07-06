class_name UnitMovementService3D
extends RefCounted
## 3D movement logic — interpolates a pawn along a path of world positions
## with a jump arc between tiles for visual polish.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsPawnMovementService`.

const CombatPawn3DScript = preload("res://scripts/combat/v2/CombatPawn3D.gd")
const CombatTile3DScript = preload("res://scripts/combat/v2/CombatTile3D.gd")
const STEP_SPEED: float = 5.0
const JUMP_HEIGHT: float = 0.4


func start_move(pawn: CombatPawn3D, path: Array) -> void:
	if pawn == null or path.is_empty():
		return
	var unit_res: UnitResource = pawn.res
	unit_res.move_path = []
	# Convert Vector3 positions to Vector2i grid coords for the resource
	for pos in path:
		if pos is Vector3:
			var gx: int = int(pos.x / CombatPawn3D.CELL_SIZE)
			var gy: int = int(pos.z / CombatPawn3D.CELL_SIZE)
			unit_res.move_path.append(Vector2i(gx, gy))
	unit_res.has_moved = true
	pawn.is_moving = true


func step(pawn: CombatPawn3D, delta: float) -> bool:
	if pawn == null:
		return false
	var unit_res: UnitResource = pawn.res
	if unit_res.move_path.is_empty():
		pawn.is_moving = false
		return false

	var next_grid: Vector2i = unit_res.move_path[0]
	var target_pos := Vector3(
		next_grid.x * CombatPawn3D.CELL_SIZE,
		0.0,
		next_grid.y * CombatPawn3D.CELL_SIZE
	)

	var current_pos: Vector3 = pawn.global_position
	var flat_target := Vector3(target_pos.x, 0.0, target_pos.z)
	var dist_to_target: float = Vector2(current_pos.x, current_pos.z).distance_to(Vector2(flat_target.x, flat_target.z))

	if dist_to_target < 0.05:
		# Arrived at this tile
		pawn.global_position = flat_target
		unit_res.move_path.pop_front()
		unit_res.grid_pos = next_grid
		# Update tile occupancy
		if pawn.arena_resource:
			var tile = pawn.arena_resource.get_tile(next_grid.x, next_grid.y)
			if tile:
				tile.occupier = pawn
		if unit_res.move_path.is_empty():
			pawn.is_moving = false
			return false
		return true

	# Interpolate with jump arc
	var t: float = 1.0 - (dist_to_target / maxf(1.0, STEP_SPEED * 0.5))
	var jump_y: float = JUMP_HEIGHT * sin(t * PI)
	var direction := (flat_target - Vector3(current_pos.x, 0.0, current_pos.z)).normalized()
	var move_amount: float = STEP_SPEED * delta
	var new_flat := Vector3(current_pos.x, 0.0, current_pos.z) + direction * move_amount
	# Clamp past target
	if new_flat.distance_to(flat_target) < 0.05:
		new_flat = flat_target
	pawn.global_position = Vector3(new_flat.x, jump_y, new_flat.z)

	pawn.is_moving = true
	return true


func look_at_direction(pawn: CombatPawn3D, direction: Vector3) -> void:
	if pawn == null or direction.length_squared() < 0.001:
		return
	var flat_dir := Vector3(direction.x, 0, direction.z).normalized()
	if flat_dir.length_squared() > 0.001:
		pawn.look_at(pawn.global_position + flat_dir, Vector3.UP)
