# NEXT_TASKS — Fallen Earth

**Version:** 0.5.0-complete · **Updated:** 2026-07-05 05:30 · **Phase:** v0.4.0 + v0.5.0 complete

*Aligns with `docs/PLAN_v040_crafting_progression.md`, `docs/HANDOFF_PROTOCOL.md`, and `memory/CURRENT_STATE.md`.*

---

## TOP PRIORITY — Next session

### P0 — v0.6.0 candidate selection

All 4 pre-existing v0.4.0 polish issues from `HANDOFF_2026-07-05_0530.md` are FIXED (see COMPLETED below). Plus a bonus production bug found during the fix: `_faction_rep_for` had a stale `_faction_names.is_empty()` early-return that broke faction rep checks for new players. Removed in `HANDOFF_2026-07-05_1300.md`.

Pick the next milestone from the PLAN's "Not yet done in v0.5.0+" list:
- **Real combat damage wiring** (merge `_resolve_attack` with EquipmentManager stats; expand `use_item` to support stamina potions, etc.) **[Recommended]** — most player-facing, builds directly on v0.5.0.
- **Real procedural NPC spawn in settlements** (replace the 3 hard-coded test NPCs in PartyNPCManager with biome-aware procedural generation)
- **Full settlement interiors** (rooms, traveling NPCs, mini-quests, visual variety)
- **Settlement-to-Riftspire travel** (Riftspire entry from the World Map, return path)
- **Button asset set** (procedural pixel-art buttons + pixel font; partially drafted in Phase 3 but not generated yet)

### P1 — Phases 9+ per `docs/PLAN_v040_crafting_progression.md`

(Full list in the plan doc; phases 2 → 8 follow Phase 1, each with own end-of-phase stop/commit/push.)

---

## COMPLETED

### v0.4.0 pre-existing polish ✅ (2026-07-05 13:00)

| ID | Task | Notes |
|----|------|-------|
| P0-1 | `MissionManager.gd:214` `GameState.mob_key` parser warning | 3 call sites changed from `GameState.mob_key(...)` (static) to `gs.mob_key(...)` (instance). `GameState.gd` has no `class_name`, so static calls fail to parse. |
| P0-2 | `smoke_phase5.gd:203` assigning to signal | Deleted `gs.faction_rep_changed = Callable()`. Signals can't be reassigned. |
| P0-3 | `smoke_phase5` `spawn_for_hex` RNG flakiness | Added `seed(12345)`, bumped max attempts to 100. Verified deterministic across 10 runs. |
| P0-4 | `smoke_tile_system` rift_scar normalization | Test was querying `Vector2i(4, 0)` (out of bounds in a 4×4 map) — changed to `Vector2i(0, 1)` where `terrain[4]` actually lives. |
| **Bonus** | `_faction_rep_for` production bug | Removed stale `_faction_names.is_empty()` early-return that silently broke rep checks for new players. Found via the chain: RNG seed → faction rep test fail → wrong ProgressionManager → also noticed the production bug. |
| **Bonus** | `smoke_phase5` faction rep test | Use autoload ProgressionManager (production reads from autoload, not local instance). Changed template from `legendary_loner` (50 rep + quest) to `faction_officer` (10 rep, no quest) to isolate the rep gate. |
| **Bonus** | `smoke_phase5` `get_invite_requirements_text` | Use autoload ProgressionManager; reset to L1 (previous test had set it to 100). |

### v0.5.0 — HP/MP combat wiring ✅ (2026-07-05 05:30)

| ID | Task | Notes |
|----|------|-------|
| v050-1 | `CombatManager` autoload-aware max_hp/mp/attack/armor | `_spawn_player` reads from `EquipmentManager` when autoload present, falls back to stat-only. |
| v050-2 | `use_item("bandage")` heals 30 HP, consumes from InventoryManager, marks unit as acted | Returns `{ok, message, heal, remaining_hp, max_hp}`. |
| v050-3 | `TacticalCombat._combat` type RefCounted → Node | To match new `CombatManager` so it can call autoload methods. |
| v050-4 | `smoke_v050.gd` — 6 test groups, all green | Bug 1: `await process_frame` in `_initialize` lets autoloads finish init. Bug 2: set `active_unit_id = "player"` before `_get_unit_ref` in test 5/6. |

### v0.4.0 Phase 0 ✅ (2026-07-05)

| ID | Task | Status |
|----|------|--------|
| 19 | **Resource nodes** — `data/resource_nodes.json` (10 biomes × ~6 nodes + floor_pickup_density), `HarvestNode` scene + script, `FloorPickup` scene + script. Update `LocalMapGenerator` to place nodes + pickups on the map. Update `LocalMapView` to host a `NodeLayer` for them. Tools: `generate_nodes.py` (~50 sprites), `generate_floor_pickups.py` (2 sprites). | ⏳ READY |
| 20 | **Tool-tier gating** — wire `HarvestNode.gather()` to check equipped MainHand tool's `harvests` list. Add `pickaxe_stone` and `axe_stone` to `data/tools.json` (T0 entry tools, 1 stick + 2 stones recipe). | ⏳ READY |
| 21 | **Player gather action** — HubWorld detects E-press when adjacent to a HarvestNode, starts a timer, awards yield. Tool check: wrong tool → "Equip a higher-tier pickaxe/axe". | ⏳ READY |

### P1 — Phase 1b (hover tooltips)

