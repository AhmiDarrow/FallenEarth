# NEXT_TASKS — Fallen Earth

**Version:** 0.4.0-dev · **Updated:** 2026-07-05 · **Phase:** 0 done, Phase 1 next

*Aligns with `docs/PLAN_v040_crafting_progression.md`, `docs/HANDOFF_PROTOCOL.md`, and `memory/CURRENT_STATE.md`.*

---

## TOP PRIORITY — Next session

### P0 — Phase 1 (resource nodes + gathering)

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
