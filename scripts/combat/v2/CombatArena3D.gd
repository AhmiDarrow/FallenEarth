class_name CombatArena3D
extends Node3D
## 3D combat grid — builds NxN CombatTile3D nodes and CombatPawn3D units.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsArena`.
## The arena owns the ArenaResource and manages tile/pawn lifecycle.

const CombatTile3DScript = preload("res://scripts/combat/v2/CombatTile3D.gd")
const CombatPawn3DScript = preload("res://scripts/combat/v2/CombatPawn3D.gd")
const BiomeTileServiceScript = preload("res://scripts/combat/services/BiomeTileService.gd")
const DestructibleDecorScript = preload("res://scripts/combat/v2/DestructibleDecor.gd")
const DEFAULT_GRID_SIZE: int = 20

## The ArenaResource this arena manages
var res: ArenaResource

## All tile children, indexed by "x,y"
var _tiles: Dictionary = {}

## All pawn children, indexed by unit_id
var _pawns: Dictionary = {}

## Material palette for tiles
var _materials: Dictionary = {}

## Biome tile texture service
var _biome_service: BiomeTileService = null

## Destructible decor objects, indexed by "x,y"
var _decor: Dictionary = {}

const DECOR_TYPES: Array = ["boulder", "cactus", "roots", "rubble", "skull", "stump", "thorns"]


func _ready() -> void:
	res = ArenaResource.new()
	res.grid_size = DEFAULT_GRID_SIZE
	_biome_service = BiomeTileService.new()
	_build_materials()


func _build_materials() -> void:
	var biome_name: String = res.biome if res and res.biome else "Ash Wastes"

	# Try to load biome-textured materials
	var tex_ground: Texture2D = _biome_service.get_tile_texture(biome_name, 0) if _biome_service else null
	var tex_veg: Texture2D = _biome_service.get_tile_texture(biome_name, 1) if _biome_service else null
	var tex_debris: Texture2D = _biome_service.get_tile_texture(biome_name, 2) if _biome_service else null
	var tex_blocked: Texture2D = _biome_service.get_tile_texture(biome_name, 3) if _biome_service else null

	# Fallback flat colors
	var ground_color := Color(0.55, 0.62, 0.55, 1.0)
	var vegetation_color := Color(0.35, 0.65, 0.35, 1.0)
	var debris_color := Color(0.70, 0.55, 0.35, 1.0)
	var blocked_color := Color(0.80, 0.35, 0.25, 1.0)

	# Highlight colors (always flat — overlays)
	var reach_color := Color(0.30, 0.70, 1.0, 0.7)
	var attack_color := Color(0.95, 0.20, 0.20, 0.7)
	var hover_color := Color(1.0, 0.95, 0.4, 0.8)
	var hover_reach_color := Color(0.30, 0.85, 1.0, 0.8)
	var hover_attack_color := Color(1.0, 0.40, 0.30, 0.8)

	_materials = {
		"default": _make_tex_mat(tex_ground, ground_color, true),
		"reachable": _make_mat(reach_color),
		"attackable": _make_mat(attack_color),
		"hover": _make_mat(hover_color),
		"hover_reachable": _make_mat(hover_reach_color),
		"hover_attackable": _make_mat(hover_attack_color),
		"blocked": _make_tex_mat(tex_blocked, blocked_color, true),
		"terrain_vegetation": _make_tex_mat(tex_veg, vegetation_color, true),
		"terrain_debris": _make_tex_mat(tex_debris, debris_color, true),
		"terrain_blocked": _make_tex_mat(tex_blocked, blocked_color),
	}


