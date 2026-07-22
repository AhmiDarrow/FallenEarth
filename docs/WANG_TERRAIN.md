# Terrain System — v0.13.0 Architecture

## Overview

Single unified terrain pipeline replacing the old three-layer system.
One class (`TerrainSystem`) owns tile loading, atlas building, and vertex-Wang painting.

## Architecture

```
TerrainSystem.gd (single class, ~300 lines)
  ├── Constants: terrain types (0-4), biome dirs, PixelLab pair defs
  ├── Loading: PixelLab Wang metadata+PNG → single atlas TileSet
  ├── Painting: vertex grid → binary pair projection → atlas lookup → TileMapLayer
  └── Fallback: ground_64.png single-texture mode for biomes without wang/ data

LocalMapGenerator.gd (~550 lines, simplified)
  └── Generates terrain byte array (512×512) via noise-based layering
      (height → rivers → lakes → paths → rock → smoothing → towns)

LocalMapView.gd (~340 lines, simplified)
  └── Delegates tile painting to TerrainSystem.paint_terrain()
      Manages entity layers (resources, pickups, decor, buildings)
```

## Core Design

### Binary pair projection (the key simplification)

Each PixelLab Wang pair maps exactly TWO terrain types (e.g., debris↔ground).
When a cell's corners contain 3+ different terrain types, we project to a
binary pair by finding the most common non-cell-type corner terrain.

```
resolve_tile(cell_terrain, nw, ne, sw, se):
  1. Try exact match in tile map
  2. Count corner terrains, find dominant non-cell type
  3. Project all corners to (cell_terrain, dominant_other) binary pair
  4. Fall back to base tile for cell_terrain
```

No priority-based projection. No special water cases. No unused variant system.

### Vertex grid

Each vertex is the simple majority (count) of the 4 adjacent cells.
No weighted priority — just count which terrain appears most often.

### Removed systems

- `ground_variant` — unused micro-variants system
- `edge_mask` — unused edge bitmask computation
- `_pair_projections()` priority chain — replaced by simple majority
- `_vertex_terrain_majority()` weighted priority — replaced by simple count
- Shade/tint/cliff procedural overlays — raw PixelLab art only
- Excessive smoothing passes (6 → 2 water shore passes)

## Stable Terrain IDs

| ID | Name       | Role |
|----|------------|------|
| 0  | ground     | Majority floor (PixelLab upper) |
| 1  | debris     | Paths / gravel |
| 2  | vegetation | Patches |
| 3  | blocked    | Rock / impassable |
| 4  | water      | Water / impassable |

## PixelLab Pair Definitions

| Stem       | lower → upper    |
|------------|------------------|
| primary    | debris → ground  |
| g_debris   | debris → ground  |
| g_veg      | debris → vegetation |
| g_water    | water → ground   |
| g_blocked  | blocked → ground |

Cliff water tilesets (25-tile) are ingested for their transitional shore tiles only.
Solid fills always come from the standard 16-tile pairs.

## Cell Size

- **CELL_SIZE = 64** (native PixelLab). No downscaling.
- Overworld entities use 64px grid. Rifts may use 32px.

## Biome Coverage

| Status | Count |
|--------|-------|
| Full Wang data (wang/ folder) | 1 (Scorched Plains) |
| ground_64.png fallback | 9 (all others) |

Non-Scorched biomes render with solid ground_64 textures until PixelLab Wang
tilesets are generated for them. The system auto-detects: wang/ folder → full
corner matching; otherwise → ground_64 fallback.

## File Map

| File | Role |
|------|------|
| `scripts/terrain/TerrainSystem.gd` | Tile constants, loading, atlas, painting |
| `scripts/LocalMapGenerator.gd` | Terrain generation (noise layering) |
| `scripts/LocalMapView.gd` | Scene rendering + entity management |
| `tools/wang_biome_map.json` | Terrain IDs, pair stems, PixelLab prompts |
| `tools/pixellab_tileset_catalog.json` | Inventory of existing PixelLab tilesets |
| `assets/tilesets/<biome>/wang/<stem>_metadata.json` | PixelLab tile metadata |
| `assets/tilesets/<biome>/wang/<stem>_image.png` | PixelLab tile sprite sheet |
