class_name CombatArena3D
extends Node3D
## 3D combat grid — builds NxN CombatTile3D nodes and CombatPawn3D units.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsArena`.
## The arena owns the ArenaResource and manages tile/pawn lifecycle.

const CombatTile3DScript = preload("res://scripts/combat/v2/CombatTile3D.gd")
const CombatPawn3DScript = preload("res://scripts/combat/v2/CombatPawn3D.gd")
const DEFAULT_GRID_SIZE: int = 7

## The ArenaResource this arena manages
var res: ArenaResource

## All tile children, indexed by "x,y"
var _tiles: Dictionary = {}

## All pawn children, indexed by unit_id
var _pawns: Dictionary = {}

## Material palette for tiles
var _materials: Dictionary = {}


func _ready() -> void:
	res = ArenaResource.new()
	res.grid_size = DEFAULT_GRID_SIZE
	_build_materials()


func _build_materials() -> void:
	# Default terrain colors — brighter for visibility
	var ground_color := Color(0.55, 0.62, 0.55, 1.0)
	var vegetation_color := Color(0.35, 0.65, 0.35, 1.0)
	var debris_color := Color(0.70, 0.55, 0.35, 1.0)
	var blocked_color := Color(0.80, 0.35, 0.25, 1.0)

	# Highlight colors
	var reach_color := Color(0.30, 0.70, 1.0, 0.7)
	var attack_color := Color(0.95, 0.20, 0.20, 0.7)
	var hover_color := Color(1.0, 0.95, 0.4, 0.8)
	var hover_reach_color := Color(0.30, 0.85, 1.0, 0.8)
	var hover_attack_color := Color(1.0, 0.40, 0.30, 0.8)

	_materials = {
		"default": _make_mat(ground_color, true),
		"reachable": _make_mat(reach_color),
		"attackable": _make_mat(attack_color),
		"hover": _make_mat(hover_color),
		"hover_reachable": _make_mat(hover_reach_color),
		"hover_attackable": _make_mat(hover_attack_color),
		"blocked": _make_mat(blocked_color),
		"terrain_vegetation": _make_mat(vegetation_color, true),
		"terrain_debris": _make_mat(debris_color, true),
		"terrain_blocked": _make_mat(blocked_color),
	}


