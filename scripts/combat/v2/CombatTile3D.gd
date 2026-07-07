class_name CombatTile3D
extends StaticBody3D
## 3D combat tile — StaticBody3D with mesh, collision, and raycasting.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsTile`.
## Each tile is a flat box mesh with a material override for
## highlight states (reachable, attackable, hover). A RayCast3D
## child detects neighboring tiles for pathfinding.

const CombatArena3DScript = preload("res://scripts/combat/v2/CombatArena3D.gd")
const CombatPawn3DScript = preload("res://scripts/combat/v2/CombatPawn3D.gd")
const CELL_SIZE: float = 1.0
const TILE_INSET: float = 0.05
const TILE_HEIGHT: float = 0.3
const RAYCAST_REACH: float = 1.5

## Visual state flags (read by _process for material swap)
var reachable: bool = false
var attackable: bool = false
var hover: bool = false
var blocked: bool = false

## Pathfinding metadata
var pf_root: CombatTile3D = null
var pf_distance: int = 0

## Terrain
var terrain_kind: int = 0
var grid_x: int = 0
var grid_y: int = 0

## Occupier reference
var occupier: Node3D = null

## Materials (set by CombatArena3D)
var mat_default: StandardMaterial3D
var mat_reachable: StandardMaterial3D
var mat_attackable: StandardMaterial3D
var mat_hover: StandardMaterial3D
var mat_hover_reachable: StandardMaterial3D
var mat_hover_attackable: StandardMaterial3D
var mat_blocked: StandardMaterial3D

## Child references
var _mesh: MeshInstance3D
var _collision: CollisionShape3D
var _raycast: RayCast3D


func _ready() -> void:
	_build_mesh()
	_build_collision()
	_build_raycast()


func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Tile"
	var box := BoxMesh.new()
	var tile_visual: float = CELL_SIZE - TILE_INSET * 2.0
	box.size = Vector3(tile_visual, TILE_HEIGHT, tile_visual)
	_mesh.mesh = box
	# Lift mesh so bottom face sits at y=0 (half height above ground)
	_mesh.position = Vector3(0.0, TILE_HEIGHT * 0.5, 0.0)
	add_child(_mesh)


func _build_collision() -> void:
	_collision = CollisionShape3D.new()
	_collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	var tile_visual: float = CELL_SIZE - TILE_INSET * 2.0
	box.size = Vector3(tile_visual, TILE_HEIGHT, tile_visual)
	_collision.shape = box
	_collision.position = Vector3(0.0, TILE_HEIGHT * 0.5, 0.0)
	add_child(_collision)


func _build_raycast() -> void:
	_raycast = RayCast3D.new()
	_raycast.name = "RayCast3D"
	_raycast.target_position = Vector3(0, -RAYCAST_REACH, 0)
	_raycast.enabled = true
	add_child(_raycast)


func setup(gx: int, gy: int, terrain: int, materials: Dictionary) -> void:
	grid_x = gx
	grid_y = gy
	terrain_kind = terrain
	blocked = (terrain == 3)
	position = Vector3(gx * CELL_SIZE, 0.0, gy * CELL_SIZE)
	# Apply materials
	mat_default = materials.get("default", null)
	mat_reachable = materials.get("reachable", null)
	mat_attackable = materials.get("attackable", null)
	mat_hover = materials.get("hover", null)
	mat_hover_reachable = materials.get("hover_reachable", null)
	mat_hover_attackable = materials.get("hover_attackable", null)
	mat_blocked = materials.get("blocked", null)
	_refresh_material()


func _process(_delta: float) -> void:
	if _mesh == null:
		return
	_mesh.visible = true
	_refresh_material()


func _refresh_material() -> void:
	if _mesh == null:
		return
	if blocked and mat_blocked != null:
		_mesh.material_override = mat_blocked
		return
	match hover:
		true:
			if reachable and mat_hover_reachable:
				_mesh.material_override = mat_hover_reachable
			elif attackable and mat_hover_attackable:
				_mesh.material_override = mat_hover_attackable
			elif mat_hover:
				_mesh.material_override = mat_hover
		false:
			if reachable and mat_reachable:
				_mesh.material_override = mat_reachable
			elif attackable and mat_attackable:
				_mesh.material_override = mat_attackable
			elif mat_default:
				_mesh.material_override = mat_default


func get_neighbors(height: float) -> Array[CombatTile3D]:
	var neighbors: Array[CombatTile3D] = []
	var arena: CombatArena3D = get_parent().get_parent() as CombatArena3D
	if arena == null:
		return neighbors
	for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var nx: int = grid_x + offset.x
		var ny: int = grid_y + offset.y
		var tile: CombatTile3D = arena.get_tile(nx, ny)
		if tile != null:
			neighbors.append(tile)
	return neighbors


func get_tile_occupier() -> Node3D:
	if _raycast and _raycast.is_colliding():
		var collider: Node3D = _raycast.get_collider()
		if collider is CombatPawn3D:
			return collider
	return null


func is_taken() -> bool:
	return get_tile_occupier() != null


func reset_markers() -> void:
	pf_root = null
	pf_distance = 0
	reachable = false
	attackable = false
	hover = false


func set_highlight(color: Color) -> void:
	if _mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat


func clear_highlight() -> void:
	_refresh_material()
