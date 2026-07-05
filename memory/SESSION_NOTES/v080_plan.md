# v0.8.0 Plan — Phase A: Town Layout on Local Map

**Date:** 2026-07-05
**Goal:** When a hex contains a town, `LocalMapGenerator.generate()` places buildings, roads, and a clearing on the 512×512 tile map. Settlements become visible, walkable spaces on the local map instead of single-sprite markers.

---

## Current State (what we're changing)

- `LocalMapGenerator.generate()` returns `map_data["settlement"] = {"structures": [], "npcs": []}` — always empty
- `LocalMapView._populate_settlements()` reads `GameState.world_data.towns_seeded` and places one `SettlementNode` (Sprite2D + Label) per town at the hex coordinate
- When the player presses E near a `SettlementNode`, `SettlementManager` loads `Settlement.tscn` — a full-screen Control overlay with text lists
- Town hexes have the same terrain generation as wild hexes (no clearing, no buildings)
- **Bug:** `station_layer` is never assigned in `LocalMapView._ready()`, so cooking tables never appear

## Target State

- Town hexes have a procedural layout: central clearing, buildings around the edge, connecting paths
- Buildings are rendered as sprites on the `settlement_layer` with labels
- Player can walk up to a building and press E to enter the settlement interior
- Town hexes have no mob spawns (only guard NPCs)
- Different building types have distinct visual sprites

---

## Task A1: Extend `data/towns.json` with building definitions

**File:** `data/towns.json`

Add a `building_types` dictionary mapping each building name to its properties:

```json
{
  "building_types": {
    "tavern":        { "w": 3, "h": 3, "role": "innkeeper",    "sprite": "tavern" },
    "trader":        { "w": 3, "h": 3, "role": "trader",       "sprite": "trader" },
    "worktable":     { "w": 2, "h": 2, "role": "crafter",      "sprite": "worktable" },
    "armor_table":   { "w": 2, "h": 2, "role": "armorer",      "sprite": "armor_table" },
    "blacksmith":    { "w": 2, "h": 2, "role": "smith",        "sprite": "blacksmith" },
    "quest_board":   { "w": 1, "h": 1, "role": "quest_giver",  "sprite": "quest_board" },
    "faction_hq":    { "w": 4, "h": 3, "role": "faction_rep",  "sprite": "faction_hq" },
    "auction_house": { "w": 3, "h": 3, "role": "auctioneer",   "sprite": "auction_house" },
    "arena":         { "w": 5, "h": 5, "role": "trainer",      "sprite": "arena" }
  },
  "templates": { ... }
}
```

Each building has width/height in cells (for terrain marking), a role (for interaction), and a sprite ID (for loading the PNG).

---

## Task A2: Generate building sprites

**Files:** `tools/generate_building_sprites.py`, `assets/sprites/buildings/`

Generate 9 building sprites via PixelLab (or procedural PIL fallback). Each is a top-down view of the building footprint:
- 24×24 per cell (so a 3×3 building = 72×72 px sprite)
- Consistent style with existing tileset terrain

Building sprites needed:
1. `tavern.png` — 3×3, warm interior glow
2. `trader.png` — 3×3, market stall / counter
3. `worktable.png` — 2×2, crafting bench
4. `armor_table.png` — 2×2, armor rack
5. `blacksmith.png` — 2×2, anvil + forge
6. `quest_board.png` — 1×1, wooden notice board
7. `faction_hq.png` — 4×3, fortified building
8. `auction_house.png` — 3×3, grand hall
9. `arena.png` — 5×5, open fighting ring

---

## Task A3: Town layout generator in `LocalMapGenerator.gd`

**File:** `scripts/LocalMapGenerator.gd`

Add a new static function `_generate_town_layout()` that is called from `generate()` when the hex contains a town.

### Algorithm

```
_generate_town_layout(rng, buildings: Array, building_types: Dictionary, terrain, occupied, spawn):
  1. Clear a central circular clearing (radius ~15 cells) to TERRAIN_GROUND
  2. Place a ring road around the clearing (TERRAIN_DEBRIS, 1-cell wide path)
  3. For each building in the buildings array:
     a. Look up w/h from building_types
     b. Pick a position on the ring road (evenly spaced around the circle)
     c. Place the building footprint as TERRAIN_BLOCKED in terrain[]
     d. Mark those cells in occupied[]
     e. Record the building's position, size, and entrance cell in the structures array
  4. Add guard NPC spawn points (2-4 positions near the clearing edge)
  5. Return the structures array and mark town cells as occupied
```

### Integration into `generate()`

```gdscript
# After spawn pocket clear, before cooking table:
var town_data: Dictionary = _get_town_for_hex(q, r)
if not town_data.is_empty():
    var structures: Array = _generate_town_layout(rng, town_data, terrain, occupied, Vector2i(cx, cy))
    map_data["settlement"]["structures"] = structures
    map_data["settlement"]["town_data"] = town_data
    # Skip mob emission for town cells (handled by marking occupied)
```

### New helper: `_get_town_for_hex(q, r)`

Reads from a cached copy of `world_data.towns_seeded` (loaded once, stored in a static variable). Returns the town dict if this hex has a town, or `{}` if not.

