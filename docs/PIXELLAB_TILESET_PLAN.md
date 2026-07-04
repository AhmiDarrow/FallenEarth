# Pixellab Tileset Integration Plan

**Created:** 2026-07-04
**Status:** Ready for implementation

## Summary

Generated 10 biome tilesets (160 Wang tiles total) via Pixellab MCP API.
Each biome has 16 tiles (16×16px) covering all corner combinations for seamless terrain transitions.

## Generated Assets

Location: `assets/tilesets/<biome_name>/wang_<id>.png`

| Biome | Tileset ID | Tiles |
|---|---|---|
| Ash Wastes | `35d4d8f3-...` | 16 |
| Rust Canyons | `ba5f7b58-...` | 16 |
| Neon Bogs | `d1bed1cd-...` | 16 |
| Scorched Plains | `ce5c30e6-...` | 16 |
| Ironwood Thicket | `e30773c4-...` | 16 |
| Glass Dunes | `e558d162-...` | 16 |
| Corpse Fields | `9a9c51f7-...` | 16 |
| Stormspire Highlands | `b9b53785-...` | 16 |
| Toxin Marshes | `3e2e0f3d-...` | 16 |
| Dead City Outskirts | `1240f10e-...` | 16 |

## Current System (Procedural Drawing)

- `ProceduralTile.gd` — Draws colored rectangles via `_draw()`, noise, biome patterns
- `LocalMapRenderer.gd` — Loads 32×32 cell chunks, each cell is a `ProceduralTile` (24px)
- `LocalMapGenerator.gd` — Generates 512×512 map data with terrain types
- Terrain is flat colored rectangles with procedural noise overlays

## Implementation Steps

### Step 1: Create BiomeTileset Resource Class

New file: `scripts/resources/BiomeTileset.gd`

```gdscript
class_name BiomeTileset
extends Resource

@export var biome_name: String
@export var tiles: Dictionary = {}  # wang_id (int 0-15) -> Texture2D

static func load_from_directory(path: String, biome_name: String) -> BiomeTileset:
    var res := BiomeTileset.new()
    res.biome_name = biome_name
    for i in 16:
        var tile_path := "%s/wang_%d.png" % [path, i]
        if ResourceLoader.exists(tile_path):
            res.tiles[i] = load(tile_path)
    return res

func get_tile_for_corners(nw: bool, ne: bool, sw: bool, se: bool) -> Texture2D:
    var wang_id := 0
    if nw: wang_id |= 8
    if ne: wang_id |= 4
    if sw: wang_id |= 2
    if se: wang_id |= 1
    return tiles.get(wang_id, null)
```

### Step 2: Create BiomeTilesetManager Autoload

New file: `scripts/BiomeTilesetManager.gd`

- Singleton/autoload that preloads all 10 biome tilesets on startup
- Maps biome name → BiomeTileset resource
- Provides `get_tile(biome, wang_id)` lookup
- Registers in `project.godot` as autoload

### Step 3: Modify LocalMapRenderer to Use Sprites

Modify: `scripts/LocalMapRenderer.gd`

Current: Creates `ProceduralTile` nodes that draw colored rectangles
New: Creates `Sprite2D` nodes with tileset textures

Key changes:
- Replace `ProceduralTile.new()` with `Sprite2D.new()`
- Look up correct Wang tile based on neighbor terrain comparison
- Scale 16×16 tiles to fit 24px cell size (or adjust CELL_SIZE to 16)
- Keep chunk loading/unloading system intact
- Biome comes from `_map_data.get("biome", "Ash Wastes")`

### Step 4: Implement Wang Tile Selection Logic

The 4-bit Wang ID is determined by comparing each corner's terrain type:
- Bit 3 (NW): top-left corner = upper terrain?
- Bit 2 (NE): top-right corner = upper terrain?
- Bit 1 (SW): bottom-left corner = upper terrain?
- Bit 0 (SE): bottom-right corner = upper terrain?

For each cell, check the 4 adjacent neighbors (N, E, S, W) and the cell itself to determine which corners are "upper" vs "lower" terrain.

### Step 5: Update ProceduralTile for Fallback

Modify: `scripts/procedural/ProceduralTile.gd`

- Keep procedural drawing as fallback when tileset images aren't available
- Add `use_tileset: bool` flag
- If tileset available, draw the Wang sprite instead of procedural rectangles

### Step 6: Optional — Tileset Atlas for Performance

For better performance, combine each biome's 16 tiles into a single atlas texture:
- Create `assets/tilesets/atlas_<biome>.png` (64×64, 4×4 grid)
- Use Godot's `AtlasTexture` to reference individual tiles
- Reduces texture switches from 16 per biome to 1

### Step 7: Add Biome Transition Support

For biome boundaries (e.g., where Ash Wastes meets Rust Canyons):
- Use Pixellab's chaining feature to generate transition tilesets
- Or blend two biome tilesets at runtime using alpha mixing
- Priority: implement single-biome rendering first, transitions later

## Godot Project Changes

### project.godot additions:
```
[autoload]
BiomeTilesetManager="*res://scripts/BiomeTilesetManager.gd"
```

### File structure after implementation:
```
assets/tilesets/
  ash_wastes/wang_0..15.png
  rust_canyons/wang_0..15.png
  ... (10 biomes)
scripts/
  resources/BiomeTileset.gd
  BiomeTilesetManager.gd
  LocalMapRenderer.gd (modified)
  procedural/ProceduralTile.gd (modified, fallback)
```

## Decision Points

1. **Cell size**: Keep 24px (scale 16px tiles up) or change to 16px (native tile size)?
   - Recommend: Keep 24px, scale tiles 1.5x for now. Change later if needed.

2. **Atlas vs individual files**: Individual files are simpler to start; atlas is better for performance.
   - Recommend: Start with individual files, optimize to atlas later.

3. **Biome transitions**: Hard boundary or blended?
   - Recommend: Hard boundary first (each cell uses its hex's biome), blend later.

## Testing

1. Load into HubWorld scene, verify tiles render correctly
2. Walk across map — tiles should change based on biome
3. Verify chunk loading/unloading still works
4. Compare performance vs procedural drawing
5. Check edge cases: rift cracks, exploration fog, markers still work on top
