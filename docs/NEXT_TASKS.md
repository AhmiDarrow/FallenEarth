# NEXT_TASKS — Fallen Earth

**Version:** 0.5.0-complete · **Updated:** 2026-07-05 05:30 · **Phase:** v0.4.0 + v0.5.0 complete

*Aligns with `docs/PLAN_v040_crafting_progression.md`, `docs/HANDOFF_PROTOCOL.md`, and `memory/CURRENT_STATE.md`.*

---

## TOP PRIORITY — Next session

### P0 — Pre-existing v0.4.0 polish (not blocking, but flagged in last handoff)

| ID | Task | Status |
|----|------|--------|
| P0-1 | **`MissionManager.gd:214`** — `GameState.mob_key(...)` reference uses autoload name as a class. GDScript parser flags "Identifier not found: GameState" but runtime works. Fix: use `get_node("/root/GameState").mob_key(...)` or add a `class_name` to GameState. | ⏳ READY |
| P0-2 | **`smoke_phase5.gd:203`** — `gs.faction_rep_changed = Callable()` tries to assign to a signal. Signals can't be reassigned. Delete the line. | ⏳ READY |
| P0-3 | **`smoke_phase5.gd` `spawn_for_hex` test** — RNG-flaky (sometimes produces no NPC in 10 calls). Make deterministic: seed RNG, or iterate until success with a max-attempts cap (e.g. 100). | ⏳ READY |
| P0-4 | **`smoke_tile_system.gd` rift_scar normalization** — ERROR is logged but test reports "ok" on the next line. Trace the LocalMapView code path; the normalization check is partially broken. | ⏳ READY |

### P1 — v0.6.0 planning

Pick the next milestone from the PLAN's "Not yet done in v0.5.0+" list:
- **Real procedural NPC spawn in settlements** (replace the 3 hard-coded test NPCs in PartyNPCManager with biome-aware procedural generation)
- **Full settlement interiors** (rooms, traveling NPCs, mini-quests, visual variety)
- **Settlement-to-Riftspire travel** (Riftspire entry from the World Map, return path)
- **Button asset set** (procedural pixel-art buttons + pixel font; partially drafted in Phase 3 but not generated yet)
- **Real combat damage wiring** (merge `_resolve_attack` with EquipmentManager stats; expand `use_item` to support stamina potions, etc.)

**Recommended: real combat damage wiring + more consumables.** It's the most player-facing and builds directly on v0.5.0.

### P2 — Phases 9+ per `docs/PLAN_v040_crafting_progression.md`

(Full list in the plan doc; phases 2 → 8 follow Phase 1, each with own end-of-phase stop/commit/push.)

---

## COMPLETED

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
