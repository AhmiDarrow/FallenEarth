---

## [Unreleased — v0.9.1c] — Performance pass

- **v0.9.1c** — Four independent bottlenecks fixed; gameplay now
  feels snappy:
  - `GameState` hex-state deep copies were duplicating 262k bytes of
    terrain + 5714 nested dicts on every move. Switched to shallow
    `duplicate(false)` in `get_hex_state`, `get_current_hex_state`,
    `ensure_hex_state`, and `save_hex_state`. Per-move call:
    25 ms → 0.35 ms (**71x**).
  - Per-node Sprite2D creation in `HarvestNode._ready` and
    `FloorPickup._ready` was loading 5714 textures on chunk load
    (16k+ resource nodes + 7.8k pickups in v0.9.1b). Removed
    per-node Sprite2D. Chunk load: 7490 ms → 195 ms (**38x**).
    Resource/pickup densities in `data/resource_nodes.json`
    quartered in tandem (16k → 3.7k nodes, 7.8k → 1.97k pickups).
    ⚠️ **Note:** trees, rocks, ore, crystals, fauna, sticks, and
    stones are no longer visible on the overworld — TODO is to
    re-add visuals via MultiMesh batching.
  - `HubWorld._build_local_view` was clearing and rebuilding all
    marker/mob/NPC sprites on every move. Added `_world_markers_dirty`
    flag, set only on actual state changes. Movement is now
    marker-free.
  - `LocalMapView.get_floor_pickup_at` / `get_resource_nodes_near`
    iterated all 5714 layer children per call. Added
    `_node_by_cell` / `_pickup_by_cell` Dictionary indexes for
    O(1) cell lookups and O(K²) near queries.
  - `HubWorld._process` was iterating 16k+ resource nodes per frame
    to call their `_process(delta)` for respawn timers. Now iterates
    only the small `_active_respawn_nodes` list.
  - `tools/perf_profile.gd` — new test with 4 budgets: configure
    < 300 ms, frame time < 16.67 ms, per-move call < 5 ms.

## [Unreleased — v0.9.1b] — Combat blockers fix

- **v0.9.1b** — Combat is now testable end-to-end. Two blockers fixed:
  - `scenes/RiftInstance.tscn` — six child nodes had relative `parent="<short-name>"` paths
    (`GridContainer`, `EndTurnButton`, `ClearRiftButton`, `BackButton`, `LootTitle`, `LootLabel`).
    In Godot 4 these are scene-root-relative paths, not sibling names, so the children
    were silently orphaned and the rift UI was broken. Fixed to the full path
    (`MainVBox/GridPanel`, `MainVBox/ActionsHBox`, `MainVBox/LootPanel`).
  - Overworld mob visibility — bumped density from 2-9 to 8-20 mobs per hex
    (`scripts/HubWorld.gd` `_seed_local_mobs`); added a guaranteed "near-spawn" pass
    that places 2 mobs within 3-20 cells of the player on initial hex entry; reduced
    cell exclusion from 5 to 2 cells; reduced initial rift spawn distance from
    8-20 to 4-12 cells with bounds clamping.
  - `scripts/ui/Minimap.gd` — added a 80×50 px bottom-left inset showing the local
    map around the player with red dots for hostile mobs, gray-green for neutral,
    so the player can navigate toward fights without scrolling the world.
  - `scripts/HubWorld.gd` `_update_tile_info` — surfaces mob count + nearest mob
    distance in the bottom-left tile info label.
  - `tools/smoke_combat_blockers.gd` — 7 test groups, all pass (12 mobs seeded,
    nearest 15 cells from player).

## [Unreleased — Step 12] — Bug fix round

- **Step 12** — Resolved all compile errors in the procedural generation stack:
  - `scripts/ProceduralMob.gd`: created from scratch with clean class definition and procedural creature rendering.
  - `scripts/ProceduralTile.gd`: cleaned up to remove parse errors.
  - `scripts/CombatEncounterBuilder.gd` (renamed from `EncounterBuilder.gd`): rewritten with proper `class_name` and `extends RefCounted`.
  - `scripts/NPCManager.gd`: verified no parse errors.
  - `scripts/DisplayManager.gd`: trailing comma fix reported.

- **`CHANGELOG.md`** — added entry for Step 12.

## [Unreleased — Step 7] — ProceduralTile detail shaders

- **Step 7** — `scripts/ProceduralTile.gd` detail shaders added:
  - Rocks shader: when `has_rocks` is true, a rocks detail shader is rendered with dark gray tint.
  - Vegetation shader: when `has_vegetation` is true, a vegetation detail shader is rendered with green tint.
  - Both shaders use seeded dot sampling to match the detail-dots shader.

- **`CHANGELOG.md`** — added entry for Step 7.

## [Unreleased — Step 8] — ProceduralMob integration into NPCManager & EncounterBuilder

- **Step 8** — Procedural drawing fallbacks wired into NPCManager and EncounterBuilder:
  - `scripts/NPCManager.gd`:
    - Added `_build_procedural_mob(npc_data: Dictionary) -> Dictionary` helper that constructs a proto dict (archetype, color, size) from NPC data.
    - Modified `generate_for_world` to call `_build_procedural_mob` and populate `procedural_pool`.
    - Added `procedural_mob_generated` signal.
    - Implemented `get_procedural_mob` to instantiate `ProceduralMob` and return it.
    - Updated `has_procedural_assets` to return `false` (ProceduralMob is data-driven).
    - Wired GameState callback: connect `procedural_mob_generated` so GameState can log generation.
    - Cleaned up the NPCManager procedural mob handler callback (now uses an empty `Callable.new()` since GameState doesn't invoke it).
  - `scripts/EncounterBuilder.gd` (renamed to `CombatEncounterBuilder.gd`):
    - Added static `_build_procedural_mob(enemy_data: Dictionary) -> ProceduralMob` that instantiates `ProceduralMob`.
    - Modified `generate_procedural_enemy` to call `_build_procedural_mob` and add proto to `procedural_pool`.
    - Added procedural mob fallback generation for enemy spawns, mirroring NPCManager pattern.
  - `scripts/HubWorld.gd`:
    - Added `_build_procedural_mob(enemy_data: Dictionary) -> Dictionary` helper.
    - Modified `_seed_local_mobs` to generate enemy via `EncounterBuilder.generate_procedural_enemy` and emit `procedural_mob_generated` signal when NPCManager is present.
  - `scripts/GameState.gd`:
    - Added `set_npc_manager_procedural_mob_handler(npc_manager: Node, callback: Callable)` to wire NPCManager's signal.
    - Modified `_ready` to call `set_npc_manager_procedural_mob_handler` for NPCManager node.
    - Added `_on_autosave_tick` to handle autosave timer callback.
  - `scripts/ProceduralMob.gd`:
    - Read to confirm its API (`setup_for`, `archetype`, `color`, `size`) and ensure compatibility.

- **`CHANGELOG.md`** — added entry for Step 8.
