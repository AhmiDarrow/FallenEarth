extends SceneTree
func _init():
	var G=load("res://scripts/LocalMapGenerator.gd")
	var md=G.generate("test",428,0,{"name":"Scorched Plains","elevation":0.5,"rainfall":0.5,"rift_chance":0.25})
	var t=md.terrain; var sz=int(md.size)
	var c={0:0,1:0,2:0,3:0,4:0}
	for y in range(200,260):
		for x in range(200,260):
			c[int(t[y*sz+x])]=int(c.get(int(t[y*sz+x]),0))+1
	print("60x60 counts", c)
	# print terrain glyphs around 238,224 water=W ground=. debris=d blocked=B
	for y in range(220,250):
		var row=""
		for x in range(220,250):
			var v=int(t[y*sz+x])
			row += "W" if v==4 else ("B" if v==3 else ("d" if v==1 else ("v" if v==2 else ".")))
		print(row)
	quit()
