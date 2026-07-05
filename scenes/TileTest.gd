extends Node2D

const TileSetFactory = preload("res://scripts/TileSetFactory.gd")

func _ready():
	print("[TileTest] Starting tile test...")
	
	var tileset_data := TileSetFactory.create_for_biome("Ash Wastes")
	print("[TileTest] TileSet created: wang=%d, terrain=%d" % [tileset_data.wang_source_id, tileset_data.terrain_source_id])
	
	var tilemap := TileMapLayer.new()
	tilemap.tile_set = tileset_data.tileset
	tilemap.position = Vector2.ZERO
	add_child(tilemap)
	
	# Place test tiles
	if tileset_data.terrain_source_id >= 0:
		tilemap.set_cell(Vector2i(0, 0), tileset_data.terrain_source_id, Vector2i(0, 0), 0)
		tilemap.set_cell(Vector2i(1, 0), tileset_data.terrain_source_id, Vector2i(0, 1), 0)
		tilemap.set_cell(Vector2i(2, 0), tileset_data.terrain_source_id, Vector2i(0, 2), 0)
		tilemap.set_cell(Vector2i(3, 0), tileset_data.terrain_source_id, Vector2i(0, 3), 0)
		tilemap.set_cell(Vector2i(4, 0), tileset_data.terrain_source_id, Vector2i(0, 4), 0)
		print("[TileTest] Placed 5 test tiles in row 0")
	
	# Setup camera
	var camera := Camera2D.new()
	camera.position = Vector2(60, 12)
	camera.zoom = Vector2(4, 4)
	add_child(camera)
	camera.make_current()
	
	print("[TileTest] Test scene ready. Camera at (60, 12), zoom 4x")
