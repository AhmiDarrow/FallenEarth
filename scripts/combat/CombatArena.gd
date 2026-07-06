class_name CombatArena
extends Node2D
## The combat grid: builds the 7x7 of CombatTile nodes, owns the
## ArenaResource, and refreshes each tile's visual each frame.
##
## Adapted from ramaureirac/godot-tactical-rpg `TacticsArena` —
## much simpler in 2D (no MeshInstance3D, no StaticBody3D, no
## raycasting). The arena just:
##   1. Builds NxN CombatTile children at (x*CELL_SIZE, y*CELL_SIZE)
##   2. Populates the ArenaResource's `tiles` dict
##   3. Refrshes each tile's visual based on its TileResource state

const CELL_SIZE: int = 40
const GRID_SIZE: int = 7

## v0.11.0: The ArenaResource this arena manages. The encounter
## builder writes units + biome here; the visual reads them.
var res: ArenaResource

## v0.11.0: All CombatTile children, indexed by "x,y" for fast
## lookup (parallel to ArenaResource.tiles).
var _tiles: Dictionary = {}

## v0.11.0: All CombatUnit children, indexed by unit_id.
var _units: Dictionary = {}

## v0.11.0: The biome's terrain atlas (24x120 sprite sheet with
## 5 rows of 24x24: ground/vegetation/debris/blocked/height).
## Loaded by configure() from TileSetService.
var _terrain_atlas: Texture2D = null


func _ready() -> void:
	res = ArenaResource.new()
	res.grid_size = GRID_SIZE


## v0.11.0: Configure the arena with a biome and grid size.
## Builds the 7x7 of tiles with terrain from a deterministic
## random seed.
func configure(biome: String = "Ash Wastes", grid_size: int = GRID_SIZE, height_seed: int = 0) -> void:
	res.biome = biome
	res.grid_size = grid_size
	_clear_tiles()
	_load_terrain_atlas()
	_build_tiles(height_seed)


func _load_terrain_atlas() -> void:
	var ts: TileSet = TileSetService.create_for_biome(res.biome)
	if ts == null:
		_terrain_atlas = null
		return
	for i in range(ts.get_source_count()):
		var src: TileSetSource = ts.get_source(i)
		if src is TileSetAtlasSource:
			_terrain_atlas = (src as TileSetAtlasSource).texture
			return
	_terrain_atlas = null


## v0.11.0: Build the grid. For each cell, pick a terrain kind
## from a deterministic RNG so the visuals match the engine's
## reachability.
func _build_tiles(height_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = height_seed
	for y in range(res.grid_size):
		for x in range(res.grid_size):
			var roll: float = rng.randf()
			var terrain: int = 0
			if roll < 0.08:
				terrain = 3  # blocked
			elif roll < 0.25:
				terrain = 1  # vegetation
			elif roll < 0.40:
				terrain = 2  # debris
			else:
				terrain = 0  # ground
			var tile: CombatTile = CombatTile.new()
			tile.name = "Tile_%d_%d" % [x, y]
			add_child(tile)  # add first so _ready runs and _base is built
			tile.setup(x, y, terrain, _terrain_atlas)
			_tiles["%d,%d" % [x, y]] = tile
			res.tiles["%d,%d" % [x, y]] = tile.res


func _clear_tiles() -> void:
	for key in _tiles:
		if is_instance_valid(_tiles[key]):
			_tiles[key].queue_free()
	_tiles.clear()


## v0.11.0: Add a unit to the arena. Called by the encounter
## builder when it places units on the grid.
func add_unit(unit_data: Dictionary) -> CombatUnit:
	var unit: CombatUnit = CombatUnit.new()
	unit.name = "Unit_" + str(unit_data.get("id", ""))
	add_child(unit)  # add first so _ready runs
	unit.setup_from_data(unit_data, res)
	_units[unit.res.unit_id] = unit
	res.units[unit.res.unit_id] = unit
	return unit


## v0.11.0: Remove a unit (e.g. on death or retreat).
func remove_unit(unit_id: String) -> void:
	if _units.has(unit_id):
		var u: CombatUnit = _units[unit_id]
		if is_instance_valid(u):
			u.queue_free()
		_units.erase(unit_id)
		res.units.erase(unit_id)


## v0.11.0: Get a tile by grid coordinates.
func get_tile(x: int, y: int) -> CombatTile:
	return _tiles.get("%d,%d" % [x, y], null)


## v0.11.0: Get a unit by id.
func get_unit(unit_id: String) -> CombatUnit:
	return _units.get(unit_id, null)


## v0.11.0: Refresh all tile visuals. Called every frame from
## CombatLevel.
func _process(_delta: float) -> void:
	for key in _tiles:
		var t: CombatTile = _tiles[key]
		if is_instance_valid(t):
			t.refresh()