func _make_mat(color: Color, opaque: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if opaque:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func configure(biome: String = "Ash Wastes", grid_size: int = DEFAULT_GRID_SIZE, height_seed: int = 0) -> void:
	res.biome = biome
	res.grid_size = grid_size
	_clear_tiles()
	_build_ground_plane()
	_build_tiles(height_seed)
	_build_grid_wireframe()
	_center_grid()


func _build_tiles(height_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = height_seed
	var tiles_node := Node3D.new()
	tiles_node.name = "Tiles"
	add_child(tiles_node)

	for y in range(res.grid_size):
		for x in range(res.grid_size):
			var roll: float = rng.randf()
			var terrain: int = 0
			if roll < 0.08:
				terrain = 3
			elif roll < 0.25:
				terrain = 1
			elif roll < 0.40:
				terrain = 2

			var tile := CombatTile3D.new()
			tile.name = "Tile_%d_%d" % [x, y]
			var tile_mats := _materials.duplicate()
			# Override default with terrain-specific color
			match terrain:
				1: tile_mats["default"] = _materials["terrain_vegetation"]
				2: tile_mats["default"] = _materials["terrain_debris"]
				3: tile_mats["default"] = _materials["terrain_blocked"]
			tile.setup(x, y, terrain, tile_mats)
			tiles_node.add_child(tile)
			_tiles["%d,%d" % [x, y]] = tile
			res.tiles["%d,%d" % [x, y]] = tile


func _center_grid() -> void:
	var grid_px: float = float(res.grid_size) * CombatTile3D.CELL_SIZE
	position = Vector3(-grid_px * 0.5, 0.0, -grid_px * 0.5)


func _clear_tiles() -> void:
	var tiles_node := get_node_or_null("Tiles")
	if tiles_node:
		tiles_node.queue_free()
	_tiles.clear()
	var ground := get_node_or_null("GroundPlane")
	if ground:
		ground.queue_free()
	var wireframe := get_node_or_null("GridWireframe")
	if wireframe:
		wireframe.queue_free()


func _build_ground_plane() -> void:
	var grid_px: float = float(res.grid_size) * CombatTile3D.CELL_SIZE
	var ground := MeshInstance3D.new()
	ground.name = "GroundPlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid_px + 0.1, grid_px + 0.1)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.17, 0.19, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = mat
	ground.position = Vector3(0.0, -0.02, 0.0)
	add_child(ground)


func _build_grid_wireframe() -> void:
	var im := ImmediateMesh.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GridWireframe"
	var grid_px: float = float(res.grid_size) * CombatTile3D.CELL_SIZE
	var half: float = grid_px * 0.5
	var line_y: float = CombatTile3D.TILE_HEIGHT + 0.01
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Vertical lines
	for i in range(res.grid_size + 1):
		var x: float = float(i) * CombatTile3D.CELL_SIZE - half
		im.surface_add_vertex(Vector3(x, line_y, -half))
		im.surface_add_vertex(Vector3(x, line_y, half))
	# Horizontal lines
	for i in range(res.grid_size + 1):
		var z: float = float(i) * CombatTile3D.CELL_SIZE - half
		im.surface_add_vertex(Vector3(-half, line_y, z))
		im.surface_add_vertex(Vector3(half, line_y, z))
	im.surface_end()
	mesh_instance.mesh = im
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	add_child(mesh_instance)


func add_unit(unit_data: Dictionary) -> CombatPawn3D:
	var pawn := CombatPawn3D.new()
	pawn.name = "Pawn_" + str(unit_data.get("id", ""))
	var pawns_node := get_node_or_null("Pawns")
	if pawns_node == null:
		pawns_node = Node3D.new()
		pawns_node.name = "Pawns"
		add_child(pawns_node)
	pawns_node.add_child(pawn)
	pawn.setup_from_data(unit_data, res)
	_pawns[pawn.res.unit_id] = pawn
	res.units[pawn.res.unit_id] = pawn
	return pawn


func remove_unit(unit_id: String) -> void:
	if _pawns.has(unit_id):
		var p: CombatPawn3D = _pawns[unit_id]
		if is_instance_valid(p):
			p.queue_free()
		_pawns.erase(unit_id)
		res.units.erase(unit_id)


func get_tile(x: int, y: int) -> CombatTile3D:
	return _tiles.get("%d,%d" % [x, y], null)


func get_pawn(unit_id: String) -> CombatPawn3D:
	return _pawns.get(unit_id, null)


func get_all_tiles() -> Array[CombatTile3D]:
	var out: Array[CombatTile3D] = []
	for key in _tiles:
		out.append(_tiles[key])
	return out


func reset_all_tile_markers() -> void:
	for key in _tiles:
		_tiles[key].reset_markers()


func mark_reachable_tiles(root: CombatTile3D, distance: float) -> void:
	for key in _tiles:
		var t: CombatTile3D = _tiles[key]
		var has_dist: bool = t.pf_distance > 0
		var in_range: bool = t.pf_distance <= distance
		var not_taken: bool = not t.is_taken()
		var is_root: bool = t == root
		t.reachable = (has_dist and in_range and not_taken) or is_root


func mark_attackable_tiles(root: CombatTile3D, distance: float) -> void:
	for key in _tiles:
		var t: CombatTile3D = _tiles[key]
		var has_dist: bool = t.pf_distance > 0
		var in_range: bool = t.pf_distance <= distance
		var is_root: bool = t == root
		t.attackable = has_dist and in_range or is_root


func process_surrounding_tiles(root_tile: CombatTile3D, max_distance: int, allies: Array = []) -> void:
	_reset_pathfinding()
	if root_tile == null:
		return
	var queue: Array = [root_tile]
	root_tile.pf_root = null
	root_tile.pf_distance = 0

	while not queue.is_empty():
		var current: CombatTile3D = queue.pop_front()
		if current.pf_distance >= max_distance:
			continue
		for neighbor in current.get_neighbors(1.0):
			if neighbor == root_tile:
				continue
			if neighbor.pf_root != null:
				continue
			if neighbor.blocked:
				continue
			if neighbor.is_taken() and not (neighbor in allies):
				continue
			neighbor.pf_root = current
			neighbor.pf_distance = current.pf_distance + 1
			queue.append(neighbor)


func get_pathfinding_tilestack(to: CombatTile3D) -> Array:
	var path: Array = []
	while to:
		to.hover = true
		path.push_front(to.global_position)
		to = to.pf_root
	return path


func _reset_pathfinding() -> void:
	for key in _tiles:
		_tiles[key].reset_markers()
