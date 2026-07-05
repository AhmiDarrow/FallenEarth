# NEXT_TASKS — Fallen Earth

**Version:** 0.5.0-complete · **Updated:** 2026-07-05 05:30 · **Phase:** v0.4.0 + v0.5.0 complete

*Aligns with `docs/PLAN_v040_crafting_progression.md`, `docs/HANDOFF_PROTOCOL.md`, and `memory/CURRENT_STATE.md`.*

---

## TOP PRIORITY — Next session

### P0 — v0.7.1 polish (small, 1-2 hours total)

| ID | Task | Status |
|----|------|--------|
| P0-1 | **Wire `spawn_for_settlement` into `SettlementManager`** — verify the procedural spawn runs when the player enters a settlement (currently `_resolve_resident_npcs` is only called when the Settlement scene is built) | ⏳ READY |
| P0-2 | Add `preferred_race` to `_faction_themes` so e.g. Iron Accord NPCs always spawn as human (not chthon) | ⏳ READY |
| P0-3 | Add a per-spawn-debug log: `[PartyNPCManager] Settled 5,7 (Neon Bogs/Iron Accord): 3 residents (iron_pact_guard, bogs_dweller, wanderer_common)` | ⏳ READY |

### P1 — v0.8.0 candidates

Pick the next milestone from the PLAN's "Not yet done" list:
- **Full settlement interiors** (rooms, traveling NPCs, mini-quests, visual variety) — most player-facing **[Recommended]**
- Settlement-to-Riftspire travel
- Button asset set
- "Place station" interaction (let the player place a crafted `cooking_table` in a new hex)

### P2 — Phases 9+ per `docs/PLAN_v040_crafting_progression.md`

(Full list in the plan doc; phases 2 → 8 follow Phase 1, each with own end-of-phase stop/commit/push.)

---

## COMPLETED

### v0.7.0 — Procedural NPC spawn in settlements (biome + faction) ✅ (2026-07-05 17:00)

