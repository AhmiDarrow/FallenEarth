class_name TacticsInput3D
extends Node3D
## Raycast-based input handler for 3D tactical combat.
##
## Casts rays from the camera through the mouse position to detect
## which tile or pawn was clicked. Emits signals for the CombatLevel.

const CombatTile3DScript = preload("res://scripts/combat/v2/CombatTile3D.gd")
const CombatPawn3DScript = preload("res://scripts/combat/v2/CombatPawn3D.gd")

signal tile_clicked(tile: CombatTile3D)
signal tile_hovered(tile: CombatTile3D)
signal pawn_clicked(pawn: CombatPawn3D)
signal right_clicked(position: Vector3)

## References
var _camera: Camera3D
var _space_state: PhysicsDirectSpaceState3D
var _last_hovered_tile: CombatTile3D = null


func setup(camera: Camera3D) -> void:
	_camera = camera


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(mb.position)

	if event is InputEventMouseMotion:
		_handle_hover(event.position)


func _handle_left_click(mouse_pos: Vector2) -> void:
	var result := _raycast_from_mouse(mouse_pos)
	if result.is_empty():
		return

	var collider: Node3D = result["collider"] as Node3D
	if collider is CombatTile3D:
		tile_clicked.emit(collider as CombatTile3D)
	elif collider is CombatPawn3D:
		pawn_clicked.emit(collider as CombatPawn3D)
		# Also emit the tile the pawn is standing on
		var pawn: CombatPawn3D = collider as CombatPawn3D
		if pawn._tile_raycast and pawn._tile_raycast.is_colliding():
			var tile_collider: Node3D = pawn._tile_raycast.get_collider()
			if tile_collider is CombatTile3D:
				tile_clicked.emit(tile_collider as CombatTile3D)


func _handle_right_click(mouse_pos: Vector2) -> void:
	var result := _raycast_from_mouse(mouse_pos)
	if result.is_empty():
		return
	var point: Vector3 = result["position"]
	right_clicked.emit(point)


func _handle_hover(mouse_pos: Vector2) -> void:
	var result := _raycast_from_mouse(mouse_pos)
	var new_hovered: CombatTile3D = null

	if not result.is_empty():
		var collider: Node3D = result["collider"] as Node3D
		if collider is CombatTile3D:
			new_hovered = collider as CombatTile3D

	# Unhover previous
	if _last_hovered_tile != null and _last_hovered_tile != new_hovered:
		_last_hovered_tile.hover = false

	# Hover new
	if new_hovered != null:
		new_hovered.hover = true
		tile_hovered.emit(new_hovered)

	_last_hovered_tile = new_hovered


func _raycast_from_mouse(mouse_pos: Vector2) -> Dictionary:
	if _camera == null:
		return {}
	var from: Vector3 = _camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + _camera.project_ray_normal(mouse_pos) * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	_space_state = _camera.get_world_3d().direct_space_state
	if _space_state == null:
		return {}
	var result: Dictionary = _space_state.intersect_ray(query)
	return result


func get_hovered_tile() -> CombatTile3D:
	return _last_hovered_tile
