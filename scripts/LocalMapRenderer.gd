## LocalMapRenderer — Chunked sprite renderer for 512×512 local maps.
## Uses Sprite2D nodes with proper tile alignment (no gaps).
class_name LocalMapRenderer
extends Node2D

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const BiomeTilesetMgr = preload("res://scripts/BiomeTilesetManager.gd")

const CELL_SIZE := 24
const CHUNK_CELLS := 32
const VIEW_RADIUS := 18

var _map_data: Dictionary = {}
var _loaded_chunks: Dictionary = {}
var _player_cell := Vector2i.ZERO
var _biome_name: String = ""
var _tile_textures: Dictionary = {}


func configure(map_data: Dictionary) -> void:
	_map_data = map_data.duplicate(true)
	_biome_name = str(_map_data.get("biome", "Ash Wastes"))
	_clear_all_chunks()
	_load_tile_textures()


func set_player_cell(x: int, y: int) -> void:
	_player_cell = Vector2i(x, y)
	_refresh_view()


func get_cell_size() -> int:
	return CELL_SIZE


func is_cell_walkable(x: int, y: int) -> bool:
	return LocalMapGen.get_movement_cost(_map_data, x, y) >= 0


func _load_tile_textures() -> void:
	var biome_dir: String = BiomeTilesetMgr.BIOME_DIR_MAP.get(_biome_name, "")
	if biome_dir.is_empty():
		print("[LocalMapRenderer] No biome dir for: %s" % _biome_name)
		return

	var base_path := "res://assets/tilesets/%s" % biome_dir

	var ground_path := "%s/ground.png" % base_path
	var ground_tex := load(ground_path) as Texture2D
	if ground_tex:
		_tile_textures[LocalMapGen.TERRAIN_GROUND] = ground_tex
	else:
		print("[LocalMapRenderer] FAILED to load ground tile: %s" % ground_path)

	var debris_tex := load("%s/debris.png" % base_path) as Texture2D
	if debris_tex:
		_tile_textures[LocalMapGen.TERRAIN_DEBRIS] = debris_tex

	var vegetation_tex := load("%s/vegetation.png" % base_path) as Texture2D
	if vegetation_tex:
		_tile_textures[LocalMapGen.TERRAIN_VEGETATION] = vegetation_tex

	var blocked_tex := load("%s/blocked.png" % base_path) as Texture2D
	if blocked_tex:
		_tile_textures[LocalMapGen.TERRAIN_BLOCKED] = blocked_tex

	var rift_tex := load("%s/rift.png" % base_path) as Texture2D
	if rift_tex:
		_tile_textures[LocalMapGen.TERRAIN_RIFT_SCAR] = rift_tex

	print("[LocalMapRenderer] Loaded %d tile textures for %s" % [_tile_textures.size(), _biome_name])


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
	var sprite_count := 0

	for dy in CHUNK_CELLS:
		for dx in CHUNK_CELLS:
			var x := start_x + dx
			var y := start_y + dy
			var terrain: int = LocalMapGen.get_terrain(_map_data, x, y)
			var local_key := LocalMapGen.local_key(x, y)

			var tex: Texture2D = _tile_textures.get(terrain, null)
			if tex:
				var spr := Sprite2D.new()
				spr.texture = tex
				spr.centered = false
				spr.position = Vector2(dx * CELL_SIZE, dy * CELL_SIZE)
				# Scale to ensure tiles fill cell exactly (no gaps)
				var scale_x := float(CELL_SIZE) / float(tex.get_width())
				var scale_y := float(CELL_SIZE) / float(tex.get_height())
				spr.scale = Vector2(scale_x, scale_y)
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				chunk_root.add_child(spr)
				cells[local_key] = spr
				sprite_count += 1

	_loaded_chunks[ck] = {"root": chunk_root, "cells": cells}


func _unload_chunk(ck: String) -> void:
	if not _loaded_chunks.has(ck):
		return
	var chunk: Dictionary = _loaded_chunks[ck]
	var root: Node = chunk.get("root") as Node
	if is_instance_valid(root):
		root.queue_free()
	_loaded_chunks.erase(ck)
