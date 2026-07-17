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
	for pos in path:
		if pos is Vector3:
			var gx: int = int(pos.x / CombatTile3D.CELL_SIZE)
			var gy: int = int(pos.z / CombatTile3D.CELL_SIZE)
			unit_res.move_path.append(Vector2i(gx, gy))
	unit_res.has_moved = true
	pawn.is_moving = true
	pawn.play_anim("walk")


func step(pawn: CombatPawn3D, delta: float) -> bool:
	if pawn == null:
		return false
	var unit_res: UnitResource = pawn.res
	if unit_res.move_path.is_empty():
		pawn.is_moving = false
		return false

	var next_grid: Vector2i = unit_res.move_path[0]
	var target_pos := Vector3(
		next_grid.x * CombatTile3D.CELL_SIZE,
		0.0,
		next_grid.y * CombatTile3D.CELL_SIZE
	)

	var current_pos: Vector3 = pawn.position
	var flat_target := Vector3(target_pos.x, 0.0, target_pos.z)
	var dist_to_target: float = Vector2(current_pos.x, current_pos.z).distance_to(Vector2(flat_target.x, flat_target.z))

	if dist_to_target < 0.05:
		pawn.position = flat_target
		unit_res.move_path.pop_front()
		unit_res.grid_pos = next_grid
		if pawn.arena_node:
			var tile = pawn.arena_node.get_tile(next_grid.x, next_grid.y)
			if tile and tile is CombatTile3D:
				tile.occupier = pawn
		if unit_res.move_path.is_empty():
			pawn.is_moving = false
			pawn.play_anim("idle")
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
	pawn.position = Vector3(new_flat.x, jump_y, new_flat.z)

	# Force upright — no physical rotation should ever happen
	pawn.rotation = Vector3.ZERO

	pawn.is_moving = true
	return true
