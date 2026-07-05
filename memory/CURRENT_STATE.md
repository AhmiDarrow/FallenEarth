# CURRENT STATE — Fallen Earth

**Version:** 0.4.0-dev
**Last Updated:** 2026-07-05
**Active Agent:** Remedy (Hermes)
**Current Phase:** Phase 0 of v0.4.0 complete (drop rift_scar tile)

## Summary

The entire local-map tile pipeline has been rewritten on Godot 4.3's
`TileMapLayer` + `TileSet` + `TileSetAtlasSource` API. All old wang-tile code
and the sprite-chunk renderer are gone, along with the procedural
`_make_circle_texture` marker draw. Fifty new terrain tiles (10 biomes × 5
terrain types) were generated via PixelLab and now render as a native
TileMapLayer at 24×24 px cells.

`MobVisual` is rewritten to render the 64×64 mob sprite at native size (no
scale-down hack) parented to a y-sorted `MobLayer`, so mob visibility is no
longer dependent on a half-size trick.

## Playable Flow (intended — unchanged)

```
Splash → MainMenu → WorldGeneration (pick start hex)
  → CharacterSelection → HubWorld (local 512×512 map)
      → WASD + edge-cross between hex regions
      → M / 🗺 → WorldMapScreen (adjacent travel, faction/quest/rift markers)
      → ⚡ on local map → RiftInstance → close → back to entry local pos
      → ★ NPC settlement (walk near marker) → recruit / missions
```

## Key Systems

| System | Status | Key Files |
|--------|--------|-----------|
| Hex sphere world gen | ✅ | `WorldGenerator.gd`, `WorldGeneration.tscn` |
| Strategic world map | ✅ | `WorldMapScreen.gd`, `WorldMapScreen.tscn` |
| Local 512×512 maps (TileMapLayer) | ✅ | `LocalMapGenerator.gd`, `LocalMapView.gd`, `LocalMapView.tscn` |
| TileSet build per biome | ✅ NEW v0.3.0 | `TileSetService.gd` |
| Hex state + travel | ✅ | `GameState.gd` (`hex_states`, `travel_to_hex`) |
| Rifts (local coords) | ✅ | `RiftRunner.gd`, `RiftInstance.gd` |
| Tactical combat (FFT) | ✅ | `TacticalCombat.gd`, `CombatManager.gd` |
| Missions (local mobs) | ✅ | `MissionManager.gd` |
| Save/load (world layer) | ✅ | `GameState.gd`, `SaveManager.gd` |
| Display options | ✅ | `DisplayManager.gd`, `Options.gd`, `scenes/ui/Options.tscn` |
| Hand-drawn tiles | ✅ NEW v0.3.0 | `assets/tilesets/{biome}/{terrain}.png` — 50 files via PixelLab |
| Mob sprites (visible) | ✅ v0.2.0 round 2 | `assets/mobs/{id}.png` — 27 mobs |
| Settlement building | ⏳ | Not started — `hex_state.settlement` stub in generator |

## What changed in v0.4.0 Phase 0

**Goal:** Remove the orange "rift scars" from the terrain. Rifts are now entities (spawned by `RiftRunner`), shown as ⚡ markers on the local map. The terrain atlas goes from 5 rows to 4.

### Removed
- `TERRAIN_RIFT_SCAR` constant from `LocalMapGenerator.gd` and `TileSetService.gd`
- `rift_scar` row from `TileSetService.TERRAIN_NAMES` and the `TileSetAtlasSource` (atlas is now 24×96, was 24×120)
- `TERRAIN_RIFT_SCAR` match arms in `LocalMapGenerator.get_terrain_movement_cost`, `terrain_color` (dead code, fully removed), and `terrain_label`
- `rift_scar` emission branch in `LocalMapGenerator.generate` — the probability budget that was 0.34–0.40 now falls into the ground `else` branch
- Dead code: `LocalMapGenerator.terrain_color` (entire function removed; was unused after the sprite-renderer removal in v0.3.0)
- All `assets/tilesets/*/rift_scar.png` files (10 total)

### Backward compatibility
- Any legacy `map_data` with `terrain[i] == 4` (the old rift_scar value) is **normalized to `TERRAIN_GROUND`** by `LocalMapView.configure()`. Smoke test verifies this.
- The historical value 4 is documented in `TileSetService` and `LocalMapGenerator` as a comment so future maintainers understand why the normalization exists.

### Updated
- `scripts/TileSetService.gd` — 4 rows in atlas, 4 tile creates
- `scripts/LocalMapGenerator.gd` — no rift emission, no rift_scar match arms
- `scripts/LocalMapView.gd` — normalizes out-of-range terrain values
- `tools/generate_tiles.py` — `RENDERERS` no longer has rift_scar; `total_expected` computed dynamically from `len(RENDERERS)`
- `tools/smoke_tile_system.gd` — explicitly tests legacy rift_scar=4 normalization
- `backups/.gdignore` — keeps the backups folder out of Godot's class registry (prevents duplicate `class_name` errors from the older scripts that lived in pre-v0.3.0 backups)
- `.gitignore` — excludes `backups/` from version control

