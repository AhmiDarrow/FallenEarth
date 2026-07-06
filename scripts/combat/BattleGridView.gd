## BattleGridView — 7x7 (configurable) FFT-style battle grid.
##
## v0.10.10: REVERTED FROM ISOMETRIC DIAMOND. The v0.10.5 iso-diamond
## view produced a 45°-rotated rhombus-shaped grid with diamond cells
## that read as "broken" rather than as a tactical grid. The current
## layout is a clean 7x7 SQUARE grid of SQUARE cells — same look as
## the overworld LocalMapView. Cells position at (x * CELL_SIZE,
## y * CELL_SIZE). Each cell renders the terrain as a square sprite,
## and the highlight (move/attack/skill) is a square ColorRect on top.
## v0.10.11: CELL_SIZE 56 -> 40. The 7x7 = 280px grid fits between
## the TopPrompt (above) and the bottom ActionBar/SkillBar (below)
## without overlap. The 56px version had the top row partially
## hidden by the TopPrompt and the bottom row nearly touching the
## ActionBar.
class_name BattleGridView extends Node2D

# v0.10.11: CELL_SIZE 56 -> 40. 7x7 = 280px (~22% of 1280 viewport)
# fits cleanly with the TopPrompt (top) and ActionBar (bottom).
const CELL_SIZE := 40