| ID | Task | Status |
|----|------|--------|
| 22 | **Hover tooltips** — `HoverTooltip.gd` (1s dwell) shows name of what's under mouse cursor: terrain label, node name, mob name, NPC name, rift marker, station. Smoke test + asset check at end. | ⏳ PENDING (after Phase 1) |

### P2 — Phases 2-8 per `docs/PLAN_v040_crafting_progression.md`

(Full list in the plan doc; phases 2 → 8 follow Phase 1, each with own end-of-phase stop/commit/push.)

---

## COMPLETED

### v0.4.0 Phase 0 ✅ (2026-07-05)

| ID | Task | Notes |
|----|------|-------|
| 18 | Drop rift_scar tile | Removed TERRAIN_RIFT_SCAR from LocalMapGenerator + TileSetService; 4-row atlas; rift_scar.png deleted (10 files); legacy `terrain[i] == 4` normalized to ground in LocalMapView. Committed `883eca5+`. |

### v0.4.0 Phase 1 ✅ (2026-07-05)

| ID | Task | Notes |
|----|------|-------|
| 19 | Resource nodes | 4 new data files (items, resource_nodes, tools, recipes); HarvestNode + FloorPickup scenes; InventoryManager autoload; LocalMapGenerator emits nodes + pickups; LocalMapView hosts them in NodeLayer + PickupLayer; HubWorld gather action + auto-pickup; tools/generate_nodes.py (39 sprites), generate_floor_pickups.py (2 sprites), verify_assets.py, smoke_resource_nodes.gd. All 7 test groups green. |

### v0.4.0 Phase 1b ✅ (2026-07-05)

| ID | Task | Notes |
|----|------|-------|
| 22 | Hover tooltips (1s dwell) | `scripts/HoverTooltip.gd` (Control with Label, 1s dwell, follows mouse at 14,14 offset). HubWorld `_hit_test_at_world` with priority: resource node > pickup > mob > rift > NPC > mission > terrain. 4 new tests in `tools/smoke_hover_tooltip.gd`. All green. |

### v0.4.0 Phase 2 ✅ (2026-07-05)

| ID | Task | Notes |
|----|------|-------|
| 23 | Full Character HUD | 2 new autoloads (ProgressionManager, LootRoller). 4 new UI scripts (HUD, Hotbar, Minimap, InventoryScreen). HubWorld wires HUD + hides old CharInfoBar; resolves hotbar tool for gather. 6 new tests in `smoke_phase2.gd`. Fixed pre-existing `SaveManager` type-annotation bug in GameState/CharacterSelection. All green. |

### Phase 7 — Godot 4.3 TileMapLayer system ✅

| ID | Task | Notes |
|----|------|-------|
| 19 | Removed old draw tile system | Deleted `LocalMapRenderer.gd`, `BiomeTilesetManager.gd`, `TileSetBuilder.gd`, `TileSetFactory.gd`, `TileTest.tscn/.gd`, `BiomeTilesets` autoload, `assets/tilesets/*` |
| 20 | New `TileSetService` | Godot 4.3 TileSet + TileSetAtlasSource, 5 terrains per biome, blocked tile has full-cell collision polygon. |
| 21 | New `LocalMapView` scene | `TileMapLayer` for ground, y-sorted `MobLayer` for entities, `MarkerLayer` for rift/NPC/mission. |
| 22 | New tile assets | 50 PNGs (10 biomes × 5 terrains) via `tools/generate_tiles.py` + PixelLab pixflux. |
| 23 | `MobVisual` rewrite | No scale-down hack. 64×64 sprite at native size, NEAREST filter, parented to y-sorted `MobLayer`. |
| 24 | `HubWorld` migration | Uses `LocalMapView`; removed `_make_circle_texture` procedural draw entirely. |
| 25 | Smoke test | `tools/smoke_tile_system.gd` exercises TileSetService (10 biomes), LocalMapView, MobVisual, HubWorld scene. |
| 26 | Boot probe | `tools/boot_probe.gd` runs MainMenu 60 frames headless with zero runtime errors. |

### Phase 4 — World gen + two-layer maps ✅ (v0.2.0)

### Phase 5 — Rifts ✅ (v0.2.0)

### Phase 6 — Combat / NPCs / missions ✅ (v0.2.0)

---

## TECH DEBT (reference only)

- ~~Remove `nul` junk files~~ ✅
- ~~Add `.gitignore`~~ ✅
- ~~Save/load shape unification~~ ✅
- ~~GDScript strict-type compile cascade~~ ✅
- ~~Old wang-tile draw system~~ ✅ (v0.3.0)
- ~~Procedural `_make_circle_texture` markers~~ ✅ (v0.3.0 — replaced with ColorRect+Label)

---

## Asset work (PixelLab API — in progress)

- [x] Human male base sprite + 8 rotations + walk frames
- [ ] Remaining 23 race×gender combos (same pipeline)
- [x] 10 mob sprites (regenerated round 2 — visible silhouette)
- [x] 50 terrain tiles (10 biomes × 5 types) — **NEW v0.3.0**
- [ ] Idle animation frames
- [ ] Attack animation frames
- **API key & pipeline documented in `memory/PROJECT_MEMORY.md`**

---

*Milestone: v0.3.0 shipped (Godot 4.3 TileMapLayer). Next: F5 visual verify → tile QA per biome.*
*Reminder: end sessions with `prepare-handoff`; update `CHANGELOG.md` on release.*
