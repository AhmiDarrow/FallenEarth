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
	var terrain: PackedByteArray = _map_data.get("terrain", PackedByteArray())
	var map_size: int = _map_data.get("size", 0)
	print("[LocalMapRenderer] configure: map_size=%d, terrain.size=%d, has_terrain=%s" % [map_size, terrain.size(), not terrain.is_empty()])
	if not terrain.is_empty():
		var blocked := 0
		var ground := 0
		for i in mini(terrain.size(), 1000):
			if terrain[i] == 3:
				blocked += 1
			elif terrain[i] == 0:
				ground += 1
		print("[LocalMapRenderer] First 1000 tiles: ground=%d blocked=%d" % [ground, blocked])
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

	var biome_name: String = str(_map_data.get("biome", "Ash Wastes"))
	var btm: BiomeTilesetManager = get_node_or_null("/root/BiomeTilesets") as BiomeTilesetManager
	var has_ts: bool = is_instance_valid(btm) and btm.has_tileset(biome_name)
	if has_ts:
		print("[LocalMapRenderer] Using Pixellab tileset for: %s" % biome_name)
	else:
		print("[LocalMapRenderer] No tileset for %s, using procedural tiles." % biome_name)

	var cells: Dictionary = {}
	var start_x := cx * CHUNK_CELLS
	var start_y := cy * CHUNK_CELLS
	var terrain_counts := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	for dy in CHUNK_CELLS:
		for dx in CHUNK_CELLS:
			var x := start_x + dx
			var y := start_y + dy
			var terrain: int = LocalMapGen.get_terrain(_map_data, x, y)
			terrain_counts[terrain] = terrain_counts.get(terrain, 0) + 1
			var local_key := LocalMapGen.local_key(x, y)

			# Build tile data with correct biome + terrain type
			var tile_data := {
				"biome": biome_name,
				"terrain_type": terrain,
			}

			# Ground cells: use Wang tile sprite if available
			if has_ts and terrain == LocalMapGen.TERRAIN_GROUND:
				var wang_id: int = _compute_wang_id(x, y, terrain)
				var tex: Texture2D = btm.get_tile(biome_name, wang_id)
				if tex:
					var spr := Sprite2D.new()
					spr.texture = tex
					spr.centered = false
					spr.position = Vector2(dx * CELL_SIZE, dy * CELL_SIZE)
					spr.scale = Vector2(float(CELL_SIZE - 1) / tex.get_width(), float(CELL_SIZE - 1) / tex.get_height())
					spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					chunk_root.add_child(spr)
					cells[local_key] = spr
					continue

			# Non-ground or fallback: procedural tile with correct biome/terrain
			var pt: ProceduralTile = ProceduralTile.new()
			pt.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
			pt.position = Vector2(dx * CELL_SIZE, dy * CELL_SIZE)
			pt.setup_for(tile_data)
			pt.name = "Tile_%d" % terrain
			chunk_root.add_child(pt)
			cells[local_key] = pt

	_loaded_chunks[ck] = {"root": chunk_root, "cells": cells}
	print("[LocalMapRenderer] Chunk (%d,%d) terrain: ground=%d debris=%d veg=%d blocked=%d rift=%d" % [
		cx, cy, terrain_counts.get(0, 0), terrain_counts.get(1, 0),
		terrain_counts.get(2, 0), terrain_counts.get(3, 0), terrain_counts.get(4, 0)
	])


func _compute_wang_id(x: int, y: int, terrain: int) -> int:
	var n: int = LocalMapGen.get_terrain(_map_data, x, y - 1)
	var e: int = LocalMapGen.get_terrain(_map_data, x + 1, y)
	var s: int = LocalMapGen.get_terrain(_map_data, x, y + 1)
	var w: int = LocalMapGen.get_terrain(_map_data, x - 1, y)
	return BiomeTilesetManager.compute_wang_id(terrain, n, e, s, w)


func _unload_chunk(ck: String) -> void:
	if not _loaded_chunks.has(ck):
		return
	var chunk: Dictionary = _loaded_chunks[ck]
	var root: Node = chunk.get("root") as Node
	if is_instance_valid(root):
		root.queue_free()
	_loaded_chunks.erase(ck)