### Modified: `_emit_resource_nodes()` and `_emit_floor_pickups()`

These already respect the `occupied[]` array, so buildings placed by the town layout will automatically exclude resource nodes and pickups from building footprints. No changes needed.

### Modified: mob emission

Mobs are currently spawned by a separate system (not by LocalMapGenerator). The town boundary needs to be communicated so mob spawning avoids town cells. Add `map_data["settlement"]["boundary"]` — a `Rect2i` representing the town's bounding box (clearing + buildings). The mob spawner can check this.

---

## Task A4: Building scene and rendering in `LocalMapView.gd`

**Files:** `scripts/SettlementBuilding.gd` (new), `scenes/SettlementBuilding.tscn` (new), `scripts/LocalMapView.gd`

### New: `SettlementBuilding` scene

A `Node2D` with:
- `Sprite2D` — loads from `assets/sprites/buildings/{sprite_id}.png`
- `Label` — building name (e.g. "Tavern"), positioned below the sprite
- `Area2D` — for interaction detection (player enters area → E-key prompt)
- Properties: `building_id`, `role`, `entrance_cell`

### Modified: `LocalMapView._populate_settlements()`

Instead of (or in addition to) placing `SettlementNode` sprites, read `map_data["settlement"]["structures"]` and instantiate `SettlementBuilding` for each structure.

The existing `SettlementNode` stays as the "town center" marker (the ★ on the map). Buildings are additional sprites on the same `settlement_layer`.

### Modified: `LocalMapView.get_settlement_at()`

Extend to also check `SettlementBuilding` children (not just `SettlementNode`), so the player can interact with individual buildings.

### New: `get_building_at(cell: Vector2i) -> Node2D`

Hit-test that returns the `SettlementBuilding` at a given cell, if any.

---

## Task A5: Fix `station_layer` bug

**File:** `scripts/LocalMapView.gd`

Add to `_ready()`:
```gdscript
station_layer = get_node_or_null("StationLayer") as Node2D
```

This is a one-line fix that makes cooking tables actually appear on the map.

---

## Task A6: Town boundary for mob exclusion

**Files:** `scripts/LocalMapGenerator.gd`, `scripts/HubWorld.gd`

After generating the town layout, compute a `Rect2i` bounding box that encompasses the clearing + all buildings. Store it in `map_data["settlement"]["boundary"]`.

**Mob spawning location found:** `HubWorld._seed_mobs_for_hex()` (line ~1390) generates 2-5 mobs per hex. It picks random cells in range [20, MAP_SIZE-20], checks terrain walkability, checks Manhattan distance from player < 12, and checks for duplicates.

**Fix:** Add a town-boundary check to `_seed_mobs_for_hex()`:
```gdscript
# After the "near player" check (line 1415):
var town_bnd: Variant = _local_map.get("settlement", {}).get("boundary", null)
if town_bnd is Rect2i and town_bnd.has_point(Vector2i(lx, ly)):
    skipped_blocked += 1
    continue
```

This ensures no mobs spawn inside the town clearing or on building footprints.

---

## Task A7: Wire building interaction in HubWorld

**File:** `scripts/HubWorld.gd`

When the player presses E near a `SettlementBuilding`:
- If the building has a `role` that maps to a known UI (trader → ShopInterface, quest_board → MissionBoardInterface), open that UI directly
- Otherwise, enter the settlement interior (current SettlementManager flow) focused on that building

Modify `_try_enter_settlement()` to check for adjacent buildings first, then fall back to the settlement center.

---

## Task A8: Smoke test

**File:** `tools/smoke_settlement_interior.gd` (new)

Test groups:
1. Town layout generation — verify structures are placed for each template size
2. Building placement — verify buildings don't overlap and are within map bounds
3. Terrain marking — verify building footprints are TERRAIN_BLOCKED
4. Occupied array — verify building cells are marked occupied
5. SettlementBuilding scene — verify it loads and instantiates
6. LocalMapView integration — verify buildings appear on settlement_layer
7. Town boundary — verify the bounding box encompasses all structures

---

## Execution Order

1. **A1** (towns.json) — data first, no code dependencies
2. **A2** (building sprites) — can run in parallel with A1
3. **A5** (station_layer fix) — quick win, unblocks cooking tables
4. **A3** (town layout generator) — core algorithm, depends on A1
5. **A4** (building rendering) — depends on A2, A3
6. **A6** (town boundary) — depends on A3
7. **A7** (building interaction) — depends on A4
8. **A8** (smoke test) — depends on all above

---

## Risks & Open Questions

1. **Building sprite generation:** PixelLab can generate these, but we need to ensure consistent scale and style with the existing 24×24 terrain tiles. Procedural PIL fallback is available if PixelLab results are inconsistent.
2. **Settlement interior scope:** Phase B will replace the text-list interior with a spatial view. Phase A's buildings on the local map are the prerequisite — the player sees buildings from the outside, presses E to enter.
3. **Performance:** Adding 3-9 building sprites per town hex is negligible compared to the 262k terrain cells.
4. **Backward compatibility:** Existing saves with `map_data["settlement"] = {"structures": [], "npcs": []}` will continue to work — the empty structures array means no buildings are rendered, and the old SettlementNode flow is preserved as fallback.