func _make_mat(color: Color, opaque: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if opaque else BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _make_tex_mat(texture: Texture2D, fallback_color: Color, opaque: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if texture:
		mat.albedo_texture = texture
		mat.albedo_color = Color.WHITE
		mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
		mat.uv1_offset = Vector3(0.0, 0.0, 0.0)
	else:
		mat.albedo_color = fallback_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if opaque else BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func configure(biome: String = "Ash Wastes", grid_size: int = DEFAULT_GRID_SIZE, height_seed: int = 0) -> void:
	res.biome = biome
	res.grid_size = grid_size
	_clear_tiles()
	_build_materials()
	_build_ground_plane()
	_build_tiles(height_seed)
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
			var place_decor: bool = false
			if roll < 0.08:
				place_decor = true
				terrain = 4
			elif roll < 0.25:
				terrain = 1
			elif roll < 0.40:
				terrain = 2

			var tile := CombatTile3D.new()
			tile.name = "Tile_%d_%d" % [x, y]
			tile.setup(x, y, terrain, _materials)
			match terrain:
				1: tile.mat_default = _materials["terrain_vegetation"]
				2: tile.mat_default = _materials["terrain_debris"]
			tiles_node.add_child(tile)
			_tiles["%d,%d" % [x, y]] = tile
			res.tiles["%d,%d" % [x, y]] = tile

			if place_decor:
				_place_decor(x, y)


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
	_clear_decor()


func _clear_decor() -> void:
	var decor_node := get_node_or_null("Decor")
	if decor_node:
		decor_node.queue_free()
	_decor.clear()


func _place_decor(grid_x: int, grid_y: int) -> void:
	var decor_node := get_node_or_null("Decor")
	if decor_node == null:
		decor_node = Node3D.new()
		decor_node.name = "Decor"
		add_child(decor_node)

	var type_name: String = DECOR_TYPES[randi() % DECOR_TYPES.size()]
	var variant: int = randi() % 4
	var dec: DestructibleDecor = DestructibleDecor.new()
	dec.setup(type_name, variant, 30, Vector2i(grid_x, grid_y))
	dec.position = _tile_center(grid_x, grid_y)
	dec.position.y = CombatTile3D.TILE_HEIGHT
	decor_node.add_child(dec)
	_decor["%d,%d" % [grid_x, grid_y]] = dec
	dec.decor_destroyed.connect(_on_decor_destroyed)


func _tile_center(grid_x: int, grid_y: int) -> Vector3:
	return Vector3(
		float(grid_x) * CombatTile3D.CELL_SIZE + CombatTile3D.CELL_SIZE * 0.5,
		0.0,
		float(grid_y) * CombatTile3D.CELL_SIZE + CombatTile3D.CELL_SIZE * 0.5
	)


func _on_decor_destroyed(dec: DestructibleDecor, grid_pos: Vector2i) -> void:
	var key: String = "%d,%d" % [grid_pos.x, grid_pos.y]
	if _decor.has(key):
		_decor.erase(key)
	_roll_decor_loot(grid_pos)


func _roll_decor_loot(grid_pos: Vector2i) -> void:
	var loot_chance: float = randf()
	if loot_chance < 0.15:
		var loot_item: String = _pick_decor_loot()
		var pawn: CombatPawn3D = _nearest_pawn(grid_pos)
		if pawn and is_instance_valid(pawn):
			pawn._show_loot_text(loot_item)


func _pick_decor_loot() -> String:
	var loot_table: Array[String] = ["Scrap Metal", "Cloth Scrap", "Bone Fragment", "Crystal Shard", "Rusty Gear", "Neon Cell"]
	return loot_table[randi() % loot_table.size()]


func _nearest_pawn(grid_pos: Vector2i) -> CombatPawn3D:
	var nearest: CombatPawn3D = null
	var min_dist: float = INF
	for pawn in _pawns.values():
		if not is_instance_valid(pawn):
			continue
		if not pawn is CombatPawn3D:
			continue
		if not pawn.alive:
			continue
		var dx: int = pawn.res.grid_pos.x - grid_pos.x
		var dy: int = pawn.res.grid_pos.y - grid_pos.y
		var dist: float = sqrt(float(dx*dx + dy*dy))
		if dist < min_dist:
			min_dist = dist
			nearest = pawn
	return nearest


func _build_ground_plane() -> void:
	var grid_px: float = float(res.grid_size) * CombatTile3D.CELL_SIZE
	var ground := MeshInstance3D.new()
	ground.name = "GroundPlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid_px + 0.1, grid_px + 0.1)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	# Use biome ground texture for ground plane
	var biome_name: String = res.biome if res and res.biome else "Ash Wastes"
	var tex: Texture2D = _biome_service.get_tile_texture(biome_name, 0) if _biome_service else null
	if tex:
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE
		mat.uv1_scale = Vector3(grid_px / 0.9, grid_px / 0.9, 1.0)
	else:
		mat.albedo_color = Color(0.15, 0.17, 0.19, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = mat
	ground.position = Vector3(grid_px * 0.5, -0.02, grid_px * 0.5)
	add_child(ground)


func add_unit(unit_data: Dictionary) -> CombatPawn3D:
	var pawn := CombatPawn3D.new()
	pawn.name = "Pawn_" + str(unit_data.get("id", ""))
	var pawns_node := get_node_or_null("Pawns")
	if pawns_node == null:
		pawns_node = Node3D.new()
		pawns_node.name = "Pawns"
		add_child(pawns_node)
	pawns_node.add_child(pawn)
	pawn.setup_from_data(unit_data, res, self)
	_pawns[pawn.res.unit_id] = pawn
	res.units[pawn.res.unit_id] = pawn
	# Mark the tile as occupied
	var pos: Vector2i = pawn.res.grid_pos
	var tile: CombatTile3D = get_tile(pos.x, pos.y)
	if tile:
		tile.occupier = pawn
	return pawn


func remove_unit(unit_id: String) -> void:
	if _pawns.has(unit_id):
		var p: CombatPawn3D = _pawns[unit_id]
		if is_instance_valid(p):
			var pos: Vector2i = p.res.grid_pos if p.res else Vector2i(-1, -1)
			var tile: CombatTile3D = get_tile(pos.x, pos.y)
			if tile and tile.occupier == p:
				tile.occupier = null
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
		# Use Chebyshev distance for attack range (matches UnitCombatService.in_range)
		var dx: int = absi(t.grid_x - root.grid_x)
		var dy: int = absi(t.grid_y - root.grid_y)
		var cheb_dist: int = maxi(dx, dy)
		var in_range: bool = cheb_dist > 0 and cheb_dist <= int(distance)
		var is_root: bool = t == root
		t.attackable = in_range or is_root


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
		path.push_front(to.position)
		to = to.pf_root
	return path


func _reset_pathfinding() -> void:
	for key in _tiles:
		_tiles[key].reset_markers()
