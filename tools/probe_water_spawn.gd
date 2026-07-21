extends SceneTree
const LocalMapGen = preload('res://scripts/LocalMapGenerator.gd')
func _initialize() -> void:
    var biome_tile := {'name': 'Scorched Plains', 'elevation': 0.5, 'rainfall': 0.5, 'rift_chance': 0.25}
    var m = LocalMapGen.generate('test', 0, 0, biome_tile)
    var terrain: PackedByteArray = m.get('terrain', PackedByteArray())
    var water = 0; var node_on_water = 0; var node_on_ground = 0; var decor_on_water = 0; var decor_on_ground = 0
    var by_terrain := {}
    for n in m.get('resource_nodes', []):
        if n.get('x', -1) < 0: continue
        var t = int(terrain[n.y * int(m.get('size', 512)) + n.x])
        if t == 4: node_on_water += 1
        elif t == 0: node_on_ground += 1
    for d in m.get('decor', []):
        if d.get('x', -1) < 0: continue
        var t = int(terrain[d.y * int(m.get('size', 512)) + d.x])
        if t == 4: decor_on_water += 1
        elif t == 0: decor_on_ground += 1
    for i in range(terrain.size()):
        if int(terrain[i]) == 4: water += 1
    print('  resource_nodes on water: %d, on ground: %d' % [node_on_water, node_on_ground])
    print('  decor on water: %d, on ground: %d' % [decor_on_water, decor_on_ground])
    print('  total water tiles: %d / %d (%0.1f%%)' % [water, terrain.size(), float(water)/float(terrain.size())*100.0])
    quit(0)
