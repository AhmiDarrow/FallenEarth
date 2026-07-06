# CURRENT STATE — Fallen Earth

**Version:** 0.11.0
**Last Updated:** 2026-07-06 14:00
**Active Agent:** Remedy (Hermes)
**Current Phase:** v0.11.0 Combat Architecture Rewrite — COMPLETE.

## Summary

v0.11.0 "Combat Architecture Rewrite" complete. Three rounds of
polish (v0.10.5 → v0.11) hadn't fixed the visual issues, and the
god-class architecture (TacticalCombat.gd 800+ lines,
CombatManager.gd 1500+ lines) made the system hard to maintain.
Rebuilt the combat system using the Resource/Service/Module
pattern from `ramaureirac/godot-tactical-rpg`:
  - 4 Resources (TileResource, UnitResource, ParticipantResource,
    ArenaResource) for data + state
  - 6 Services (PathfindingService, TurnService, UnitMovement,
    UnitCombat, PlayerService, OpponentService) for logic
  - 4 Modules (CombatTile, CombatUnit, CombatArena, CombatLevel)
    for scene tree
  - 2 UI panels (TopPrompt, ActionBar) — the other 3 deferred

Backward compatible: old BattleCell/GridView/Unit + TacticalCombat
scene still work, old encounter format auto-converted. To switch,
replace TacticalCombat.tscn reference with CombatLevel.tscn.

## v0.10.10 details

**Layout revert:**
- `BattleGridView.cell_to_world(x, y) -> (x*40 + 20, y*40 + 20)` —
  no more 2:1 iso projection.
- `BattleCell` no longer draws a `Polygon2D` diamond floor; the
  cell IS the terrain sprite (a 40x40 scaled `Sprite2D` with
  `TEXTURE_FILTER_NEAREST`).
- `BORDER_THICKNESS` = 1 (was 3; on 40px cells the chunky 3px
  line read as busy).
- `COLOR_MOVE` = cyan `Color(0.30, 0.85, 1.0, 0.40)` (v0.10.11:
  was white/0.22 — invisible against light sand/ground).
- `DECOR_COUNT` = 14 (was 22), grid_rect buffer = 50px (v0.10.11:
  was 60px sized for the 392px grid; now sized for 280px).

**Always-visible cell borders (v0.10.10 polish):**
- `BattleCell._highlight_border.visible = true` by default (was
  `false` — only shown on ATTACK/SKILL). Default border color is
  `Color(0.18, 0.16, 0.12, 0.55)` (dim warm gray) so the grid
  structure reads at a glance without overwhelming the terrain.
- `set_highlight` no longer toggles border visibility — it just
  swaps the border color: ATTACK → red, SKILL → purple, MOVE/
  CURSOR/NONE → dim warm gray.

**Size-aware unit sprite scaling (v0.10.10 polish, v0.10.11 retuned):**
- `BattleUnit._load_sprite` no longer hard-codes `scale = 0.7x`.
- v0.10.10: target_px = 46 (~82% of 56px cell).
- v0.10.11: target_px = 32 (~80% of 40px cell).
- Result: 128x128 human at 0.25x = 32px (was 0.7x = 89.6px in v0.10.5,
  overflowed the 56px cell). 64x64 mob at 0.5x = 32px.

**Legacy right-side action bar hidden:**
- `TacticalCombat._ready()` now sets
  `legacy_main.visible = false` and
  `legacy_actions.visible = false` so the right-side action
  buttons (which the bottom action bar + SkillBar + TopPrompt
  all replaced) stop bleeding into the middle of the screen.

**Unit + HP-bar positioning:**
- `BattleUnit.setup_from_data` places units at the cell center.
- `CombatFeedback.setup_hp_bars` positions HP bars at the cell
  center, offset 24px up.