### Validation
- `validate_scripts.gd` — All scripts and scenes OK
- `tools/smoke_tile_system.gd` — All checks passed (10 biome TileSets, MobVisual load, LocalMapView configure with legacy rift_scar=4 normalized to ground, HubWorld instantiate)
- `tools/boot_probe.gd` — 60 frames, 0 errors

### Next
- **Phase 1: Resource nodes + gathering + tool-tier gating + sticks/stones** (per `docs/PLAN_v040_crafting_progression.md`)

**Deleted in v0.3.0 follow-up** (3D material remnants surfaced by F5):
- `data/sources/materials/material3d_mesh_*.tres.gd` × 9 — broken scripts that did `extends Material3D` (not a real Godot 4 class); produced 9 "Parse Error: Closing } doesn't have an opening counterpart" lines on every boot.
- `scripts/_material3d.gd` — orphan that declared `var material3d_mesh_*: Material3D` and triggered the scan of the broken source scripts above.
- `tools/generate_materials.gd` — the tool that produced the broken scripts.
- `data/sources/` and `data/materials/` — empty after the deletes; folders removed.

F5 boot log is now clean: 0 parse errors. The remaining `tileset.py` 2-line stub in `scripts/` is unrelated to the draw system and is intentionally left in place.

**Deleted** (old draw tile system):
- `scripts/LocalMapRenderer.gd` (chunked sprite renderer)
- `scripts/BiomeTilesetManager.gd` (wang-tile loader, was autoloaded as `BiomeTilesets`)
- `scripts/TileSetBuilder.gd` (`@tool` curator, scanned `selected/` subdirs)
- `scripts/TileSetFactory.gd` (procedural-fallback TileSet builder)
- `scenes/TileTest.tscn` / `scenes/TileTest.gd`
- `assets/tilesets/*` (10 biome folders with old 16-wang-tile atlases)
- `BiomeTilesets` autoload entry in `project.godot`
- `_visual_tile_cache` / `get_visual_tile` / `get_tile_visual` in `WorldGenerator.gd`
- `_make_circle_texture` procedural draw in `HubWorld.gd`

**Added** (Godot 4.3 native):
- `scripts/TileSetService.gd` — `create_for_biome(name)` returns a `TileSet` with one
  `TileSetAtlasSource` (5 vertical-strip tiles, 24×120 px atlas), BLOCKED tile has a
  full-cell collision polygon on physics layer 0.
- `scenes/LocalMapView.tscn` + `scripts/LocalMapView.gd` — `Node2D` with
  `Ground` (TileMapLayer), `MobLayer` (y-sorted), `MarkerLayer`.
- `assets/tilesets/{biome_dir}/{terrain}.png` × 50 files, generated via
  `tools/generate_tiles.py` (PixelLab pixflux, 5 concurrent workers, ~10 s each).

**Rewritten**:
- `scripts/MobVisual.gd` — sprite at native 64×64 (no `scale = Vector2(0.5, 0.5)`),
  parented to `MobLayer` so the y-sort stacks entities correctly.
- `scripts/HubWorld.gd` — uses `LocalMapView`; markers use `LocalMapView.add_marker`
  (ColorRect + Label); mobs use new `MobVisual`.

**Tooling**:
- `tools/generate_tiles.py` — idempotent, 5 workers, supports `--biome` and `--force`.
- `tools/smoke_tile_system.gd` — `-s` script that loads all 10 biome TileSets,
  configures a 4×4 `LocalMapView`, instantiates a `MobVisual`, and instantiates
  the full `HubWorld.tscn`. Run: `godot --headless -s tools/smoke_tile_system.gd`.
- `tools/boot_probe.gd` — boots `MainMenu.tscn` for 60 frames, reports runtime
  errors. Run: `godot --headless -s tools/boot_probe.gd`.

## Validation

```powershell
# Compile check
& "C:\Users\Administrator\godot\Godot_v4.3-stable_win64.exe" --headless `
   --path "C:\Users\Administrator\FallenEarth" -s validate_scripts.gd

# Tile system smoke test (10 biomes + view + mob + hub)
& "C:\Users\Administrator\godot\Godot_v4.3-stable_win64.exe" --headless `
   --path "C:\Users\Administrator\FallenEarth" -s tools/smoke_tile_system.gd

# MainMenu boot probe (60 frames, no input)
& "C:\Users\Administrator\godot\Godot_v4.3-stable_win64.exe" --headless `
   --path "C:\Users\Administrator\FallenEarth" -s tools/boot_probe.gd
```

Last runs:
- `validate_scripts.gd` — **All scripts and scenes OK.**
- `smoke_tile_system.gd` — **All 4 test groups pass; 0 errors.**
- `boot_probe.gd` — **60 frames observed, no fatal errors.**

## Next Session Priorities

1. **F5 visual playthrough** — confirm tiles render and mobs are visible at full size.
2. **Per-biome tile QA** — open each biome in F5; replace any tile that looks
   too dark or too similar to neighbours via `tools/generate_tiles.py --biome <x> --force`.
3. **Settlement building** — `hex_state.settlement` is a stub in `LocalMapGenerator`.

## Asset budget

- PixelLab Tier 2 (Pixel Artisan) — 4770 generations remaining (was 5000).
- v0.3.0 used 50 generations (10 biomes × 5 terrain types).