| ID | Task | Notes |
|----|------|-------|
| v070-1 | Faction-aware templates | 11 → 18 templates. Added 7 faction-specific: iron_pact_guard, hollow_warden, ash_serpent_raider, veil_warden, neon_choir_techie, bone_circuit_broker, caravan_guard. Each has `preferred_factions: ["<Faction>"]`. |
| v070-2 | Per-faction themes | New `_faction_themes` section in templates JSON. 10 factions, each with name_prefix + race_pref. Faction theme OVERRIDES biome theme for name/race. |
| v070-3 | Bi-axial template roll | `_roll_template_for_settlement(biome, faction)` categorizes into match_both (4x), match_faction_only (3x), match_biome_only (2x), universal (1x). Faction matches get a stronger boost than biome matches (per user's "balance to faction ratio" brief). |
| v070-4 | `spawn_for_settlement` API | Generates 1-3 NPCs per town (small/medium/large). Deterministic via FNV-1a hash of `hex\|biome\|faction`. |
| v070-5 | `clear_settlement_residents` | Removes only residents for the given hex_key. Preserves Phase 3 test NPCs and hex-spawned NPCs. |
| v070-6 | `Settlement._resolve_resident_npcs` | Now calls `clear_settlement_residents(hex)` then `spawn_for_settlement(hex, biome, faction, size)`. Replaces the Phase 3 placeholder pool selection. |
| v070-7 | `WorldGenerator` town data | Town data now includes `biome: <Biome Name>` (pulled from the picked tile's biome). Needed for `_resolve_resident_npcs`. |
| v070-8 | `smoke_v070.gd` — 12 test groups, all green | Verified deterministic across 5 runs. |
| v070-9 | Updated `smoke_phase5.gd` for 18 templates | Bumped template count expectation from 4 to 18. |

### v0.6.0 follow-up polish — craftable cooking table + sprite + wiring ✅ (2026-07-05 16:00)

| ID | Task | Notes |
|----|------|-------|
| v060fp-1 | `cooking_table` item | `data/items.json` — new item, `category: "station"`, `stackable: false`, `max_stack: 1`, sell 50 EC |
| v060fp-2 | `cooking_table` recipe (L5) | `data/recipes.json` — `station: "none"` (chicken-and-egg: you craft the table BEFORE you have one). Ingredients: 4 withered_branch + 2 iron_ore + 1 teal_crystal. |
| v060fp-3 | LocalMapGenerator wiring | `_emit_start_cooking_table(spawn)` emits 1 table at spawn + 8, +8. Marked `occupied` BEFORE resource/floor-pickup emitters so a tree can't drop on it. |
| v060fp-4 | `cooking_table.png` sprite | `assets/sprites/stations/cooking_table.png` (24×24) via new `tools/generate_station_sprites.py`. Table + cauldron + flame + steam wisps. |
| v060fp-5 | Item icons for 5 new items | `tools/generate_item_icons.py` learned the `station` category. 5 new icons generated. |
| v060fp-6 | 7 new tests | smoke_cooking now 22 tests. Use `FileAccess.file_exists` (not `ResourceLoader.exists`) for newly-generated PNGs. |

### v0.6.0 follow-up — cooking table + mob drops + recipes ✅ (2026-07-05 15:00)

| ID | Task | Notes |
|----|------|-------|
| v060f-1 | `raw_meat` item | `data/items.json` — `raw_meat` (category: raw_material, max_stack 20, sell 3 EC) |
| v060f-2 | Mob drops | `data/mobs.json` — added `drops: [...]` to 7 mobs: ashveil_grazer, echo_chorister, iron_buck, charnel_stalker, mycelial_behemoth, rift_elk, storm_raptor. `LootRoller.roll` already supported drops. |
| v060f-3 | CookingTable node | `scripts/CookingTable.gd` + `scenes/CookingTable.tscn` — interactable station. Sprite path: `assets/sprites/stations/cooking_table.png` (fallback to generic). |
| v060f-4 | CookingTableUI | `scripts/ui/CookingTableUI.gd` + `scenes/ui/CookingTableUI.tscn` — recipe list modal. Populates from `CraftingManager.recipes_for_station("cooking_table")`. Esc closes. |
| v060f-5 | StationLayer | `scenes/LocalMapView.tscn` + `scripts/LocalMapView.gd` — new `StationLayer` (generic, future-station-ready). `_populate_cooking_tables`, `get_cooking_table_at`, `get_station_layer`. |
| v060f-6 | HubWorld wiring | `scripts/HubWorld.gd` — `_cooking_table_ui` member, `_adjacent_cooking_table()` and `_open_cooking_table_ui()` helpers. E-key handler checks cooking table before gather fallback. |
| v060f-7 | 3 cooking recipes | `data/recipes.json` — `cooked_meat` (L1, 1 raw_meat), `mana_potion` (L5, 2 withered_branch + 1 teal_crystal), `antidote` (L3, 1 kelp_fibre + 1 rusted_scrap). All `station: "cooking_table"`. |
| v060f-8 | `smoke_cooking.gd` — 15 test groups, all green | Verified deterministic across 10 runs. |

### v0.6.0 — Combat damage + consumables ✅ (2026-07-05 14:00)

| ID | Task | Notes |
|----|------|-------|
| v060-1 | Per-class weapon stats | `em.get_attack` now sums stat_mods from all equipment. Each class scales with its own stat (Scavenger=str, Technician=int, Survivor=con, Striker=str, Riftbinder=int+wis, Warden=str+con). Fixes the v0.5.0 bug where all class weapons effectively used str. |
| v060-2 | Dynamic equipment reads | `_spawn_player` stores `unit.attack`/`unit.armor` as base only. `_effective_attack`/`_effective_armor` call `em.get_attack(unit_id)`/`em.get_defense(unit_id)` at damage time. Equip changes mid-combat take effect immediately. |
| v060-3 | 3 new consumables | `mana_potion` (+25 MP), `cooked_meat` (+15 HP + +1 attack for 3 turns), `antidote` (+10 HP, status-cure placeholder). `use_item` refactored to dispatch via `_apply_consumable` helper. |
| v060-4 | `smoke_v060.gd` — 11 test groups, all green | Verified deterministic across 10 runs. |

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