**v0.10.11 grid sizing:**
- CELL_SIZE 56 → 40 across BattleGridView, BattleCell, BattleUnit.
- 7×7 grid = 280px (~22% of 1280 viewport), fits cleanly between
  the TopPrompt (top) and bottom ActionBar/SkillBar (60px clear
  above, 60px clear below).

## Smoke tests

| File | Checks | Status |
|------|--------|--------|
| `validate_scripts.gd` | All | All OK |
| `tools/smoke_combat_v100.gd` | 27 (Phase 1) | All pass |
| `tools/smoke_combat_ai.gd` | 11 (Phase 2) | All pass |
| `tools/smoke_combat_ui.gd` | 15 (Phase 3) | All pass |
| `tools/smoke_combat_feedback.gd` | 4 (feedback) | All pass |
| `tools/smoke_combat_polish.gd` | 30 (Polish + v0.10.10 + v0.10.11) | All pass |
| `tools/smoke_combat_blockers.gd` | All | All pass |
| `tools/boot_combat.gd` | full scene boot | All pass |

## v0.10.1 polish details

**New components:**
- `scripts/combat/UnitSelectionArrow.gd` — cyan down-arrow above active unit
- `scripts/combat/TopPrompt.gd` — top-center styled prompt ("Select a white tile to move")
- `scripts/combat/UnitNamePlate.gd` — white-bg name labels above units

**BattleBackground overhaul:** replaced 18-tile debris/vegetation scatter
with 22 biome-themed decor props (boulders, skulls, cacti, rubble, thorns,
stumps, roots). 7 new decor types × 3-4 variants = 25 PNGs in
`assets/battle_decor/`.

**BattleCell polish:** HIGHLIGHT_MOVE = soft white tint; HIGHLIGHT_ATTACK/
HIGHLIGHT_SKILL = border-only frames so ground shows inside.

**TacticalCombat:** new `_build_bottom_action_bar()` creates a dedicated
bottom-center HBox with styled End Turn + Retreat buttons. New
`_style_action_button()` / `_style_finish_button()` apply chunky
metal styleboxes. Legacy MainVBox labels (status/turn_order/instructions/
log) hidden — replaced by TopPrompt + TurnOrderBar + UnitInfoCard + SkillBar.

**New assets (25 PNGs):**
- `assets/battle_ui/`: selection_arrow, top_prompt_panel, name_plate_panel,
  button_red/blue/grey/gold (7 new files)
- `assets/battle_decor/`: boulder ×4, skull ×3, cactus ×4, rubble ×4,
  thorns ×4, stump ×3, roots ×3 (18 PNGs total)
- `tools/generate_battle_decor_imports.py` — generates .import files
  for headless workflows (Godot rewrites them on next editor import).

## Smoke tests

| File | Checks | Status |
|------|--------|--------|
| `tools/smoke_combat_v100.gd` | 27 (Phase 1) | All pass |
| `tools/smoke_combat_ai.gd` | 11 (Phase 2) | All pass |
| `tools/smoke_combat_ui.gd` | 15 (Phase 3) | All pass |
| `tools/smoke_combat_polish.gd` | NEW v0.10.1 — 7 groups | All pass |
| `tools/boot_combat.gd` | NEW v0.10.1 — full scene boot | All pass |
| `validate_scripts.gd` | All | All OK |

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
| Save/load (all managers) | ✅ NEW v0.8.0 Phase H | `GameState.gd`, `SaveManager.gd` — aggregates + restores inventory, progression, party, equipment, base, base_shops |
| Display options | ✅ | `DisplayManager.gd`, `Options.gd`, `scenes/ui/Options.tscn` |
| Hand-drawn tiles | ✅ NEW v0.3.0 | `assets/tilesets/{biome}/{terrain}.png` — 50 files via PixelLab |
| Mob sprites (visible) | ✅ v0.2.0 round 2 | `assets/mobs/{id}.png` — 27 mobs |
| Settlement buildings on map | ✅ NEW v0.8.0 | `SettlementBuilding.gd` + `assets/sprites/buildings/` — 9 building types, procedural layout |
| Spatial settlement interiors | ✅ NEW v0.8.0 | `SettlementInterior.gd` + `RoomView.gd` + `data/settlement_rooms.json` — room system, WASD, NPC visuals, E-key |
| Settlement interior visuals | ✅ NEW v0.8.0 Phase C | NPC character sprites (AtlasTexture), biome floor textures, faction wall accents |

