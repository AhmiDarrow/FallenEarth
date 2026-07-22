extends SceneTree

func _init():
	var TerrainSys = load("res://scripts/terrain/TerrainSystem.gd")
	var ts = TerrainSys.tileset_for_biome("Scorched Plains")
	var ac = TerrainSys.base_tile(TerrainSys.TERRAIN_WATER)
	var src = ts.get_source(0) as TileSetAtlasSource
	var region = src.get_tile_texture_region(ac)
	var tex = src.texture
	var img = tex.get_image()
	var sum=Vector3.ZERO; var n=0
	for y in range(region.position.y, region.position.y+region.size.y):
		for x in range(region.position.x, region.position.x+region.size.x):
			var c=img.get_pixel(x,y)
			if c.a>0.5:
				sum+=Vector3(c.r,c.g,c.b); n+=1
	if n>0: sum/=float(n)
	print("water_tile_rgb=", sum, " cool=", sum.z-(sum.x+sum.y)*0.5)
	var layer = TileMapLayer.new()
	layer.tile_set = ts
	layer.set_cell(Vector2i(0,0), 0, ac)
	print("readback=", layer.get_cell_atlas_coords(Vector2i(0,0)), " source=", layer.get_cell_source_id(Vector2i(0,0)))
	quit()
