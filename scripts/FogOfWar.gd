class_name FogOfWar
extends Node

signal cell_revealed(cell: Vector2i)

var _tilemap: TileMapLayer = null
var _map_size: Vector2i = Vector2i.ZERO
var _explored: Dictionary = {}
var _visible: Dictionary = {}
var _reveal_radius: int = 4
var _fog_atlas_coords: Vector2i = Vector2i.ZERO
var _fog_source_id: int = 0
var _fog_cell: Vector2i = Vector2i.ZERO


func setup(tilemap: TileMapLayer, map_width: int, map_height: int, reveal_radius: int = 4) -> void:
	_tilemap = tilemap
	_map_size = Vector2i(map_width, map_height)
	_reveal_radius = reveal_radius
	_explored.clear()
	_visible.clear()
	_update_fog_reference()
	_cover_all()


## Try to find the fog tile in the tilemap's tileset so we have the right
## atlas coords. If none exists, we don't paint fog (graceful fallback).
func _update_fog_reference() -> void:
	if not is_instance_valid(_tilemap) or not is_instance_valid(_tilemap.tile_set):
		return
	var src_count: int = _tilemap.tile_set.get_source_count()
	for si in src_count:
		var src := _tilemap.tile_set.get_source(si)
		if not (src is TileSetAtlasSource):
			continue
		var src_atlas := src as TileSetAtlasSource
		var tile_count: int = src_atlas.get_tile_count()
		if tile_count == 0:
			continue
		var first := src_atlas.get_tile_id(0)
		_fog_source_id = si
		_fog_atlas_coords = first
		return


func _cover_all() -> void:
	if not is_instance_valid(_tilemap):
		return
	for y in range(_map_size.y):
		for x in range(_map_size.x):
			_tilemap.set_cell(Vector2i(x, y), _fog_source_id, _fog_atlas_coords)


func reveal_around(cell: Vector2i) -> void:
	if not is_instance_valid(_tilemap):
		return
	var r := _reveal_radius
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := cell + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= _map_size.x or c.y >= _map_size.y:
				continue
			var dist := absi(dx) + absi(dy)
			if dist > r:
				continue
			_explored[_key(c)] = true
			_visible[_key(c)] = true
			_tilemap.erase_cell(c)
			cell_revealed.emit(c)


func is_explored(cell: Vector2i) -> bool:
	return _explored.has(_key(cell))


func is_visible(cell: Vector2i) -> bool:
	return _visible.has(_key(cell))


func clear_visibility() -> void:
	_visible.clear()


func full_reveal() -> void:
	if not is_instance_valid(_tilemap):
		return
	for y in range(_map_size.y):
		for x in range(_map_size.x):
			var c := Vector2i(x, y)
			_explored[_key(c)] = true
			_tilemap.erase_cell(c)


func is_fully_revealed() -> bool:
	return _explored.size() >= _map_size.x * _map_size.y


func get_explored_count() -> int:
	return _explored.size()


func get_total_cells() -> int:
	return _map_size.x * _map_size.y


static func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