## What changed in v0.8.0 Phase A

**Goal:** Procedural town layout on local map. When a hex contains a town, buildings, roads, and a clearing are placed on the 512×512 tile map.

### New files
- `scripts/SettlementBuilding.gd` + `scenes/SettlementBuilding.tscn` — building entity on local map
- `tools/generate_building_sprites.py` — procedural PIL generator for 9 building sprites
- `tools/smoke_settlement.gd` — 10-group smoke test
- `assets/sprites/buildings/*.png` — 9 building sprites (tavern, trader, worktable, armor_table, blacksmith, quest_board, faction_hq, auction_house, arena)

### Modified
- `data/towns.json` — added `building_types` section (9 entries with w/h/role/sprite/label)
- `scripts/LocalMapGenerator.gd` — town layout generator: clearing (radius 15), ring road, building placement, path drawing, boundary computation. `generate()` now populates `map_data["settlement"]` with structures + boundary
- `scripts/LocalMapView.gd` — `_populate_buildings()`, `get_building_at()`, `get_map_data()`, `_clear_buildings()`. Fixed `station_layer` bug (was never assigned)
- `scripts/HubWorld.gd` — mob boundary check in `_seed_local_mobs()`, `_adjacent_building()`, `_interact_building()`, `_open_shop_interface()`, `_open_mission_board()`

### Algorithm
1. Clear circular clearing (radius 15) at map center
2. Place buildings evenly spaced on ring road (radius ~19)
3. Mark footprints as TERRAIN_BLOCKED + occupied
4. Draw debris paths from entrances to clearing
5. Compute Rect2i boundary for mob exclusion

### Validation
- `tools/smoke_settlement.gd` — 10/10 pass
- `validate_scripts.gd` — All scripts and scenes OK
- `tools/smoke_tile_system.gd` — All checks pass (no regression)

## What changed in v0.8.0 Phase B

**Goal:** Replace text-list settlement interior with spatial room system. Player walks between connected rooms, sees NPCs as visual entities, interacts via E-key.

