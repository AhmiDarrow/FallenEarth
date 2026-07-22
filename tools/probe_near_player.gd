extends SceneTree

func _init() -> void:
	var TerrainSys = load("res://scripts/terrain/TerrainSystem.gd")
	var LocalMapGen = load("res://scripts/LocalMapGenerator.gd")
	var biome_tile := {"name": "Scorched Plains", "elevation": 0.5, "rainfall": 0.5, "rift_chance": 0.25}
	var md: Dictionary = LocalMapGen.generate("test", 428, 0, biome_tile)
	var t: PackedByteArray = md.terrain
	var sz: int = int(md.size)
	var px := 238; var py := 224
	print("map_size=", sz, " player_area terrain dump 40x30 around ", px, ",", py)
	var counts := {0:0,1:0,2:0,3:0,4:0}
	for y in range(maxi(0,py-20), mini(sz, py+20)):
		var row := ""
		for x in range(maxi(0,px-20), mini(sz, px+20)):
			var v := int(t[y*sz+x])
			counts[v] = int(counts.get(v,0))+1
			row += str(v)
		print(row)
	print("counts near player ", counts)
	var best_d := 99999; var best := Vector2i(-1,-1)
	for y in sz:
		for x in sz:
			if int(t[y*sz+x]) != 4: continue
			var d: int = absi(x-px)+absi(y-py)
			if d < best_d: best_d = d; best = Vector2i(x,y)
	print("nearest water ", best, " dist ", best_d)
	TerrainSys.tileset_for_biome("Scorched Plains")
	var bw: Vector2i = TerrainSys.base_tile(4)
	var bg: Vector2i = TerrainSys.base_tile(0)
	print("bases g=", bg, " w=", bw)
	var minx:=sz; var miny:=sz; var maxx:=0; var maxy:=0; var wc:=0
	for y in sz:
		for x in sz:
			if int(t[y*sz+x])==4:
				wc+=1
				minx=mini(minx,x); miny=mini(miny,y); maxx=maxi(maxx,x); maxy=maxi(maxy,y)
	print("water bbox ", minx,",",miny,"-",maxx,",",maxy," n=",wc)
	quit()
