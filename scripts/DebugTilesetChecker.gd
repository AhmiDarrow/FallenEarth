## DebugTilesetChecker — Run in editor to verify Wang tile selection.
extends Node

func _ready() -> void:
    var btm: BiomeTilesetManager = get_node_or_null("/root/BiomeTilesets") as BiomeTilesetManager
    if not is_instance_valid(btm):
        print("BiomeTilesets not available!")
        return
    
    print("Loaded tilesets: ", btm._tilesets.keys())
    
    # Check a few tiles exist and their sizes
    for biome in btm.BIOME_DIR_MAP:
        if btm.has_tileset(biome):
            var tex0: Texture2D = btm.get_tile(biome, 0)
            var tex15: Texture2D = btm.get_tile(biome, 15)
            if tex0 and tex15:
                print("%s: tile0=%dx%d tile15=%dx%d" % [biome, tex0.get_width(), tex0.get_height(), tex15.get_width(), tex15.get_height()])
            else:
                print("%s: MISSING tiles!" % biome)
        else:
            print("%s: NO TILESET" % biome)
    
    # Test Wang ID computation
    var G := 0  # GROUND
    var D := 1  # DEBRIS
    var V := 2  # VEGETATION
    var B := 3  # BLOCKED
    var R := 4  # RIFT_SCAR
    
    # Solid ground (all neighbors match)
    print("Solid ground (all G): wang_id=%d (expect 15)" % BiomeTilesetManager.compute_wang_id(G, G, G, G, G))
    
    # Isolated ground (all neighbors different)
    print("Isolated ground (surrounded by D): wang_id=%d (expect 0)" % BiomeTilesetManager.compute_wang_id(G, D, D, D, D))
    
    # Edge: ground with debris to the east
    print("Edge E (G with D east): wang_id=%d" % BiomeTilesetManager.compute_wang_id(G, G, D, G, G))
    
    # Corner: ground with debris to north and east
    print("Corner NE (G with D north+east): wang_id=%d" % BiomeTilesetManager.compute_wang_id(G, D, D, G, G))
    
    queue_free()
