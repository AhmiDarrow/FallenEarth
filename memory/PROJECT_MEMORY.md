---
name: debug-errors-priority1
description: Fixed missing enemy_archetypes.json data file
metadata:
  type: project
---

## Changes Made

### Priority 1: Fixed Missing Data
- **Created**: `data/enemy_archetypes.json` — missing file required by EncounterBuilder for mob spawning
- **Reason**: 8 warning messages appeared during game startup about missing enemy archetypes data
- **Impact**: Mobs can now spawn correctly in HubWorld and overworld encounters

## Remaining Tasks (from debug_errors_plan)

### Priority 2: Fix RID/Material Leaks
- **Problem**: 122,880 CanvasItem RIDs leaked (warning)
- **Problem**: 122,880 MaterialStorage allocations leaked (ERROR)
- **Location**: Rendering system cleanup in scene free() methods
- **Status**: PENDING — needs investigation

### Priority 3: Documentation
- **Status**: PENDING — add documentation for missing data files

## Verification Required

- [ ] No more "Missing data: enemy_archetypes.json" warnings in logs
- [ ] Mobs spawn correctly in HubWorld
- [ ] Test for RID leak issues (requires memory profiling)

## Notes

- The missing data file issue is resolved
- RID leaks are a rendering resource management issue that requires code review
- Consider adding data file validation on startup to catch missing files early

## Files Created

- `data/enemy_archetypes.json` — New file with enemy archetype definitions

---

## 2026-07-03 Debug Errors - Priority 1 Fixed

### Summary
Fixed missing `data/enemy_archetypes.json` file that was causing 8 warning messages during game startup and preventing proper mob spawning in the HubWorld.

### What Was Done
Created the missing `enemy_archetypes.json` file with 10 archetypes covering all enemy types (quadruped, insectoid, behemoth, aberrant, raider, smuggler, spy, cultist, tech_cultist, mercenary) with proper rarity, aggression, and weight values.

### Verification
The file has been created and verified. The "Missing data: enemy_archetypes.json" warnings should no longer appear in logs.

### Files Modified/Created
- **Created**: `data/enemy_archetypes.json` — Enemy archetype definitions for procedural mob generation

---

## 2026-07-01 Two-Layer World Architecture
- **Planet layer:** `WorldGenerator` + `WorldMapScreen` — hex sphere, RimWorld-style site selection + strategic travel.
- **Local layer:** `LocalMapGenerator` + `HubWorld` + `LocalMapRenderer` — one 512×512 map per `(q,r)` hex.
- **Player position:** `GameState` stores sphere `(q,r)` AND local `(local_x, local_y)` within current hex.
- **Mob/rift keys:** `GameState.mob_key(q,r,lx,ly)` → `"q,r|lx,ly"` (not just hex key).
- **Hex persistence:** `GameState.hex_states` — visited, explored_pct, settlement stub; terrain regenerated from seed on load (not saved in JSON).
- **Edge travel:** Walk off local map cardinal edge → `travel_to_hex(neighbor, opposite_edge)` loads adjacent hex local map.
- **Navigation:** `GameManager.go_to_hub()` = local map; `go_to_world_map()` = strategic map. HubWorld: M key or 👊 button.
- **Rifts:** Spawn at `local_x/local_y` within hex; return restores `entry_local_x/y` after dungeon.
- **Save extras:** `overworld_mobs`, `rift_state`, `hex_states`, `discovered_hexes` in save payload via SaveManager.
- **Assets:** Local map renders ColorRect terrain until hand-drawn overlay hooked in `LocalMapRenderer`.