### New files
- `data/settlement_rooms.json` — 10 room definitions (town_square + 9 building interiors). Each: 12×10 grid (#=wall, .=floor, X=exit), NPC placements, exit connections.
- `scripts/RoomView.gd` — Room renderer: ColorRect per cell, NPC visuals (colored dot + name label), collision queries (is_wall, is_exit, get_npc_at, get_exit_near, is_settlement_exit_near).
- `scripts/SettlementInterior.gd` — Main controller: WASD movement (0.12s cooldown), E-key dispatch (exit→switch room, NPC→interact, settlement exit→leave), room transitions, NPC interactions by role (trader→Shop, quest_giver→MissionBoard, others→greeting dialog).
- `scenes/SettlementInterior.tscn` — Scene container.
- `tools/smoke_interior.gd` — 10-group smoke test.

### Modified
- `scripts/SettlementManager.gd` — `SETTLEMENT_SCENE` changed to `SettlementInterior.tscn`. `enter_settlement()` accepts `focus_building` param, passes to `interior.setup()`.
- `scripts/HubWorld.gd` — `_interact_building()` passes `bld_id` to `sm.enter_settlement()` and `_try_enter_settlement()`.
- `validate_scripts.gd` — Added SettlementInterior.tscn, SettlementInterior.gd, RoomView.gd.

### Design
- Room size: 12×10 cells at 24px/cell (288×240 pixels)
- Color-coded tiles: wall=#1a1a2e, floor=#2a2a3e, exit=#2a5a3e
- NPCs: colored dots with name labels (future: character sprites)
- Grid-based collision (no physics)
- Room transitions instant (old RoomView freed, new created)
- E-key priority: room exit > settlement exit > NPC interaction
- Backward compatible: old Settlement.gd exists but no longer loaded

### Validation
- `tools/smoke_interior.gd` — 10/10 pass
- `tools/smoke_settlement.gd` — 10/10 pass (no regression)
- `tools/smoke_tile_system.gd` — 4/4 pass (no regression)
- `validate_scripts.gd` — All scripts and scenes OK

## What changed in v0.8.0 Phase C

**Goal:** Add visual variety to settlement interiors — NPC character sprites, biome floor textures, faction-themed wall accents.

### Modified
- `scripts/RoomView.gd` — NPC colored dots replaced with character sprite frames (AtlasTexture extracts south-facing 16x16 from 128x128 spritesheets). Biome ground tiles render as floor texture (Sprite2D). 11 faction wall accent colors applied to top/bottom wall rows.
- `scripts/SettlementInterior.gd` — Extracts `biome` and `faction` from town_data, passes to RoomView.setup().
- `data/settlement_rooms.json` — Added `race` field to all 10 NPC entries for sprite selection.
- `tools/smoke_interior.gd` — Added 4 Phase C test groups (race fields, sprite loading, biome textures, faction accents). Total: 14 groups.

### Design
- Character sprites: 128x128 sheet, 8 directions, 16x16 per frame. South = row 0, col 0. Scaled 1.4x for 24px cells.
- Biome floors: 24x24 ground tiles from `assets/tilesets/{biome}/ground.png`. TEXTURE_FILTER_NEAREST for crisp pixel art.
- Faction accents: top/bottom wall rows use faction color, side walls stay dark. Subtle differentiation.
- Fallback: if sprite/biome missing, falls back to colored dot / solid color (backward compatible).

### Validation
- `tools/smoke_interior.gd` — 14/14 pass (10 Phase B + 4 Phase C)
- `tools/smoke_settlement.gd` — 10/10 pass (no regression)
- `tools/smoke_tile_system.gd` — All pass (no regression)
- `validate_scripts.gd` — All scripts and scenes OK

## What changed in v0.8.0 Phase H

**Goal:** Wire BaseManager + BaseShopManager into GameState save/load so base state persists across sessions.

### Modified
- `scripts/GameState.gd` `save_game()` — Added `sm.populate_payload_with_managers(data)` call to include manager snapshots (inventory, progression, party, equipment, base, base_shops) in the save payload.
- `scripts/GameState.gd` `load_game()` — Added `sm.apply_managers_from_payload(data)` call to restore manager state from the save payload on load.
- `tools/smoke_phase8.gd` — Added `_test_base_manager_round_trip()` test group: places base, sets level/residents/name, opens shop, snapshots, clears, restores, verifies all state preserved.

### Validation
- `tools/smoke_phase8.gd` — 5/5 pass (aggregate_snapshot, restore_all, round-trip, populate+apply, BaseManager round-trip)
- `validate_scripts.gd` — All scripts and scenes OK

## What changed in v0.7.1 P0 polish

**Goal:** Fix faction theme data for correct NPC race spawning in settlements.

### Modified
- `data/joinable_npc_templates.json` — Fixed `preferred_race: "vespers"` → `"vesperid"` (5 factions). Renamed `race_pref` → `origin_pref` (clearer). Fixed invalid origins "Independent"/"Neutral" → proper "Upworld"/"Underworld".
- `scripts/PartyNPCManager.gd` — Renamed `race_pref` variable to `origin_pref`. Added `preferred_race` variable. Removed dead "Independent"/"Neutral" check. Updated comments.

### Validation
- `tools/smoke_interior.gd` — 14/14 pass
- `tools/smoke_v070.gd` — 12/12 pass
- `validate_scripts.gd` — All OK

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
