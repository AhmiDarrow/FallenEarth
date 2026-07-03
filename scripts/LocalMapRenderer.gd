## LocalMapRenderer — Chunked viewport renderer for 512×512 local maps.
## Loads/unloads 64×64 cell chunks around the player; reuses CanvasTexture nodes.
class_name LocalMapRenderer
extends Node2D

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const ProceduralTile = preload("res://scripts/procedural/ProceduralTile.gd")

const CELL_SIZE := 24
const CHUNK_CELLS := 32
const VIEW_RADIUS := 18

var _map_data: Dictionary = {}
var _loaded_chunks: Dictionary = {}  # "cx,cy" -> { cells: Dictionary }
var _player_cell := Vector2i.ZERO


func configure(map_data: Dictionary) -> void:
	_map_data = map_data.duplicate(true)
	_clear_all_chunks()


func set_player_cell(x: int, y: int) -> void:
	_player_cell = Vector2i(x, y)
	_refresh_view()


func get_cell_size() -> int:
	return CELL_SIZE


func _clear_all_chunks() -> void:
	for key in _loaded_chunks.keys():
		_unload_chunk(str(key))
	_loaded_chunks.clear()


func _refresh_view() -> void:
	if _map_data.is_empty():
		return

	var min_x := _player_cell.x - VIEW_RADIUS
	var max_x := _player_cell.x + VIEW_RADIUS
	var min_y := _player_cell.y - VIEW_RADIUS
	var max_y := _player_cell.y + VIEW_RADIUS

	var needed: Dictionary = {}
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cx := _chunk_coord(x)
			var cy := _chunk_coord(y)
			var ck := "%d,%d" % [cx, cy]
			needed[ck] = true
			if not _loaded_chunks.has(ck):
				_load_chunk(cx, cy)

	for ck in _loaded_chunks.keys():
		if not needed.has(ck):
			_unload_chunk(ck)


func _chunk_coord(cell: int) -> int:
	return int(floor(float(cell) / float(CHUNK_CELLS)))


func _load_chunk(cx: int, cy: int) -> void:
	var ck := "%d,%d" % [cx, cy]
	var chunk_root := Node2D.new()
	chunk_root.name = "Chunk_%s" % ck
	chunk_root.position = Vector2(cx * CHUNK_CELLS * CELL_SIZE, cy * CHUNK_CELLS * CELL_SIZE)
	add_child(chunk_root)

	var cells: Dictionary = {}
	var start_x := cx * CHUNK_CELLS
	var start_y := cy * CHUNK_CELLS
	for dy in CHUNK_CELLS:
		for dx in CHUNK_CELLS:
			var x := start_x + dx
			var y := start_y + dy
			var terrain: int = LocalMapGen.get_terrain(_map_data, x, y)
			var local_key := LocalMapGen.local_key(x, y)
			var tile: Dictionary = _map_data.get(local_key, {}) as Dictionary
			var tile_key := "%d,%d" % [terrain, tile.get("terrain_type", 0)]
			var pt: ProceduralTile = ProceduralTile.new()
			pt.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
			pt.position = Vector2(dx * CELL_SIZE, dy * CELL_SIZE)
			pt.setup_for(tile)
			pt.name = "Tile_%s" % tile_key
			chunk_root.add_child(pt)
			cells[local_key] = pt

	_loaded_chunks[ck] = {"root": chunk_root, "cells": cells}


func _unload_chunk(ck: String) -> void:
	if not _loaded_chunks.has(ck):
		return
	var chunk: Dictionary = _loaded_chunks[ck]
	var root: Node = chunk.get("root") as Node
	if is_instance_valid(root):
		root.queue_free()
	_loaded_chunks.erase(ck)
