# Procedural Map Improvements — Landscape Coherence

## The Problem

Both the **overworld local maps** (512×512 per hex) and **rift instances** use per-cell
independent random noise to determine terrain. This produces speckled "random noise" rather
than coherent landscapes with recognizable features (lakes, forests, clearings, rocky badlands).

### Root Causes

| System | File:Lines | Issue |
|--------|-----------|-------|
| Overworld terrain | `LocalMapGenerator.gd:80-91` | `n := rng.randf()` per cell — each cell is independent |
| Overworld tiles | `TileSetService.gd` | 1 tile per terrain type, no edge blending |
| World biome assignment | `WorldGenerator.gd:115-135` | `_rng.randf()` elevation noise no coherence |
| Rift (large) | `RiftDungeonGenerator.gd:109-128` | sin×cos FBM produces blobby noise, no clear features |
| Rift (small) | `RiftDungeonGenerator.gd:76-104` | Uniform 1-cell corridor maze |

### What Exists

- **10 biomes**, each with 5 tiles (ground/debris/vegetation/blocked/rift) — 64×64 PNG -> 24×24
- **FastNoiseLite** already used in `MaterialLibrary.gd:145` — proven, no new dependency
- **Resource nodes** (trees, ore, formations) spawn AFTER terrain — compatible with noise placement
- **TileSet** uses Godot 4 built-in TileMapLayer — supports terrain system

---

## Phase 1: Noise-based Overworld Terrain (HIGH priority)

File: `LocalMapGenerator.gd` (line 77-91 replacement)

**Replace `n := rng.randf()` with 2-layer FastNoiseLite:**

```
landscape_noise  = FastNoiseLite.new()  # fractal Simplex, freq~0.008, 3 octaves
detail_noise     = FastNoiseLite.new()  # fractal Simplex, freq~0.03, 2 octaves
```

Each noise seeded with `hash_seed(local_seed + "landscape")` for determinism.

**Mapping noise → terrain per biome:**

| Biome | Ground | Vegetation | Debris | Blocked (water/cliff) |
|-------|--------|------------|--------|----------------------|
| Scorched Plains | 0.0-0.60 | 0.60-0.75 | 0.75-0.88 | 0.88-1.0 |
| Ash Wastes | 0.0-0.45 | 0.45-0.60 | 0.60-0.85 | 0.85-1.0 |
| Neon Bogs | 0.0-0.25 | 0.25-0.45 | 0.45-0.65 | 0.65-1.0 |
| Ironwood Thicket | 0.0-0:30 | 0.30-0.65 | 0.65-0.80 | 0.80-1.0 |
| Rust Canyons | 0.0-0.40 | 0.40-0.55 | 0.55-0.78 | 0.78-1.0 |
| Glass Dunes | 0.0-0.55 | 0.55-0.70 | 0.70-0.85 | 0.85-1.0 |
| Corpse Fields | 0.0-0.50 | 0.50-0.65 | 0.65-0.85 | 0.85-1.0 |
| Toxin Marshes | 0.0-0.20 | 0.20-0.40 | 0.40-0.60 | 0.60-1.0 |
| Stormspire Highlands | 0.0-0.35 | 0.35-0.50 | 0.50-0.70 | 0.70-1.0 |
| Dead City Outskirts | 0.0-0.40 | 0.40-0.55 | 0.55-0.75 | 0.75-1.0 |

Thresholds are adjusted by hex-level `rain` and `elev` (existing params from WorldGenerator).

**Result:** Neighboring cells get similar noise values -> coherent blobs of terrain.
Lakes (blocked) form continuous bodies, forests (vegetation) form groves.

---

## Phase 2: Edge-aware Auto-Tiling (MEDIUM priority)

File: `TileSetService.gd` + `LocalMapView.gd`

**Approach:** Add a second TileMapLayer for edge transitions, or use Godot 4's
built-in terrain system on the TileSet.

### Option A — Simple Edge Band (Recommended v1)

After terrain generation, detect cells where terrain type changes:
- Walk the grid, mark cells adjacent to a different terrain type
- Assign these edge cells a special terrain value
- In TileSetService, generate edge tiles procedurally:
  - For each terrain pair (e.g., GROUND→BLOCKED), generate blended tile
  - Blend = 50% each tile, with the dominant terrain's pixel pattern

### Option B — Godot 4 Terrain System

Configure TileSet with terrain sets (2+ terrains per set), assign each tile
a terrain bitmask. Enable auto-tiling on TileMapLayer. This requires:
- 4-9 tile variants per terrain type per biome (36+ tiles per biome)
- Better to generate these via PixelLab

**For v1:** Use Option A (procedural edge tiles, ~5 lines of noise-edge detection).

---

## Phase 3: Rift Dungeon Improvements (MEDIUM priority)

File: `RiftDungeonGenerator.gd` + `RiftTileSetService.gd` + `RiftMapView.gd`

### 3a — Noise Terrain Replacement

Replace `_fbm()` (sin×cos) at line 117 with FastNoiseLite:
- `FastNoiseLite.TYPE_SIMPLEX_SMOOTH`, freq=0.04, 4 octaves
- Seeded per rift_id for deterministic dungeons

### 3b — Variable Corridor Width (small mazes)

Modify recursive-backtracker to occasionally carve 2-3 cell wide corridors:
- 20% chance per step: carve a 2-wide passage instead of 1-wide
- Add occasional 3×3 dead-end chambers during maze generation

### 3c — Better Room Variety (large rifts)

After noise threshold, carve explicit rooms:
- Place 3-8 rooms (5% of map area) as rectangular clearings
- Connect rooms with the existing connectivity pass
- Buffer room edges with decor tiles

---

## Phase 4: Biome-specific Terrain Profiles (LOW priority)

File: `data/biomes.json` or new `data/terrain_profiles.json`

Add terrain generation parameters per biome:
```json
"terrain_profile": {
  "noise_freq": 0.008,
  "noise_octaves": 3,
  "ground_range": [0.0, 0.50],
  "vegetation_range": [0.50, 0.68],
  "debris_range": [0.68, 0.82],
  "blocked_range": [0.82, 1.0],
  "water_fill": 0.08,
  "clump_size": 6
}
```

This allows tuning each biome independently without code changes.

---

## Phase 5: Rift Map Chunking (LOW priority)

File: `RiftMapView.gd`

For rifts > 256×256:
- Divide ground into 64×64 chunks
- Only paint visible chunks
- Track dirty chunks and update on explore
- Use TileMapLayer with partial updates

Current system paints the full 512×512 in one pass — Godot handles it but
fog-of-war plus markers plus entity placement can slow down.

---

## Implementation Order

1. **Phase 1** (noise terrain) — biggest visual impact, no new assets needed
2. **Phase 3a** (rift noise) — fast win, same pattern
3. **Phase 2** (edge tiles) — polish visual transitions
4. **Phase 3b/c** (rift variety) — gameplay improvement
5. **Phase 4** (profiles) — balance tuning, ongoing
6. **Phase 5** (chunking) — performance, as needed