const BattleCellScript = preload("res://scripts/combat/BattleCell.gd")
const BattleUnitScript = preload("res://scripts/combat/BattleUnit.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const TileSetService = preload("res://scripts/TileSetService.gd")

var _grid_layer: Node2D
var _unit_layer: Node2D
var _cursor_layer: Node2D
var _cells: Array[BattleCell] = []
var _units: Dictionary = {}
var _height_map: Dictionary = {}
var _biome: String = "Ash Wastes"
var _terrain_atlas: Texture2D = null
var grid_size: int = 7


signal cell_clicked(x: int, y: int)
signal cell_hovered(x: int, y: int, hovered: bool)


## Return the BattleUnit by id (or null).
func get_unit(unit_id: String) -> BattleUnit:
	return _units.get(unit_id, null)


## Return all current BattleUnit nodes in spawn order.
func get_all_units() -> Array:
	var out: Array = []
	for uid in _units:
		var bu: BattleUnit = _units[uid]
		if is_instance_valid(bu):
			out.append(bu)
	return out


## Return the world-space center of a grid cell, in the grid's parent
## local space. v0.10.10: simple square grid; cell at (x, y) is at
## (x * CELL_SIZE + CELL_SIZE/2, y * CELL_SIZE + CELL_SIZE/2).
func cell_to_world(x: int, y: int) -> Vector2:
	return Vector2(
		float(x) * CELL_SIZE + CELL_SIZE * 0.5,
		float(y) * CELL_SIZE + CELL_SIZE * 0.5,
	)


## v0.10.10: kept as an alias for code that still calls cell_to_iso.
## Returns the same as cell_to_world now (no more iso transform).
func cell_to_iso(x: int, y: int) -> Vector2:
	return cell_to_world(x, y)


## Square grid bounds: returns a Rect2 covering the full grid extent
## in local space. Used to center the grid.
func _iso_grid_bounds() -> Rect2:
	var grid_px: float = float(grid_size) * CELL_SIZE
	return Rect2(0.0, 0.0, grid_px, grid_px)


func _ready() -> void:
	_build_children()


func _build_children() -> void:
	_grid_layer = Node2D.new()
	_grid_layer.name = "GridLayer"
	add_child(_grid_layer)

	_unit_layer = Node2D.new()
	_unit_layer.name = "UnitLayer"
	_unit_layer.y_sort_enabled = true
	add_child(_unit_layer)

	_cursor_layer = Node2D.new()
	_cursor_layer.name = "CursorLayer"
	add_child(_cursor_layer)


func configure(encounter: Dictionary) -> void:
	grid_size = int(encounter.get("grid_size", 7))
	_biome = str(encounter.get("biome_key", "Ash Wastes"))
	_height_map = (encounter.get("height_map", {}) as Dictionary).duplicate(true)
	_load_biome_atlas()
	if not encounter.has("terrain_grid") or not encounter.has("blocked_grid"):
		encounter = build_terrain_for_encounter(encounter)
	_build_cells(encounter)
	_clear_units()
	_spawn_units(encounter)
	# v0.10.10: center the square grid in local space so the
	# grid's bounding-box center is at (0, 0) in this node's
	# local space. With a 7x7 grid at 40px/cell (v0.10.11), that's
	# 280x280 centered, so the grid spans -140..+140 in both axes.
	var grid_px: float = float(grid_size) * CELL_SIZE
	var offset: Vector2 = -Vector2(grid_px * 0.5, grid_px * 0.5)
	_grid_layer.position = offset
	_unit_layer.position = offset
	_cursor_layer.position = offset


func _load_biome_atlas() -> void:
	var tile_set: TileSet = TileSetService.create_for_biome(_biome)
	if tile_set == null:
		_terrain_atlas = null
		return
	for i in range(tile_set.get_source_count()):
		var src: TileSetSource = tile_set.get_source(i)
		if src is TileSetAtlasSource:
			_terrain_atlas = (src as TileSetAtlasSource).texture
			return
	_terrain_atlas = null


func _build_cells(encounter: Dictionary) -> void:
	_clear_cells()
	var terrain: Array = encounter.get("terrain_grid", []) as Array
	var blocked: Array = encounter.get("blocked_grid", []) as Array
	for y in range(grid_size):
		for x in range(grid_size):
			var cell := BattleCellScript.new()
			cell.name = "Cell_%d_%d" % [x, y]
			_grid_layer.add_child(cell)
			cell.clicked.connect(_on_cell_clicked)
			cell.hover_changed.connect(_on_cell_hovered)
			var t_idx: int = _terrain_at_index(terrain, x, y, 0)
			var h: int = int(_height_map.get("%d,%d" % [x, y], 0))
			var b: bool = _bool_at_index(blocked, x, y, false) or t_idx == LocalMapGen.TERRAIN_BLOCKED
			var tex: Texture2D = _tile_texture_for(t_idx)
			# v0.10.10: square grid; cell origin is the top-left of
			# the cell, sprite fills CELL_SIZE x CELL_SIZE.
			cell.setup(x, y, t_idx, h, b, tex, CELL_SIZE)
			_cells.append(cell)


func _tile_texture_for(terrain: int) -> Texture2D:
	if _terrain_atlas == null:
		return null
	if terrain < 0 or terrain > 3:
		terrain = 0
	return _terrain_atlas


func _terrain_at_index(arr: Array, x: int, y: int, default_value: int) -> int:
	var idx: int = y * grid_size + x
	if arr == null or idx < 0 or idx >= arr.size():
		return default_value
	return int(arr[idx])


func _bool_at_index(arr: Array, x: int, y: int, default_value: bool) -> bool:
	var idx: int = y * grid_size + x
	if arr == null or idx < 0 or idx >= arr.size():
		return default_value
	return bool(arr[idx])


func _clear_cells() -> void:
	for c in _cells:
		if is_instance_valid(c):
			c.queue_free()
	_cells.clear()


## Build a height seed-based terrain for the encounter. Matches
## CombatManager's `_build_height_map` RNG so visuals line up with
## the engine's reachability.
func build_terrain_for_encounter(encounter: Dictionary) -> Dictionary:
	var size: int = int(encounter.get("grid_size", grid_size))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(encounter.get("height_seed", 0))
	var terrain: Array = []
	var blocked: Array = []
	for y in range(size):
		for x in range(size):
			var roll: float = rng.randf()
			var t: int = 0
			if roll < 0.08:
				t = LocalMapGen.TERRAIN_BLOCKED
			elif roll < 0.25:
				t = LocalMapGen.TERRAIN_VEGETATION
			elif roll < 0.40:
				t = LocalMapGen.TERRAIN_DEBRIS
			else:
				t = LocalMapGen.TERRAIN_GROUND
			terrain.append(t)
			blocked.append(t == LocalMapGen.TERRAIN_BLOCKED)
	encounter["terrain_grid"] = terrain
	encounter["blocked_grid"] = blocked
	return encounter


func refresh_ranges(reachable: Array, attackable: Array, skillable: Array) -> void:
	for c in _cells:
		c.set_highlight(BattleCell.HIGHLIGHT_NONE)
	for pos in reachable:
		var cell := _get_cell(pos.x, pos.y)
		if cell != null:
			cell.set_highlight(BattleCell.HIGHLIGHT_MOVE)
	for pos in attackable:
		var cell := _get_cell(pos.x, pos.y)
		if cell != null:
			cell.set_highlight(BattleCell.HIGHLIGHT_ATTACK)
	for pos in skillable:
		var cell := _get_cell(pos.x, pos.y)
		if cell != null:
			cell.set_highlight(BattleCell.HIGHLIGHT_SKILL)


func clear_ranges() -> void:
	for c in _cells:
		c.set_highlight(BattleCell.HIGHLIGHT_NONE)


func _get_cell(x: int, y: int) -> BattleCell:
	if x < 0 or y < 0 or x >= grid_size or y >= grid_size:
		return null
	for c in _cells:
		if c.grid_x == x and c.grid_y == y:
			return c
	return null


func _spawn_units(encounter: Dictionary) -> void:
	var units: Array = encounter.get("units", []) as Array
	for u in units:
		_add_or_update_unit(u)


func _add_or_update_unit(unit: Dictionary) -> void:
	var uid: String = str(unit.get("id", ""))
	if uid.is_empty():
		return
	var bu: BattleUnit = _units.get(uid, null)
	if bu == null:
		bu = BattleUnitScript.new()
		bu.name = "Unit_%s" % uid
		_unit_layer.add_child(bu)
		_units[uid] = bu
	bu.setup_from_data(unit, CELL_SIZE)


func update_unit(unit: Dictionary) -> void:
	_add_or_update_unit(unit)


func move_unit_to(unit_id: String, x: int, y: int, tween: bool = true) -> void:
	var bu: BattleUnit = _units.get(unit_id, null)
	if bu == null:
		return
	bu.move_to(Vector2i(x, y), tween)


func remove_unit(unit_id: String) -> void:
	var bu: BattleUnit = _units.get(unit_id, null)
	if bu == null:
		return
	bu.queue_free()
	_units.erase(unit_id)


func _clear_units() -> void:
	for uid in _units:
		var bu: BattleUnit = _units[uid]
		if is_instance_valid(bu):
			bu.queue_free()
	_units.clear()


func get_battle_units() -> Array:
	var out: Array = []
	for uid in _units:
		var bu: BattleUnit = _units[uid]
		if is_instance_valid(bu):
			out.append(bu)
	return out


func get_battle_unit(unit_id: String) -> BattleUnit:
	return _units.get(unit_id, null)


func flash_unit(unit_id: String) -> void:
	var bu: BattleUnit = _units.get(unit_id, null)
	if bu != null:
		bu.flash_damage()


func play_unit_attack_swing(unit_id: String) -> void:
	var bu: BattleUnit = _units.get(unit_id, null)
	if bu != null:
		bu.play_attack_swing()


func set_active_unit(unit_id: String) -> void:
	for uid in _units:
		var bu: BattleUnit = _units[uid]
		if is_instance_valid(bu):
			bu.set_active(uid == unit_id)


func _on_cell_clicked(x: int, y: int) -> void:
	cell_clicked.emit(x, y)


func _on_cell_hovered(x: int, y: int, hovered: bool) -> void:
	cell_hovered.emit(x, y)
