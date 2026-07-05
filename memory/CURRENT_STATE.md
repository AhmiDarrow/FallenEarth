# CURRENT STATE — Fallen Earth

**Version:** 0.4.0-dev
**Last Updated:** 2026-07-05
**Active Agent:** Remedy (Hermes)
**Current Phase:** Phase 5 of v0.4.0 complete (procedural NPC spawn + invite conditions)

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

### What changed in v0.4.0 Phase 1

**Goal:** Place 1-3 trees + 1-3 formations + 0-3 ore + 0-3 crystals + 0-3 fauna per biome on the local map, plus sticks and stones as floor pickups. Player presses E to gather. The full minute-1 progression loop: walk → pick up sticks/stones → craft Stone Axe or Stone Pickaxe → chop trees / mine ore.

### New data files
- `data/items.json` — 14 items: stick, stone, withered_branch, kelp_fibre, ironwood_bark, living_metal_sample, rusted_scrap, iron_ore, copper_ore, starmetal_ore, teal_crystal, void_shard, ember_crystal, bandage
- `data/resource_nodes.json` — 10 biomes × ~6 node entries; `floor_pickup_density` (stick 0.012, stone 0.018) for universal floor pickups
- `data/tools.json` — 8 tools: 2 stone tools (T0) + 3 axes (T1-T3) + 3 pickaxes (T1-T3)
- `data/recipes.json` — 3 recipes: stone_axe, stone_pickaxe, bandage (all station: none, L1)

### New scripts
- `scripts/HarvestNode.gd` + `scenes/HarvestNode.tscn` — gatherable resource entity; respects tool tier; respawn timer; sprite by name
- `scripts/FloorPickup.gd` + `scenes/FloorPickup.tscn` — small auto-pickup entity (stick, stone)
- `scripts/InventoryManager.gd` (autoload) — 30-slot stack-based inventory; `add_item`, `remove_item`, `get_count`, `has_item`; signals `inventory_changed`, `item_added`, `item_full`

### Modified
- `project.godot` — added `InventoryManager="*res://scripts/InventoryManager.gd"` autoload
- `scenes/LocalMapView.tscn` — added `NodeLayer` and `PickupLayer` (y-sorted) between Ground and MobLayer
- `scripts/LocalMapView.gd` — new `node_layer` and `pickup_layer` members; `_populate_resource_nodes` + `_populate_floor_pickups` from `map_data`; `get_resource_nodes_near` / `get_floor_pickups_near` / `get_floor_pickup_at` queries
- `scripts/LocalMapGenerator.gd` — `_emit_resource_nodes` + `_emit_floor_pickups` place nodes + pickups on walkable cells outside the spawn pocket; cached file-loaders for the JSON
- `scripts/HubWorld.gd` — `_try_start_gather` (E key, adjacent HarvestNode); `_tick_gather` (timer); `_try_collect_floor_pickup_at` (auto-pickup on walk); `_process` ticks gather timer + HarvestNode respawn; `_equipped_tool` placeholder for Phase 4's EquipmentManager
- `validate_scripts.gd` — added HarvestNode, FloorPickup, InventoryManager to the script list

### New tool scripts
- `tools/generate_nodes.py` — 39 unique resource node sprites + 1 generic fallback (procedural PIL)
- `tools/generate_floor_pickups.py` — 2 sprites (stick, stone)
- `tools/verify_assets.py` — phase-scoped asset verification; `--phase 1` checks tilesets, resource_nodes, floor_pickups
- `tools/smoke_resource_nodes.gd` — 7 test groups covering data loads, generator emission, view hosting, gather logic (incl. tool tier), pickup collect, inventory ops, respawn timer

### Phase 1 design notes
- **No tool gating in Phase 1:** without an EquipmentManager yet, the player has no way to "equip" a tool. The `HarvestNode.try_gather` API supports proper tool checking (stone_pickaxe only mines iron_outcrop, not copper), but `HubWorld` calls it with a `*` wildcard so bare-hands works for testing. Phase 4 (EquipmentManager + hotbar) will make tool equipping real and turn off the `*` fallback.
- **No respawn for floor pickups:** sticks and stones are single-shot per map. The 262k-cell Ash Wastes map gets ~5k-7k sticks and ~7k-10k stones — plenty to find. To revisit if the user finds the world too empty.
- **High node density:** total density across all categories is ~10% of walkable cells. Ash Wastes gets ~16k resource nodes. This may feel crowded; Phase 1 is a "make sure the system works" milestone. If F5 looks busy we'll trim densities in a follow-up.

### Validation
- `validate_scripts.gd` — All scripts and scenes OK
- `tools/smoke_tile_system.gd` — All checks passed
- `tools/smoke_resource_nodes.gd` — All 7 groups passed (data loads, generator emits, view hosts, gather logic w/ stone pickaxe, pickup collect, inventory ops, respawn timer)
- `tools/boot_probe.gd` — 60 frames, 0 errors
- `tools/verify_assets.py --phase 1` — all 3 categories ok

### What changed in v0.4.0 Phase 1b

**Goal:** Small Label that follows the mouse after a 1-second dwell, showing the name of whatever is under the cursor on the local map (terrain, resource node, mob, rift, NPC).

### New script
- `scripts/HoverTooltip.gd` — extends `Control`; tracks `_current_target` + `_hover_start_time`; 1s dwell (`DWELL_MS = 1000`); follows the mouse at `MOUSE_OFFSET = (14, 14)`; outline-styled text (white + 3px black outline) for legibility.

### Modified
- `scripts/HubWorld.gd` — `_setup_hover_tooltip` instantiates the tooltip and adds it to the HubWorld tree; `_tick_hover_tooltip` runs each frame in `_process`; `_hit_test_at_world(world_pos)` does the actual hit-testing with this priority order: resource node > floor pickup > mob marker > rift marker > NPC marker > terrain label. New helpers: `_terrain_label_at_cell`, `_mob_name_at_cell`, `_resolve_mob_display_name` (reads `data/mobs.json` for the display name), `_npc_name_at_hex`.
- `validate_scripts.gd` — added `HoverTooltip.gd` to the script list.

### New tooling
- `tools/smoke_hover_tooltip.gd` — 4 test groups: idle/empty hides label; 1s dwell before show; target change resets dwell; empty target hides visible tooltip.

### Hit-test priority
1. Resource node (highest priority — shows the node's display name, e.g. "Iron Outcrop")
2. Floor pickup (shows the item's display name from InventoryManager, e.g. "Stick")
3. Mob marker (looks up display name in `data/mobs.json`, e.g. "Blight Toad (Lv.3)")
4. Rift marker ("Rift")
5. NPC marker (NPC name from `_get_npc_at_hex`)
6. Mission marker ("Mission")
7. Terrain label ("Ground" / "Debris" / "Vegetation" / "Blocked") — always falls through here

The player's own cell is excluded (no point showing "Player" all the time).

### Validation
- `validate_scripts.gd` — All OK
- `tools/smoke_tile_system.gd` — All checks passed
- `tools/smoke_resource_nodes.gd` — All 7 groups passed
- `tools/smoke_hover_tooltip.gd` — All 4 groups passed
- `tools/boot_probe.gd` — 60 frames, 0 errors

### Next
- **Phase 2: full Character HUD + hotbar + minimap + inventory screen + mob drops + XP/EC** per `docs/PLAN_v040_crafting_progression.md` §4

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
