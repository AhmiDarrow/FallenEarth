# PLAN v0.4.0 — Crafting, Gathering, Equipment, Economy (and v0.5.0 polish)

**Status:** v0.4.0 COMPLETE (all 8 phases shipped, committed to master).
v0.5.0 STARTED — partial HP/MP combat wiring landed (commit 708e9e8).
**Owner:** Remedy
**Builds on:** v0.3.0 TileMapLayer system (50 terrain tiles, 27 mob sprites)
**Current branch:** `master` (always push to master — the next agent pulls from `master`)

## Quick context for the next agent (v0.5.0 resume)

- v0.4.0 + v0.5.0 partial work is committed to `master`. Pull before starting.
- The plan below describes v0.4.0 (largely done) and what was added in v0.5.0 (partially done).
- Read `docs/PLAN_v040_crafting_progression.md` (this file) for the canonical v0.4.0 design + v0.5.0 status section.
- Read `memory/CURRENT_STATE.md` for the live v0.4.0 state (10 systems shipped, what's next).
- Read `memory/LATEST_HANDOFF.md` for the most recent commit context.
- Read `memory/SESSION_NOTES/HANDOFF_2026-07-05_0500.md` (v0.4.0 Phase 8 final) and the most recent `HANDOFF_2026-07-05_XXXX.md` for v0.5.0 context.
- All 9 existing smoke files still pass under v0.4.0 + v0.5.0 partial:
  - `tools/smoke_tile_system.gd` (smoke tile)
  - `tools/smoke_resource_nodes.gd` (smoke-p1)
  - `tools/smoke_hover_tooltip.gd` (smoke-tt)
  - `tools/smoke_phase2.gd` (smoke-p2 — full Character HUD)
  - `tools/smoke_phase3.gd` (smoke-p3 — CharacterMenu, Party, Crafting, 2 info panels, 3 station UIs)
  - `tools/smoke_phase3b.gd` (smoke-p3b — settlements, shops, mission board)
  - `tools/smoke_phase4.gd` (smoke-p4 — Equipment, weapons, armor, accessories, stats)
  - `tools/smoke_phase5.gd` (smoke-p5 — procedural NPC spawn + invite)
  - `tools/smoke_phase6.gd` (smoke-p6 — base building)
  - `tools/smoke_phase7.gd` (smoke-p7 — base shops)
  - `tools/smoke_phase8.gd` (smoke-p8 — save/load + item icons + loot popups + rarity colors)
  - `tools/smoke_v050.gd` (smoke-v050 — HP/MP combat wiring; 4/6 pass; 1 outstanding bug)
- `tools/boot_probe.gd` — 60-frame smoke that boots MainMenu; all pass.

## v0.5.0 status (start of next session)

### Done in v0.5.0
- `CombatManager.gd`: `extends RefCounted` → `extends Node` (so it can call `get_node_or_null` on autoloads)
- `CombatManager._spawn_player`: pulls max_hp / mp_max / attack / armor from `EquipmentManager` when the autoload is present; falls back to stat-only when not
- `CombatManager.use_item(item_id)`: heals 30 HP on `bandage`, consumes one from InventoryManager, marks unit as acted. Returns `{ok, message, heal, remaining_hp, max_hp}`
- `TacticalCombat._combat`: type changed from RefCounted → Node to match the new CombatManager
- `tools/smoke_v050.gd` (6 test groups)

### Outstanding v0.5.0 issues
1. **EquipmentManager autoload `_weapons_data` gets cleared mid-test.** Symptom: `em.get_weapon("Scavenger", 0)` returns `{}` partway through `smoke_v050.gd`. The autoload initializes with 6 weapons at startup, so the clear happens during test execution. **Suspects:** `restore_from_snapshot` in `EquipmentManager.gd` (line 90: `_equipment_state.clear()` — but that only clears `_equipment_state`, not `_weapons_data`). The autoload data is a class-level dict, so something is either calling `restore_from_snapshot` with a payload that doesn't include weapons OR there's a re-init happening. **First thing to check in the next session.** The fact that `smoke_v050.gd`'s tests 1, 5, 6 pass but tests 2, 3, 4 fail with "empty" suggests the autoload's data is fresh and gets cleared somewhere between test 1 and test 2. Check `restore_from_snapshot` callers in `CombatManager`, `HubWorld`, `GameState` autosave flow.
2. **CombatManager.use_item only handles `bandage`.** Other consumables (stamina potions, etc.) need follow-up.

### Not yet done in v0.5.0+
- **Real procedural NPC spawn in settlements** (Phase 5 ships generic spawn; settlements need specific NPCs at specific cells with specific archetypes)
- **Full settlement interiors** (rooms, traveling NPCs, mini-quests, visual variety)
- **Settlement-to-Riftspire travel** (the user opens the Riftspire capital, then travels back)
- **Button asset set** (procedural pixel-art buttons + pixel font applied via `gui/theme/custom` in `project.godot`; partially drafted in Phase 3 but not generated yet)
- **Real combat damage wiring** — the `use_item` path works, but the existing `_resolve_attack` (Phase 8) and HP/MP caps (Phase 4) need to be merged with the EquipmentManager stats

### Files to know
- `scripts/CombatManager.gd` — autoload-style manager for FFT combat (was `extends RefCounted`, now `extends Node`)
- `scripts/EquipmentManager.gd` — autoload for inventory + per-tier equipment
- `scripts/InventoryManager.gd` — autoload for inventory (had `get_rarity_color` added in Phase 8 polish)
- `data/weapons.json`, `data/armor.json`, `data/base_shops.json` — phase data files
- `assets/sprites/items/` — 14 procedural item icons (Phase 8 polish)
- `assets/sprites/equipment/` — 468 procedural per-tier equipment sprites
- `assets/sprites/base/` — 10 procedural base sprites

### Test runner pattern
All smoke tests follow the same pattern:
```
& godot --headless --path . -s tools/smoke_X.gd
```
Each test:
- `await`s each test function (running them sequentially)
- `prints` "ok ..." on success, "FAIL ..." on failure
- prints "All checks passed. (failures.size=N)" at the end
- exits 0 on full pass, 1 on any failure

Run the full v0.4.0 + v0.5.0 suite before committing:
```bash
& godot --headless --path . -s validate_scripts.gd
& godot --headless --path . -s tools/smoke_tile_system.gd
& godot --headless --path . -s tools/smoke_resource_nodes.gd
& godot --headless --path . -s tools/smoke_hover_tooltip.gd
& godot --headless --path . -s tools/smoke_phase2.gd
& godot --headless --path . -s tools/smoke_phase3.gd
& godot --headless --path . -s tools/smoke_phase3b.gd
& godot --headless --path . -s tools/smoke_phase4.gd
& godot --headless --path . -s tools/smoke_phase5.gd
& godot --headless --path . -s tools/smoke_phase6.gd
& godot --headless --path . -s tools/smoke_phase7.gd
& godot --headless --path . -s tools/smoke_phase8.gd
& godot --headless --path . -s tools/smoke_v050.gd
& godot --headless --path . -s tools/boot_probe.gd
```

### v0.4.0 plan (largely done — see the rest of this file)

The rest of this file is the original v0.4.0 design + v0.5.0 additions. Read sections by topic; most are done.

### v0.4.0 (and v0.5.0) additions (this revision):

**v0.4.0 additions (this revision):**
- **Tools share MainHand with weapons** — single equip slot, swap via hotbar (no separate Tool slot)
- **Hotbar** — 10 quick-swap slots bound to number keys 1-0, sits at the bottom of the HUD
- **Sticks and stones** — base-material floor pickups that lead the crafting progression; pick up a stick + 2 stones → craft a Stone Tool (entry-point recipe, no station required)
- **Stone Axe AND Stone Pickaxe** — both are T0 entry tools, both from 1 stick + 2 stones
- **Full in-game Character HUD** — HP/MP bars, level, XP, EC, hotbar, minimap
- **Two info panels for character creation** — one for race, one for class (separate panels)
- **1-second hover delay on tooltips** — don't spam, only after the cursor dwells
- **Small minimap** — top-right of HUD, shows discovered hexes, current position, faction towns, rifts, Riftspire
- **NPC towns run by factions** — placed during world gen; even percentage of each faction represented
- **Riftspire (capital)** — exactly one per world, pre-generated non-aggressive NPC city, locked until L50
- **Party joinable NPCs** — random spawn, procedurally generated race/class/gender; invite requires level + faction rep + quest unlock; **reuses existing character sprites** (no new NPC art)
- **Base building** — player-chosen placement (50-tile buffer from map edges); 10 upgrades ending at L200; cost = material + money + level; grows bigger and fancier with each upgrade; click hut to open Base UI; at 20 NPCs the player names the settlement
- **Base shops** — some joinable NPCs at the base can ask for money/items to open permanent shops/services
- **All new content gets procedural assets** — every new item, equipment slot, harvest node, base upgrade, and UI element ships with a procedurally-generated sprite in its phase
- **Rift design clarification** — already implemented: RiftRunner + RiftInstance, procedural dungeons, 75% boss chance at end, close mechanism returns to upworld entry position. Listed here for completeness only.

---

## 0. Scope in one paragraph

We're going to bolt a full resource-gathering → crafting → equipment → combat loop onto the existing 2-layer world. The local map gets harvestable resource nodes (trees, formations, ore, crystals, water — per-biome varieties). The player gathers from them into a stacked inventory. Mobs drop loot, XP, and EC (EarthCoin). Three crafting stations (worktable L5, armor table L10, blacksmith L10) unlock recipes by level; the inventory tab handles basic items with no station. Six classes each get a unique weapon type with 26 tiers (every 10 levels). Four armor slots (head/chest/legs/boots) per class, with ~30 tiers spanning 1–256. Two accessory slots, ten accessory items with varied effects. A unified Character menu (inventory/equipment/crafting/stats) replaces the current loose options. Save/load extends to cover everything.

---

## 1. Phase plan (deliverable chunks)

The plan is split into 6 phases. Each phase is independently shippable — you can play between phases and the game is in a coherent state at the end of each. **Recommended order: 0 → 1 → 2 → 3 → 4 → 5**, but Phase 3 (crafting) and Phase 4 (equipment) can interleave.

| # | Phase | Est. effort | Why this order |
|---|-------|-------------|----------------|
| 0 | Visual cleanup — drop rift_scar tile | 30 min | Removes the orange scars; makes the canvas cleaner before we add nodes. |
| 1 | Resource nodes + gathering + tool-tier gating + sticks/stones | 4-5 h | Foundation for the whole economy loop. Without nodes, nothing to craft from. Tool tiering + sticks/stones added in this phase so gathering is correctly gated from the start. |
| 1b | Hover tooltips (ground / nodes / mobs / NPCs) — 1s dwell | 2-3 h | Tiny standalone system; do it here while the world is still being populated. |
| 2 | Inventory + mob drops + XP/EC + full Character HUD + hotbar + minimap | 6-8 h | Everything you collect needs to land somewhere visible. Adds progression feedback (XP bar, EC), the in-game HUD, hotbar for tool/weapon swap, and the small minimap. |
| 3 | Crafting (inventory tab + 3 stations) + NPC towns + Riftspire | 7-9 h | Uses nodes from Phase 1, inventory from Phase 2. Level-gated, so the game has a sense of progression. NPC town placement + Riftspire generation happen during world gen. |
| 4 | Equipment + weapons + armor + tools + accessories + stats screen | 7-9 h | The big one. Weapons per class × 26 tiers, armor × 13 tiers × 4 slots, 3 pickaxes + 3 axes, 8 equip slots, 10 accessories, stat recompute. Tools and weapons share MainHand. |
| 5 | Party joinable NPCs (procedural + invite) | 4-5 h | Random procedural spawn of race/class/gender NPCs; invite requires level + faction rep + quest unlock. Adds a real "build a team" loop on top of the equipment system. |
| 6 | Base building (L10 unlock + 10 upgrades + capacity) | 5-7 h | Auto-placed first hut at L10; upgrades grow the sprite and capacity +5 each. Hub for any dismissed party members. |
| 7 | Base shops (NPC-initiated services) | 3-4 h | Some joinable NPCs at the base can ask for money/items to open a shop. Adds an end-game loop and reasons to keep party members around. |
| 8 | Character creation info panels (2 separate) + unified menu + button assets + save/load + polish | 5-7 h | Two info panels (race and class), new button art across all menus, save/load extended to all the new state, loot popups, item icons. |

Total estimated: **44-58 hours** of focused work. That's 7-10 long sessions.

---

## 2. Phase 0 — Visual cleanup

**Goal:** Remove the orange rift_scar tile from the atlas; the TileSet goes from 5 terrain rows to 4.

**Changes:**
- `scripts/TileSetService.gd` — remove the rift_scar row, update the `TERRAIN_NAMES` constant, update the `BLOCKED` index (it was index 3; now becomes index 2 since rift_scar is gone). Or better: keep constants stable and just skip the rift_scar load. I'll keep the constant for code clarity.
- `scripts/LocalMapGenerator.gd` — stop emitting TERRAIN_RIFT_SCAR. Drop the `rift_scar` field from map_data. Any existing save with rift_scar values gets normalized to TERRAIN_GROUND on load.
- `tools/generate_tiles.py` — drop the rift_scar renderer.
- `assets/tilesets/*/rift_scar.png` — deleted.

**Rift visualization:** Rifts are now entities, not terrain. `RiftRunner.add_rift_entrance` already tracks (local_x, local_y) per hex; we render them as a marker via `LocalMapView.add_marker(...)` with the ⚡ glyph (the same marker we already use — just no tile change).

---

## 3. Phase 1 — Resource nodes + gathering

**Goal:** Place 1-3 trees + 1-3 natural formations + 1-3 ore + 1-3 crystals + 1-3 fauna per biome on the local map. Player can walk onto a node and "gather" by holding E for a few seconds. **Plus: sticks and stones floor pickups scattered everywhere — the entry-point material for the whole progression.**

### Sticks and stones (entry-point materials)
- Two new items in `data/items.json`: `stick`, `stone`
- `stick` — gathered from "stick" floor pickups (small sticks lying on the ground); 1 stick per pickup
- `stone` — gathered from "stone" floor pickups (small stones on the ground); 1 stone per pickup
- Floor pickups are *not* HarvestNodes — they're tiny entities that auto-pickup on walk-over (no gather timer, no tool required). Implemented as a separate small `FloorPickup` scene.
- **First recipe in the game** (in `data/recipes.json`): `stone_axe_basic`
  - ingredients: 1 stick + 2 stones
  - result: a basic Stone Axe (T1 tool, harvests any tree, slow)
  - station: `none` (crafted from inventory)
  - level_required: 1
- This gives the player a working progression path from minute 1: walk → pick up sticks/stones → craft Stone Axe → chop trees → craft better tools.

### Resource nodes per biome: `data/resource_nodes.json`

```json
{
  "Ash Wastes": {
    "trees": [
      {"id": "ash_scrub", "yield": {"item": "withered_branch", "qty": [1,3]}, "gather_secs": 2.5, "respawn_secs": 180, "sprite": "tree_ash_scrub"}
    ],
    "formations": [
      {"id": "rust_pipe_cluster", "yield": {"item": "rusted_scrap", "qty": [1,2]}, "gather_secs": 3.0, "respawn_secs": 240, "sprite": "formation_rust_pipe"}
    ],
    "ore": [
      {"id": "iron_outcrop", "yield": {"item": "iron_ore", "qty": [1,2]}, "gather_secs": 4.0, "respawn_secs": 300, "sprite": "ore_iron"}
    ],
    "crystals": [],
    "fauna": [
      {"id": "wasteland_lizard", "passive": true, "aggro_range": 0, "sprite": "fauna_lizard"}
    ],
    "floor_pickup_density": {
      "stick": 0.04,
      "stone": 0.06
    }
  },
  "Neon Bogs": {
    "trees": [
      {"id": "neon_kelp", "yield": {"item": "kelp_fibre", "qty": [2,4]}, "gather_secs": 2.5, "respawn_secs": 180, "sprite": "tree_neon_kelp"}
    ],
    "formations": [
      {"id": "shallow_pool", "passable": false, "sprite": "formation_pool"}
    ],
    "ore": [],
    "crystals": [
      {"id": "teal_geode", "yield": {"item": "teal_crystal", "qty": [1,2]}, "gather_secs": 5.0, "respawn_secs": 360, "sprite": "crystal_teal"}
    ],
    "fauna": [
      {"id": "bog_crab", "passive": true, "aggro_range": 0, "sprite": "fauna_crab"},
      {"id": "bog_crab", "passive": true, "aggro_range": 0, "sprite": "fauna_crab"}
    ],
    "floor_pickup_density": {
      "stick": 0.02,
      "stone": 0.05
    }
  }
  // ... 8 more biomes; sticks and stones appear in every biome
}
```

### New constants
- 3 ore types: iron_ore, copper_ore, starmetal_ore
- 3 crystal types: teal_crystal, void_shard, ember_crystal
- Wood/material per biome: withered_branch (Ash), kelp_fibre (Bogs), living_metal (Ironwood), etc.
- 10-15 natural formation sprites (rocks, pools, vents, etc.)
- 1-3 fauna per biome (lizards, crabs, beetles, moths)
- **Sticks and stones** — universal floor pickups, every biome

### New scenes
- `scenes/HarvestNode.tscn` + `scripts/HarvestNode.gd` — node entity (gather timer, tool-tier check)
- `scenes/FloorPickup.tscn` + `scripts/FloorPickup.gd` — tiny auto-pickup on walk-over (stick/stone/etc.)

### Integration
- `LocalMapGenerator.generate()` — after the terrain fill, place N nodes per category (sampled from the biome's JSON) and sprinkle floor pickups based on density. Don't place on top of blocked cells or other entities. Store in `map_data["resource_nodes"]` and `map_data["floor_pickups"]`.
- `LocalMapView.configure()` — instantiate `HarvestNode` and `FloorPickup` children, parent to a new `NodeLayer` (sibling of `MobLayer`).
- `HubWorld` — on key press E, if player is adjacent to a non-depleted HarvestNode, start a gather timer (with tool tier check from Phase 4). After `gather_secs`, award the yield to inventory (Phase 2) and mark the node depleted. Floor pickups auto-trigger on walk.
- `data/items.json` — new file with item definitions (id, name, stackable, max_stack, sell_value_ec, icon).

### Procedural sprites (Phase 1)
- `tools/generate_nodes.py` — produces 24x24 or 48x48 sprites for each node type using PIL primitives. No API calls. ~50 sprites.
- `tools/generate_floor_pickups.py` — produces stick and stone sprites (tiny, low-detail). 2 sprites.
- Asset check at end of phase: confirm ~52 PNGs exist.

---

## 4. Phase 2 — Inventory + drops + XP/EC + full Character HUD + hotbar + minimap

**Goal:** Player can hold items, mobs drop loot on death, full in-game HUD shows HP/MP/XP/EC/level/hotbar, small minimap, and a 10-slot hotbar for tool/weapon quick-swap.

### New manager: `scripts/InventoryManager.gd` (autoload)
- `inventory: Array[Dictionary]` — slot entries `{item_id, qty}`
- `add_item(item_id, qty) -> int` (returns actually added; 0 if full)
- `remove_item(item_id, qty) -> bool`
- `has_item(item_id, qty) -> bool`
- `get_count(item_id) -> int`
- `capacity: int = 30` (configurable)
- `stack_rules: Dictionary` — from items.json
- Signals: `inventory_changed()`, `item_added(item_id, qty)`, `item_full(item_id)`

### New manager: `scripts/ProgressionManager.gd` (autoload)
- `xp: int`, `level: int`, `xp_to_next: int`
- `ec: int = 0` (EarthCoin)
- `add_xp(amount)` → level up if threshold crossed
- `add_ec(amount)`
- `spend_ec(amount) -> bool`
- Signals: `xp_gained()`, `level_up(new_level)`, `ec_changed()`

### Mob drops
- `data/loot_tables.json` already has per-biome items. We extend each mob entry in `data/mobs.json` with a `drops: Array[Drop]` where each Drop is `{item_id, chance, qty}`.
- `EncounterBuilder` (existing) or new `LootRoller.roll(mob_data, biome)` — rolls drops on combat end.
- `HubWorld._on_combat_victory` (or wherever combat resolves) — calls LootRoller, awards to inventory + EC + XP.

### XP/EC per mob
- Formula: `xp = mob.level * 5 + 5`, `ec = mob.level * 2 + rand(1,5)`
- For v0.4.0 this is simple; can rebalance later.

### Full in-game Character HUD (`scripts/ui/HUD.gd` + `scenes/ui/HUD.tscn`)
The HUD overlays the world view and persists across all gameplay screens. It has these regions:

```
┌─ TopBar ─────────────────────────────────────────────────────┐
│  [Player] Race · Class  Lv.12        [EC] 💰 1,432 EC  [≡Menu]│
│  HP ████████░░ 84/120   MP ████░░░░░░ 38/80                  │
│  XP ██████░░░░░░░░░ 1,800/3,200  (level progress bar)         │
└──────────────────────────────────────────────────────────────┘

                                              ┌─ Minimap ────┐
                                              │   ⬡ ⬡ ⬡       │
                                              │   ⬡ ★ ⬡       │ (★ = current
                                              │   ⬡ ⬡ ⬡       │  hex, faction
                                              │                │  colors, rifts)
                                              └────────────────┘

┌─ Hotbar ─────────────────────────────────────────────────────┐
│  [1] 🪓  [2] ⚔  [3] ⛏  [4] 🏹  [5]    [6]    [7]    [8]    │
│  StoneAxe Sword Pickaxe  Bow   ─     ─     ─     ─          │
│  (selected slot highlighted, 1-0 + click to swap)             │
└──────────────────────────────────────────────────────────────┘
```

Components:
- **Top bar**: character name + race + class, level, EC counter, menu button
- **HP / MP / XP bars**: thin horizontal bars; HP red, MP blue, XP green/yellow
- **Minimap**: top-right, ~180×180 px. Shows a small hex grid (~7×7 around current hex), current hex highlighted, discovered hexes tinted by faction, rift markers (⚡), Riftspire marker (★), town markers
- **Hotbar**: 10 slots, bound to number keys 1–0 and click. Shows whatever is in the MainHand slot + 9 favorites. Highlighted slot = currently equipped in MainHand. Press 1–0 to equip the matching item directly into MainHand (replaces whatever was there).
- **Menu button**: opens the unified Character menu (Phase 5)

### Hotbar data model
- The hotbar is a *list* of item IDs, not a fixed equip state.
- `inventory_state["hotbar"] = ["stone_axe", "iron_sword", "", "", ...]` (length 10)
- Pressing key 1 sets `MainHand` to `hotbar[0]`. Pressing 2 sets MainHand to `hotbar[1]`. Etc.
- Empty slots do nothing.
- The hotbar can be edited from the Inventory screen (drag items in/out, or "assign to hotbar" right-click action).

### Minimap
- `scripts/ui/Minimap.gd` — reads `GameState._tile_map` and `GameState._discovered_hexes`, renders to a SubViewport at low resolution, then displays as a TextureRect.
- Markers:
  - Current hex: large bright dot
  - Discovered hexes: small filled hexes tinted by faction (faction color from `data/factions.json`)
  - Undiscovered: dark
  - Rifts: ⚡ glyph on the hex
  - Riftspire: special ★ marker
  - NPC towns: small faction-colored star
- Updates on hex travel, faction discovery, rift spawn.
- Lives in HUD.tscn; instantiated on HubWorld, WorldMapScreen, Riftspire entry.

### Save/load impact
- GameState tracks `inventory_state`, `xp`, `level`, `ec`, `hotbar`. SaveManager stores them. Backward-compat: empty fields on old saves.

### New screen: `scenes/ui/InventoryScreen.tscn` + `InventoryScreen.gd`
- Grid of item slots (6×5 = 30 default)
- Hover tooltip with item name + description
- Click to use consumables (bandages → heal)
- Right-click for context (drop, equip if equipment, "add to hotbar" action)
- Hotbar editor at the bottom (drag items into the 10 slots)
- Close button → return to world

---

## 5. Phase 3 — Crafting + NPC towns + Riftspire

**Goal:** Three crafting stations + inventory basic crafting. Level-gated recipes. NPC town placement during world gen. Riftspire capital hex.

### New data: `data/recipes.json`

```json
[
  {
    "id": "stone_axe_basic",
    "name": "Stone Axe",
    "station": "none",
    "level_required": 1,
    "ingredients": [{"item": "stick", "qty": 1}, {"item": "stone", "qty": 2}],
    "result": {"item": "axe_stone", "qty": 1},
    "category": "tool"
  },
  {
    "id": "bandage",
    "name": "Bandage",
    "station": "none",
    "level_required": 1,
    "ingredients": [{"item": "withered_branch", "qty": 1}],
    "result": {"item": "bandage", "qty": 1},
    "category": "consumable"
  },
  {
    "id": "iron_pickaxe",
    "name": "Iron Pickaxe",
    "station": "blacksmith",
    "level_required": 10,
    "ingredients": [{"item": "iron_ore", "qty": 2}, {"item": "withered_branch", "qty": 1}],
    "result": {"item": "pickaxe_iron", "qty": 1},
    "category": "tool"
  },
  {
    "id": "copper_pickaxe",
    "name": "Copper Pickaxe",
    "station": "blacksmith",
    "level_required": 20,
    "ingredients": [{"item": "copper_ore", "qty": 4}, {"item": "iron_ore", "qty": 1}],
    "result": {"item": "pickaxe_copper", "qty": 1},
    "category": "tool"
  },
  {
    "id": "starmetal_pickaxe",
    "name": "Starmetal Pickaxe",
    "station": "blacksmith",
    "level_required": 60,
    "ingredients": [{"item": "starmetal_ore", "qty": 3}, {"item": "ember_crystal", "qty": 1}, {"item": "iron_ore", "qty": 1}],
    "result": {"item": "pickaxe_starmetal", "qty": 1},
    "category": "tool"
  },
  {
    "id": "reinforced_axe",
    "name": "Reinforced Axe",
    "station": "blacksmith",
    "level_required": 25,
    "ingredients": [{"item": "iron_ore", "qty": 3}, {"item": "withered_branch", "qty": 2}],
    "result": {"item": "axe_reinforced", "qty": 1},
    "category": "tool"
  },
  {
    "id": "masterwork_axe",
    "name": "Masterwork Axe",
    "station": "blacksmith",
    "level_required": 75,
    "ingredients": [{"item": "starmetal_ore", "qty": 2}, {"item": "ironwood_bark", "qty": 3}],
    "result": {"item": "axe_masterwork", "qty": 1, "bonus_yield": 1},
    "category": "tool"
  }
  // ... ~30 basic + 30 worktable + 25 armor + 25 weapon recipes total
]
```

### Recipe categories (4):
- `basic` (no station, always available from inventory tab) — bandages, basic food, basic consumables, the stone tool recipes
- `worktable` (L5+) — components, ammo, advanced consumables
- `armor_table` (L10+) — armor pieces
- `blacksmith` (L10+) — weapons + tools (axes and pickaxes)

### Station interaction
- 3 new placeable nodes: `Worktable`, `ArmorTable`, `Blacksmith`
- They are harvestable? No — they're interactable. Press E when adjacent → opens that station's UI.
- For v0.4.0, place one of each near the start hex in every world (so player has access after L5/L10).

### New screens
- `scenes/ui/CharacterMenu.tscn` (Phase 3 expansion) — tabbed shell hosting **all** character screens:
  - Tab: **Inventory** (existing `InventoryScreen.gd`)
  - Tab: **Equipment** (Phase 4 — placeholder in Phase 3)
  - Tab: **Crafting** (Phase 3 new)
  - Tab: **Party** (Phase 3 new — see Party section below)
  - Tab: **Stats** (Phase 4 — placeholder in Phase 3)
  - Keyboard: `I` `E` `C` `P` `S` to open each tab; `Tab` / `Shift+Tab` to cycle; `Esc` to close.
- `scenes/ui/WorktableUI.tscn` — list of unlocked worktable recipes, ingredient check, craft button
- `scenes/ui/ArmorTableUI.tscn` — same shape, armor recipes
- `scenes/ui/BlacksmithUI.tscn` — same shape, weapon recipes

### Party screen (new — see Character menu section)
- One of the CharacterMenu tabs.
- `scripts/ui/PartyScreen.gd` + `scenes/ui/PartyScreen.tscn`.
- Manages: invite from available_npcs, dismiss to base, view per-member equipment (read-only in Phase 3).

### Recipe unlock
- A recipe is "visible" if `level >= level_required`. No discovery mechanic — you see them all once eligible. (Keeps it simple; can add discovery later.)
- Filter buttons in the UI: by category, by ingredient availability.

### New manager: `scripts/CraftingManager.gd` (autoload)
- `unlocked_recipes: Array[String]` — derived from level
- `can_craft(recipe_id) -> bool` (has ingredients + level)
- `craft(recipe_id) -> bool` (consume ingredients, add result)

### NPC towns (faction-controlled) — world gen integration

`data/towns.json` — town templates per faction:
```json
{
  "templates": {
    "small_outpost": {
      "size": "small",
      "pop_cap": 12,
      "buildings": ["tavern", "trader", "worktable"],
      "npc_count": 6
    },
    "medium_settlement": {
      "size": "medium",
      "pop_cap": 30,
      "buildings": ["tavern", "trader", "worktable", "armor_table", "blacksmith", "quest_board"],
      "npc_count": 15
    },
    "large_hub": {
      "size": "large",
      "pop_cap": 60,
      "buildings": ["tavern", "trader", "worktable", "armor_table", "blacksmith", "quest_board", "faction_hq", "auction_house"],
      "npc_count": 30
    }
  }
}
```

`data/factions.json` (existing, may extend) — each faction has:
- `town_template_pref`: ["medium_settlement", "small_outpost"] — preferred template order
- `color`: hex color for the minimap tint

`WorldGenerator._place_towns(seed, tile_map, faction_count, town_count)`:
- Choose `town_count` based on sphere size (e.g. 1 town per 25 hexes, minimum 4, maximum 10)
- Distribute towns by **even percentage of each faction** — if there are 4 factions and 8 towns, each faction gets exactly 2 towns. The placement is at evenly-distributed positions on the hex sphere (not adjacent to each other, not adjacent to Riftspire).
- For each town, assign a template based on the faction's `town_template_pref` (mostly medium_settlement, with one large_hub per faction per world).
- Towns occupy a single hex. The hex's biome is preserved (a desert town on Ash Wastes uses Ash Wastes tiles, just with extra buildings).

`data/towns_seeded.json` (generated at world gen time, persisted with the world):
```json
{
  "towns": [
    {"hex": "3,5",  "faction": "Iron Pact",     "template": "medium_settlement", "npcs": ["np_001", "np_002", ...]},
    {"hex": "-2,8", "faction": "Stormcrows",     "template": "medium_settlement", "npcs": [...]},
    {"hex": "7,-3", "faction": "Cinder Watch",   "template": "small_outpost",     "npcs": [...]},
    {"hex": "0,0",  "faction": "Riftspire (Capital)", "template": "riftspire_hand_authored", "npcs": [...]}
  ]
}
```

`LocalMapGenerator.generate()` — when a hex matches a town, the local map gets extra structure:
- Pre-placed `Worktable`, `ArmorTable`, `Blacksmith` buildings
- 6-30 NPCs (one per building + extras)
- Town layout is **procedural** (not hand-authored) for regular towns — a small clearing in the center, buildings around the edge, NPCs scattered
- Town NPCs are tagged `non_aggressive: true` in the NPC generation
- Town hexes have no mobs (or only the town's guard NPCs)

### Riftspire (the capital) — special hex

- **Exactly one Riftspire hex per world**, generated at world gen
- Its local map is **pre-generated / hand-authored** (not procedural) — saved as a static map_data
- Locked until the player reaches L50: "You sense a powerful presence beyond. Return when you are stronger." (L50 gating happens at hex-travel time in `GameState.travel_to_hex` or `LocalMapGenerator`)
- Once L50 is reached, Riftspire becomes fully accessible
- Layout: full city, no aggro NPCs, all factions represented, full of shops and quest givers

Riftspire has these districts/buildings (one each unless noted):
- **Faction HQs**: 4-6 buildings, one per major faction, each with a faction rep NPC (gives daily quests, opens faction-specific store)
- **Worktable Hall**: a building with all 3 stations (worktable, armor table, blacksmith) for convenience
- **Auction House**: special vendor, rotates rare items daily
- **Tavern**: rest area, rumor mill
- **Quest Board**: daily quests refresh
- **Travel Hub**: fast-travel to discovered hexes (consumes EC)
- **Skill Trainer**: re-spec / unlock abilities
- **Banks/Storages**: shared stash

Riftspire is "the endgame hub" — when the player wants to manage their loadout, sell loot, or pick up new quests, they go to Riftspire.

**Riftspire data**: a hand-authored `data/riftspire_layout.json` containing the static map_data (terrain PackedByteArray, NPC positions, building positions, portal/warp tile positions). Loaded by `LocalMapGenerator._load_riftspire_layout()` when the player enters the Riftspire hex.

### Riftspire entry conditions
```gdscript
# In HubWorld._try_cross_edge or WorldMapScreen.travel_to_hex
if target_hex == world_gen.riftspire_hex_key and gs.get_player_level() < 50:
    show_message("Riftspire awaits at Level 50. You are level %d." % gs.get_player_level())
    return false
```

---

## 6. Phase 4 — Equipment + weapons + armor + tools + accessories + stats

### New data files

`data/weapons.json` — flat list with one entry per (class, tier) pair:
```json
[
  {
    "id": "weapon_scavenger_t1",
    "class": "Scavenger",
    "tier": 1,
    "level_required": 1,
    "name": "Scrap Shiv",
    "sprite": "weapon_scavenger_t1",
    "damage": 4, "speed_bonus": 0, "range": 1,
    "stat_mods": {"str": 1}
  }
  // 6 classes × 26 tiers = 156 weapon entries
]
```

`data/armor.json` — flat list with one entry per (class, slot, tier) pair:
```json
[
  {
    "id": "armor_scavenger_head_t1",
    "class": "Scavenger",
    "slot": "head",
    "tier": 1,
    "level_required": 1,
    "name": "Scrap Visor",
    "sprite": "armor_scavenger_head_t1",
    "armor": 2, "stat_mods": {"con": 1}
  }
  // 6 classes × 4 slots × 13 tiers = 312 armor entries (template-scaled at load)
]
```

`data/tools.json` — **3 pickaxes (per ore tier) + 3 axes (per wood tier) + 1 stone axe + 1 stone pickaxe**. Tools live in the same `MainHand` equip slot as weapons; the hotbar handles swap.

```json
[
  {
    "id": "axe_stone",
    "type": "axe",
    "tier": 0,
    "level_required": 1,
    "name": "Stone Axe",
    "sprite": "tool_axe_stone",
    "harvests": ["all_tree_ids"],
    "speed_mult": 0.7,
    "category": "tool"
  },
  {
    "id": "pickaxe_stone",
    "type": "pickaxe",
    "tier": 0,
    "level_required": 1,
    "name": "Stone Pickaxe",
    "sprite": "tool_pickaxe_stone",
    "harvests": ["iron_outcrop"],
    "speed_mult": 0.7,
    "category": "tool"
  },
  {
    "id": "pickaxe_iron",
    "type": "pickaxe",
    "tier": 1,
    "level_required": 1,
    "name": "Iron Pickaxe",
    "sprite": "tool_pickaxe_iron",
    "harvests": ["iron_outcrop"],
    "speed_mult": 1.0,
    "category": "tool"
  },
  {
    "id": "pickaxe_copper",
    "type": "pickaxe",
    "tier": 2,
    "level_required": 20,
    "name": "Copper Pickaxe",
    "sprite": "tool_pickaxe_copper",
    "harvests": ["iron_outcrop", "copper_outcrop"],
    "speed_mult": 1.4,
    "category": "tool"
  },
  {
    "id": "pickaxe_starmetal",
    "type": "pickaxe",
    "tier": 3,
    "level_required": 60,
    "name": "Starmetal Pickaxe",
    "sprite": "tool_pickaxe_starmetal",
    "harvests": ["iron_outcrop", "copper_outcrop", "starmetal_outcrop"],
    "speed_mult": 1.8,
    "category": "tool"
  },
  {
    "id": "axe_rough",
    "type": "axe",
    "tier": 1,
    "level_required": 1,
    "name": "Rough Axe",
    "sprite": "tool_axe_rough",
    "harvests": ["all_tree_ids"],
    "speed_mult": 1.0,
    "category": "tool"
  },
  {
    "id": "axe_reinforced",
    "type": "axe",
    "tier": 2,
    "level_required": 25,
    "name": "Reinforced Axe",
    "sprite": "tool_axe_reinforced",
    "harvests": ["all_tree_ids"],
    "speed_mult": 1.5,
    "category": "tool"
  },
  {
    "id": "axe_masterwork",
    "type": "axe",
    "tier": 3,
    "level_required": 75,
    "name": "Masterwork Axe",
    "sprite": "tool_axe_masterwork",
    "harvests": ["all_tree_ids"],
    "speed_mult": 2.0,
    "bonus_yield": 1,
    "category": "tool"
  }
  // 7 tool entries total
]
```

**Tool ↔ weapon MainHand sharing**:
- `MainHand` slot accepts either a weapon or a tool
- When the player presses 1–0 in the hotbar and the slot holds a tool, the tool equips into MainHand
- When the player presses 1–0 and the slot holds a weapon, the weapon equips into MainHand
- A tool in MainHand shows the tool sprite in the character's hand visually
- A weapon in MainHand shows the weapon sprite in the character's hand visually
- Items with `category: "tool"` are filtered out of weapon slot UIs and vice versa

**Tool-gated harvesting rule** (in `HarvestNode.gather()` and `HubWorld._try_gather`):
- Read `EquipmentManager.get_main_hand_item()` to get the equipped item
- If equipped item has `category: "tool"` AND `node.id` is in the tool's `harvests` list → gather at `node.gather_secs / tool.speed_mult`, yield `qty` (plus `bonus_yield` if defined)
- If equipped item is a weapon or empty AND the node is a harvestable resource → refuse with "Equip an axe" or "Equip a pickaxe" (or "Stone Axe works on trees but not ore")
- If equipped tool's `harvests` doesn't include `node.id` → refuse with "Need a higher-tier pickaxe" (or axe)
- Special case: trees are harvestable with any tool that has `harvests: ["all_tree_ids"]` — that includes the Stone Axe and all metal axes. A pickaxe in MainHand won't chop trees.

**Stone tools entry point**:
- **Stone Axe**: crafted from 1 stick + 2 stones at L1, no station
- **Stone Pickaxe**: crafted from 1 stick + 2 stones at L1, no station
- Both are the first tools the player makes — they prove the progression works from minute 1
- Both slow (`speed_mult: 0.7` = 30% slower than the T1 metal version) but functional
- Stone Axe → any tree; Stone Pickaxe → iron_outcrop (the only T1 ore at L1 — copper and starmetal require their own tier pickaxes)

**Pickaxe tier ↔ ore tier mapping** (matches the 3 ore types from Phase 1):
| Pickaxe | Mines | Crafted at |
|---------|-------|-----------|
| Stone Pickaxe (T0) | iron_outcrop | Lv.1, no station: 1 stick + 2 stones |
| Iron Pickaxe (T1) | iron_outcrop | Lv.10 Blacksmith: 2 iron_ore + 1 withered_branch |
| Copper Pickaxe (T2) | iron + copper_outcrop | Lv.20 Blacksmith: 4 copper_ore + 1 iron_ore |
| Starmetal Pickaxe (T3) | iron + copper + starmetal_outcrop | Lv.60 Blacksmith: 3 starmetal_ore + 1 ember_crystal + 1 iron_ore |

**Axe tier ↔ wood tier mapping**:
| Axe | Fells | Bonus |
|-----|-------|-------|
| Stone Axe (T0) | any tree | 0.7× speed (slower than T1) |
| Rough Axe (T1) | any tree | 1.0× speed |
| Reinforced Axe (T2) | any tree | 1.5× speed |
| Masterwork Axe (T3) | any tree | 2.0× speed, +1 bonus yield per chop |

`data/accessories.json` — 10 hand-authored items (unchanged from earlier):
```json
[
  {"id": "luck_charm",      "name": "Luck Charm",       "effect": {"loot_bonus_pct": 5},   "description": "Slightly increases drop chance from mobs."},
  {"id": "scavenger_ring",  "name": "Scavenger's Ring", "effect": {"gather_speed_pct": 10}, "description": "Gather 10% faster from resource nodes."},
  {"id": "wanderer_boots",  "name": "Wanderer's Boots", "effect": {"move_speed_bonus": 1},   "description": "+1 tile per move on the local map."},
  {"id": "iron_grip",       "name": "Iron Grip",        "effect": {"stat_mods": {"str": 2}},"description": "+2 Strength."},
  {"id": "mindstone",       "name": "Mindstone",        "effect": {"stat_mods": {"int": 2}},"description": "+2 Intelligence."},
  {"id": "warden_charm",    "name": "Warden's Charm",   "effect": {"stat_mods": {"con": 2}, "hp_max_add": 15}, "description": "+2 Constitution, +15 max HP."},
  {"id": "rift_compass",    "name": "Rift Compass",     "effect": {"reveal_rift_range": 8}, "description": "Rifts within 8 tiles glow on the minimap."},
  {"id": "hunters_mark",    "name": "Hunter's Mark",    "effect": {"crit_bonus_pct": 3},    "description": "+3% critical hit chance."},
  {"id": "timepiece",       "name": "Timepiece",        "effect": {"cooldown_reduce_pct": 10}, "description": "Ability cooldowns tick 10% faster."},
  {"id": "echo_charm",      "name": "Echo Charm",       "effect": {"double_loot_pct": 5},  "description": "5% chance for double drops from mobs."}
]
```

### Equipment slots (8)
```
[Head] [Chest] [Legs] [Boots]
[MainHand] [OffHand]   ← MainHand accepts weapons AND tools (swapped via hotbar)
[Accessory1] [Accessory2]
```

### New screen: `scenes/ui/EquipmentScreen.tscn` + `EquipmentScreen.gd`
- Visual character sprite on the left (the existing 64x64 PlayerVisual), with armor layers overlaid
- 8 equip slot buttons on the right (4×2 grid)
- Click slot → opens inventory filter to compatible items
- "Add to Hotbar" button on any weapon/tool in inventory — adds to the next free hotbar slot
- Stats panel at the bottom: HP, MP, Attack, Defense, Speed, +stat bonuses from gear

### Sprite layering (Phase 4)
- The base `PlayerVisual` is the 64x64 character. Armor pieces are additional `Sprite2D` children parented at the same position. MainHand shows the currently equipped weapon OR tool sprite.
- Armor sprites via template + tint. `tools/generate_armor_sprites.py` produces 312 entries in one batch (procedural, no API cost).
- 156 weapons: same template approach. `tools/generate_weapon_sprites.py`.
- 7 tools: hand-authored small (pickaxe/axe shape with a tinted handle per tier). `tools/generate_tool_sprites.py` does 3 pickaxes + 3 axes + stone axe via PIL primitives (no API cost).
- Asset check at end of phase: confirm ~475 PNGs exist.

### Stat recompute
- `PlayerStats.compute(character_data, equipment) -> Dictionary`
  - Inputs: base class stats, level, equipment (incl. MainHand weapon or tool)
  - Outputs: total {hp_max, mp_max, attack, defense, speed, move_bonus, ...}
  - Cached on character sheet, invalidated on equip change / level up
- `GameState.set_equipment(...)` triggers recompute + signal

### Stats screen
- A tab inside `EquipmentScreen`.

### New manager: `scripts/EquipmentManager.gd` (autoload)
- `equipped: Dictionary` — slot_id → item_id (or null); 8 slots
- `equip(item_id, slot?) -> bool` (validates slot compatibility, incl. tool/weapon in MainHand)
- `unequip(slot) -> String` (returns item_id to inventory)
- `get_main_hand_item() -> Dictionary` (returns weapon or tool data)
- `get_stat_mods() -> Dictionary`
- Signals: `equipment_changed()`, `stat_recomputed()`

---

## 7. Phase 5 — Party joinable NPCs (procedural + invite)

**Goal:** Random NPCs with procedurally-generated race/class/gender/stats spawn in the world. Player can invite them to the party if level + faction rep + quest unlock requirements are met. Once invited, they join the combat party and can be dismissed (returning to the player's base, once Phase 6 lands).

### New manager: `scripts/PartyNPCManager.gd` (autoload)
- `available_npcs: Array[Dictionary]` — NPCs that exist in the world but aren't yet in the party
- `party_members: Array[Dictionary]` — NPCs currently in the party (separate from the existing companion system)
- `spawn_pending: bool` — flag for "should we spawn a new joinable NPC soon"
- `spawn_cooldown: float` — time until next spawn attempt
- Signals: `npc_invited(npc_id)`, `npc_dismissed(npc_id)`, `party_changed()`

### New data: `data/joinable_npc_templates.json`

Templates that define possible invite conditions and per-archetype behavior:
```json
{
  "templates": [
    {
      "id": "wanderer_common",
      "rarity": "common",
      "weight": 50,
      "min_player_level": 1,
      "min_faction_rep": null,
      "requires_quest": null,
      "biome_pref": "any",
      "shop_offerings": null,
      "description": "Just a wanderer. Easy to recruit early on."
    },
    {
      "id": "faction_officer",
      "rarity": "uncommon",
      "weight": 25,
      "min_player_level": 5,
      "min_faction_rep": {"faction": "iron_pact", "amount": 10},
      "requires_quest": null,
      "biome_pref": "any",
      "shop_offerings": null,
      "description": "An officer of one of the factions. Better gear, higher requirements."
    },
    {
      "id": "quest_unlock_vip",
      "rarity": "rare",
      "weight": 10,
      "min_player_level": 10,
      "min_faction_rep": null,
      "requires_quest": "intro_to_pact",
      "biome_pref": "any",
      "shop_offerings": null,
      "description": "Locked behind a quest. Powerful specialist."
    },
    {
      "id": "legendary_loners",
      "rarity": "legendary",
      "weight": 1,
      "min_player_level": 25,
      "min_faction_rep": {"faction": "any_top_faction", "amount": 50},
      "requires_quest": "any_late_quest",
      "biome_pref": "any",
      "shop_offerings": "weapon_specialist",
      "description": "Legendary NPCs with their own backstories. Open shops at your base if you treat them right."
    }
  ]
}
```

### Spawn rules
- When the player walks into a new local hubworld map, the manager rolls a spawn: 70% chance of spawning 0 NPCs, 25% chance of 1, 5% chance of 2.
- Spawn location: random walkable cell, not adjacent to the player, not adjacent to other NPCs.
- The NPC is generated from a template + random race/class/gender (uniform from `races.json` and `character_classes.json`).
- Stats are scaled to be within `player_level ± 10`. Use the existing class stat_mods as the base; scale by level.
- Equipment: NPCs start with a T1 weapon and T1 armor appropriate for their class.
- Names: assembled from `data/npc_name_parts.json` (already exists).

### NPC sprite reuse
- **Joinable NPCs use the existing character sprite pipeline** — no new NPC art in v0.4.0.
- Each NPC has a `race` and `gender` (set at generation time). The sprite is loaded from `res://assets/characters/{race}_{gender}/{race}_{gender}_base.png` (the same path the player uses for their visual).
- `JoinableNPCSprite.gd` (or just reuse the existing `CharacterVisual.gd`) handles sprite load + scale + NEAREST filter.
- This is "good enough" for v0.4.0 — players will see NPCs as their race/gender with their starting armor layered on. Cosmetic differences (clothing, hairstyle) can be added in a later phase.
- The `archetype` field (scavenger, soldier, medic, etc.) is purely behavioral — doesn't affect the sprite.

### Invite flow
1. Player walks near an NPC. NPC shows up as a marker with their name + class + level.
2. Player presses E (or right-click) → opens a small dialog with the NPC's name, class, level, and the invite requirements.
3. If the player meets all requirements → "Invite to Party" button is enabled. Clicking adds the NPC to `party_members` and removes them from `available_npcs` (they teleport to the player).
4. If the player doesn't meet requirements → button is disabled; the dialog shows which requirement is unmet ("Requires Iron Pact reputation 10 — you have 3").
5. If the player chooses not to invite → "Leave" button dismisses the dialog; NPC stays where they are.

### Party management
- Party size: unlimited (or 5 + (level / 25) — propose unlimited for v0.4.0).
- Each party member has their own HP/MP/equipment; they participate in combat (the existing FFT combat system already supports multiple party members).
- Right-click a party member in the HUD roster → "Dismiss to Base" (only works once base is built in Phase 6). Before base is built, dismiss = "release" (NPC disappears from world).
- Died party members: stay in the party as KO'd, recover after resting at the base.

### Save/load
- All available_npcs and party_members are part of the save state, keyed by npc_id.
- Spawn rules re-evaluate on game load (no fresh spawns until player re-enters a hex that hasn't been visited since the last save).
- The `CharacterSelection` screen has race buttons and class buttons. **Two side panels** — one for race, one for class — that update when a button is selected.
- **Race panel**: race name, lore paragraph, stat mods, preferred biomes, and any starting items. ~150-word lore per race.
- **Class panel**: class name, lore paragraph, stat mods, role, 2-3 of the most iconic abilities with descriptions (L1, L8, L20), max level.
- Layout: race list on left, race info panel center-left, class list center-right, class info panel right.
- The existing race/class JSON already has the data; this is mostly UI work + a `RichTextLabel` for each panel.
- `data/races.json` doesn't currently have `lore` — add a `lore` field to each race (or pull from `lore.md` if a per-race section exists). 150 words × 8 races = 1200 words; small.
- Same for `data/character_classes.json` — `lore` is already in the `description` field. May rename to `lore` for clarity, or just reuse.
- **No new code dependencies** — just UI + data.

### Hover tooltip 1-second dwell
- The hover tooltip from Phase 1b uses a 1-second dwell timer: tooltip only appears if the cursor stays on the same target for 1 full second. This avoids spam when the player moves the cursor across many tiles quickly.
- Implementation: `HoverTooltip` tracks `(target_id, hover_start_time)`. When target changes, reset timer. When `Time.get_ticks_msec() - hover_start_time >= 1000` and target is non-null, show tooltip. When target becomes null (cursor off-map), hide tooltip immediately.

### New asset buttons (all menus) — Phase 8
- Every menu/scene currently uses Godot's default `Button` style, which looks out of place against the pixel art.
- Generate a pixel-art button set via `tools/generate_button_assets.py`:
  - `assets/ui/button_default.png` (96×32), `button_hover.png`, `button_pressed.png`, `button_disabled.png`
  - A 9-slice (StyleBoxTexture) for variable-width buttons
  - Pixel-art font: `assets/ui/font_pixel.png` (BMFont format, generated from a TTF)
- Apply as a Godot theme (`assets/ui/theme.tres`) and set as the default theme in `project.godot` (`gui/theme/custom`).
- This single change unifies the look of: MainMenu, CharacterSelection, WorldGeneration, Options, PauseMenu, plus the new Phase 1-4 UI screens.
- **No new gameplay dependencies** — pure visual upgrade.
- Asset check at end of phase: confirm ~10 UI asset files exist.

### Unified Character menu
- Add a "Menu" button to the HubWorld HUD (top-right or bottom)
- Opens a Character menu with 4 buttons: Inventory / Equipment / Crafting / Stats
- Each button opens its respective screen
- ESC closes back to game
- The existing PauseMenu remains separate (handles save/load/quit)

### Save/load
- SaveManager gains fields: `inventory_state`, `progression`, `equipment`, `unlocked_recipes`, `node_state` (depleted nodes per hex + respawn timers), `hotbar`, `towns_seeded`
- Schema version bumped to 0.4.0
- Old saves: keep loading, but with empty inventory/equipment/progression

### Polish
- Loot popups (text floats up " +3 Iron Ore" when gathered)
- Sound effects (later phase; out of scope for 0.4.0)
- Item icons (procedural; generated with PIL)
- Color-code item rarity (common grey, uncommon green, rare blue, epic purple, legendary orange)

---

## 11. Asset generation strategy

**Every new content category ships with a procedural sprite generator in its phase.** No API calls; everything PIL-driven. Generated once, then committed.

| New content | Generator | Output | Estimated file count |
|-------------|-----------|--------|---------------------|
| Resource nodes (trees, formations, ore, crystals) | `tools/generate_nodes.py` | 24×24 PNGs | ~50 |
| Floor pickups (sticks, stones) | `tools/generate_floor_pickups.py` | 16×16 PNGs | 2 |
| Weapons (6 classes × 26 tiers) | `tools/generate_weapon_sprites.py` | 32×32 PNGs (procedural shape per class, tinted per tier) | 156 |
| Armor (6 classes × 4 slots × 13 tiers) | `tools/generate_armor_sprites.py` | 32×32 PNGs (procedural silhouette, tinted per tier) | 312 |
| Tools (3 pickaxes + 3 axes + stone axe + stone pickaxe) | `tools/generate_tool_sprites.py` | 32×32 PNGs | 8 |
| Base (10 upgrade levels) | `tools/generate_base_sprites.py` | 96×96 to 1536×1536 PNGs (grows with level) | 10 |
| Buttons + font | `tools/generate_button_assets.py` | 96×32 PNGs + 9-slice + BMFont | ~10 |
| Item icons | `tools/generate_item_icons.py` (new, run as part of Phase 2) | 24×24 PNGs | ~50 |
| Riftspire (hand-authored) | `tools/author_riftspire.py` | procedural helper for the static map | 1 map_data |
| Joinable NPC sprites | **REUSE existing** `assets/characters/{race}_{gender}_base.png` | (no new files) | 0 |
| **Total new asset files** | | | **~600** |

**Generation approach** for each category:
- Start with a base shape (rectangle, silhouette, icon)
- Add per-tier detail (more lines, shading, accents as tier increases)
- Apply a per-class/per-biome color palette
- Save as RGBA8 PNG, downscaled to fit the 24×24 / 32×32 / etc. target with `Image.NEAREST`

**All generators are idempotent** — if a file exists and the source parameters haven't changed, it's left alone (or `--force` to regenerate).

**Asset check at end of each phase**: `tools/verify_assets.py` (added in Phase 2) confirms all expected PNGs exist for the new content; CI-style check before moving to the next phase.

## 12. Data files summary

| File | Status | Rows |
|------|--------|------|
| `data/items.json` | NEW | ~50 items (raw mats + components + consumables + ammo + sticks + stones) |
| `data/resource_nodes.json` | NEW | 10 biomes × ~6 node entries + floor_pickup_density = ~60 entries |
| `data/recipes.json` | NEW | ~85 recipes (10 basic incl. stone axe, 30 worktable, 25 armor, 25 weapon/tool recipes) |
| `data/weapons.json` | NEW | 6 classes × 26 tiers = 156 (or template + 156 ids) |
| `data/armor.json` | NEW | 6 classes × 4 slots × 13 tiers = 312 (template-scaled) |
| `data/tools.json` | NEW | 8 entries (3 pickaxes + 3 axes + 1 stone axe + 1 stone pickaxe) |
| `data/accessories.json` | NEW | 10 hand-authored |
| `data/towns.json` | NEW | 3 templates (small/medium/large) per faction; placement happens at world gen |
| `data/riftspire_layout.json` | NEW | hand-authored static local map for the Riftspire capital hex |
| `data/joinable_npc_templates.json` | NEW | 4 templates (wanderer / faction officer / quest VIP / legendary loner) with invite conditions |
| `data/base.json` | NEW | 10 upgrade levels with sprite, cost, capacity, description |
| `data/base_shops.json` | NEW | 10 shop types + 10 NPC archetype → shop offerings |
| `data/races.json` | EDIT | add `lore` field (150 words × 8 races) |
| `data/factions.json` | EDIT | add `town_template_pref`, `color` (minimap tint) |
| `data/mobs.json` | EDIT | add `drops: Array[Drop]` to each mob |
| `data/loot_tables.json` | EDIT | cross-link items.json by id |

## 13. Scripts/scenes summary

### New scripts
- `scripts/HarvestNode.gd` — node entity; respects tool tier on gather
- `scripts/FloorPickup.gd` — small auto-pickup entity (stick/stone/etc.)
- `scripts/HoverTooltip.gd` — singleton or autoload; 1s dwell timer; identifies what's under mouse cursor
- `scripts/InventoryManager.gd` — autoload
- `scripts/ProgressionManager.gd` — autoload (XP/level/EC)
- `scripts/CraftingManager.gd` — autoload
- `scripts/EquipmentManager.gd` — autoload (8 slots; MainHand accepts weapons + tools)
- `scripts/PlayerStats.gd` — stat computation
- `scripts/LootRoller.gd` — drop table resolver
- `scripts/TownManager.gd` — town placement, town NPC tracking, Riftspire gating
- `scripts/PartyNPCManager.gd` — autoload; spawns joinable NPCs, manages invite flow, party members
- `scripts/PartyMemberGenerator.gd` — procedural race/class/gender/stats for joinable NPCs; **reuses `CharacterVisual.gd` for sprite rendering**
- `scripts/Base.gd` — base scene logic; level, capacity, residents, BaseManagerUI trigger
- `scripts/BaseManager.gd` — autoload; tracks base state, validates upgrades, manages shop offerings
- `scripts/ui/HUD.gd` — full in-game HUD: HP/MP/XP/EC, hotbar, minimap, menu button
- `scripts/ui/Hotbar.gd` — 10-slot hotbar; binds 1–0; calls `EquipmentManager.equip` on press
- `scripts/ui/Minimap.gd` — small minimap component; renders hexes, factions, rifts, Riftspire
- `scripts/ui/InventoryScreen.gd`
- `scripts/ui/EquipmentScreen.gd` (8-slot layout, 4×2)
- `scripts/ui/CraftingScreen.gd`
- `scripts/ui/WorktableUI.gd`, `ArmorTableUI.gd`, `BlacksmithUI.gd`
- `scripts/ui/BaseManagerUI.gd` — base level, capacity, residents, upgrade button, shop list
- `scripts/ui/BaseShopUI.gd` — vendor interface per shop_type
- `scripts/ui/PartyInviteUI.gd` — invite dialog with requirement checks (real flow lands in Phase 5; Phase 3 ships a placeholder)
- `scripts/ui/CharacterSelectInfo.gd` — TWO info panels (race + class)
- `tools/generate_nodes.py` — ~50 resource node sprites
- `tools/generate_floor_pickups.py` — 2 sprites (stick, stone)
- `tools/generate_armor_sprites.py` — 312 armor sprites
- `tools/generate_weapon_sprites.py` — 156 weapon sprites
- `tools/generate_tool_sprites.py` — 8 tool sprites (3 pickaxes + 3 axes + 1 stone axe + 1 stone pickaxe)
- `tools/generate_base_sprites.py` — 10 base sprites (procedural, increasing complexity)
- `tools/generate_item_icons.py` — ~50 item icons
- `tools/generate_button_assets.py` — UI button textures + font
- `tools/author_riftspire.py` — helper for hand-authoring the Riftspire map data (interactive CLI)
- `tools/verify_assets.py` — checks that all expected asset files exist for the current phase

### New scenes
- `scenes/HarvestNode.tscn`
- `scenes/Worktable.tscn`, `ArmorTable.tscn`, `Blacksmith.tscn`
- `scenes/ui/InventoryScreen.tscn`
- `scenes/ui/EquipmentScreen.tscn`
- `scenes/ui/CraftingScreen.tscn`
- `scenes/ui/WorktableUI.tscn`, `ArmorTableUI.tscn`, `BlacksmithUI.tscn`

### Modified scripts
- `project.godot` — add 6 new autoloads (InventoryManager, CraftingManager, EquipmentManager, ProgressionManager, PartyNPCManager, BaseManager); set `gui/theme/custom = res://assets/ui/theme.tres`
- `scripts/GameState.gd` — wire to new managers; add inventory/progression/equipment/hotbar/party/base state to save; add level getter for Riftspire gating
- `scripts/SaveManager.gd` — extend payload with party, base, available_npcs
- `scripts/LocalMapGenerator.gd` — emit resource_nodes + floor_pickups, drop rift_scar, special-case the Riftspire hex, inject base when applicable
- `scripts/LocalMapView.gd` — host NodeLayer for HarvestNodes + FloorPickups; expose hover hit-test API
- `scripts/HubWorld.gd` — gather action (with tool tier check), interact prompt, HUD wiring, hover tooltip, Riftspire entry check, base interaction, party member rendering
- `scripts/WorldGenerator.gd` — town placement (`_place_towns`), Riftspire placement, `riftspire_hex_key` accessor
- `scripts/TileSetService.gd` — drop rift_scar
- `scripts/CombatEncounterBuilder.gd` (or new) — wire drops on victory
- `scripts/CharacterSelection.gd` — show TWO info panels (race + class) on selection
- `scripts/CombatEncounterBuilder.gd` — combat party includes invited party members (not just player + companions)
- `scripts/NPCManager.gd` — extended to handle joinable NPC tracking (or PartyNPCManager takes over)

### Modified scenes
- `scenes/HubWorld.tscn` — add full HUD layer (top bar, minimap, hotbar), NodeLayer, FloorPickupLayer, base hook
- `scenes/CharacterSelection.tscn` — add TWO info panels (race info center-left, class info center-right)
- `scenes/ui/PauseMenu.tscn` — add "Character" button
- `scenes/ui/MainMenu.tscn`, `WorldGeneration.tscn`, `Options.tscn` — pick up the new theme automatically
- New: `scenes/Base.tscn` — base scene (auto-placed on L10)
- New: `scenes/ui/BaseManagerUI.tscn` — base management UI
- New: `scenes/ui/BaseShopUI.tscn` — shop UI
- New: `scenes/ui/PartyInviteUI.tscn` — invite dialog
- New: `scenes/Riftspire.tscn` (special hand-authored scene) OR the standard `HubWorld.tscn` driven by `data/riftspire_layout.json` (proposing the latter — same code path, just different map_data)

## 14. Per-phase delivery workflow (the new rule)

**At the end of each phase, I stop, update the project, push to git, and wait for explicit permission to proceed to the next phase.** No auto-chaining.

### Workflow steps (executed at the end of every phase)

1. **Run the test suite** to confirm the phase shipped cleanly:
   - `validate_scripts.gd` (compile check)
   - `tools/smoke_tile_system.gd` (TileSet/LocalMapView/MobVisual smoke)
   - `tools/boot_probe.gd` (MainMenu boots 60 frames clean)
   - `tools/verify_assets.py` (asset files present, if it exists by that phase)
   - Any new test script added during the phase (e.g. `tools/smoke_crafting.gd` in Phase 3)

2. **Update the project's shared memory layer**:
   - `memory/CURRENT_STATE.md` — flip the phase to "complete", note what shipped, list any known issues
   - `docs/NEXT_TASKS.md` — move the just-finished phase to the COMPLETED section, surface the next phase as TOP PRIORITY
   - `memory/PROJECT_MEMORY.md` — append any new conventions, gotchas, or new system behaviors learned this phase
   - `memory/SESSION_NOTES/HANDOFF_YYYY-MM-DD_HHMM.md` — write the full 9-section handoff per `docs/HANDOFF_PROTOCOL.md`
   - `memory/LATEST_HANDOFF.md` — point at the new handoff file
   - Run the `backup-memory` skill → copies to `backups/YYYY-MM-DD_HHMM_<label>/`

3. **Commit the phase to git**:
   - `git add -A` (adds all changes, including new asset files, modified scripts, updated memory)
   - `git status` (sanity check)
   - `git commit -m "v0.4.0 Phase N: <phase name>"`
   - `git push origin master` (pushes to the configured remote)
   - If `git push` fails (auth, network), I report the error and ask the user how to proceed (e.g. "do you have a credential helper configured? want me to retry, or commit locally only?")

4. **Stop and report** to the user:
   - One concise summary of what shipped in the phase
   - Test results (all green? any warnings?)
   - The commit hash + push status
   - The next phase's scope (so the user knows what's about to start)
   - **Explicit wait for "go" before starting the next phase**

5. **Do not start the next phase** until the user says go (or "use defaults" / "proceed").

### Git configuration (already in place)

- Remote: `https://github.com/AhmiDarrow/FallenEarth.git` (origin)
- Default branch: `master`
- `.gitignore` is comprehensive (covers Godot 4 generated, Python cache, saves, IDE files)
- 282 files are currently uncommitted — these are the v0.3.0 work done before this rule. **Decision needed**: commit them as a single "v0.3.0 baseline" before Phase 0, or fold them into Phase 0.

### Backup before each commit

The `backup-memory` skill is run before the commit. Backup goes to `backups/YYYY-MM-DD_HHMM_pre_phase_N/`. If a commit fails or needs to be reverted, the backup gives us a clean restore point.

### How I report at the end of a phase

```
✅ Phase N complete: <phase name>
  - Tests: validate_scripts OK, smoke OK, boot_probe OK
  - Files added: <count>; modified: <count>; deleted: <count>
  - Commit: <hash> pushed to origin/master
  - Handoff: memory/SESSION_NOTES/HANDOFF_<timestamp>.md
  - Next phase: Phase N+1 — <brief scope>

Awaiting permission to start Phase N+1.
```

### What happens if a phase ships broken

- The test suite fails → I fix it before committing. The commit message reflects "fixes" not "ships".
- The user reviews the diff and rejects → I revert (`git reset --hard HEAD~1` or `git revert <hash>`) and start over from the previous known-good commit.
- The user wants changes → I make changes in the same phase, recommit (amend or new commit), repush.

### Per-phase checklist (added to §15 delta table as we go)

- [ ] Phase 0: drop rift_scar tile
- [ ] Phase 1: resource nodes + gathering + sticks/stones
- [ ] Phase 1b: hover tooltips
- [ ] Phase 2: full HUD + hotbar + minimap
- [ ] Phase 3: crafting + NPC towns + Riftspire
- [ ] Phase 4: equipment + weapons + armor + tools + accessories
- [ ] Phase 5: party joinable NPCs
- [ ] Phase 6: base building
- [ ] Phase 7: base shops
- [ ] Phase 8: integration, save/load, polish

## 15. Risks and decisions to confirm

- **Tools share MainHand with weapons:** no separate Tool slot. The hotbar handles swap. Both Stone Axe AND Stone Pickaxe are entry tools (1 stick + 2 stones, no station, L1). Confirm.
- **Hotbar size:** 10 slots bound to keys 1–0. Confirm 10 (or want 8 / 12)?
- **Stone tools speed mult 0.7** (slower than T1 metal) — confirms the value of upgrading. Confirm (or want it even slower at 0.5)?
- **Riftspire L50 gate:** players under L50 see a message when they try to enter. Confirm L50 threshold (or want L40 / L60)?
- **Riftspire is one hex per world** (cannot be entered via hex walk from neighbors — must travel via World Map). Confirm this isolation, or want it adjacent to a normal hex?
- **NPC town count:** roughly 1 town per 25 hexes (4-10 towns per world). Even percentage of faction representation. Confirm count formula, or want fixed N (e.g. exactly 6)?
- **Town placement rule:** no two adjacent towns; at least 2 hexes from Riftspire. Confirm, or different rule?
- **NPC town template pref:** medium_settlement by default, one large_hub per faction per world, small_outpost as flavor. Confirm.
- **Tooltip dwell:** 1 second before tooltip appears. Confirm (or want 0.5s / 1.5s)?
- **Tooltip on what:** ground tiles, resource nodes, mobs, NPCs, rifts, stations. Anything else (player, items on ground, etc.)?
- **Tooltip style:** small Label that follows the mouse cursor, with a 1-second dwell delay. Confirm.
- **Button art scope:** generated pixel-art button set applied globally via `gui/theme/custom`. This affects every existing menu scene. Confirm OK to override the theme.
- **Race lore length:** 150 words per race × 8 races = 1200 words. Confirm length.
- **Two info panels:** separate race panel and class panel on the character creation screen, side by side. Confirm layout.
- **Party joinable NPC spawn rate:** 25% chance per hex visit, 1-2 NPCs. Confirm (or want more/less frequent)?
- **CharacterMenu hotkeys:** `I` `E` `C` `P` `S` for tabs + `Tab`/`Shift+Tab` cycle + `Esc` close. Confirm (or want WASD or different binding)?
- **Party tab in Phase 3 (placeholder) or wait for Phase 5 (real):** Phase 3 ships the tab UI with a hard-coded `available_npcs` list of 2-3 test NPCs. Phase 5 replaces with procedural generation. Confirm or want a different placeholder?
- **NPC level scaling:** within ±10 levels of player. Confirm (or want a fixed level range like 5-15)?
- **Party member combat:** joinable NPCs participate in FFT combat as party members. Confirm (or do they stay out of combat)?
- **Base placement:** at L10, the player clicks a cell on the local map to place the first hut. Cell must be at least 50 tiles from any map edge. Confirm.
- **Base upgrade level curve:** L10 (initial) → L20 → L30 → L45 → L65 → L90 → L120 → L150 → L175 → L200 (final). Confirm or adjust.
- **Base upgrade cost formula:** `cost_ec(level) = round(100 * level^1.8)`. Material costs per upgrade. Level gate. Confirm or adjust.
- **Base capacity:** +5 per upgrade, base 5, max 50 (at L200). Confirm.
- **Base shop system (Phase 7):** 10 shop types, 10 NPC archetypes → 10 offerings. Cost ranges 200-5000 EC. Confirm.
- **NPC sprite reuse:** joinable NPCs use the existing `assets/characters/{race}_{gender}_base.png` sprites (same as the player). No new NPC art in v0.4.0. Confirm.
- **Settlement naming at 20 NPCs:** when residents reach 20, the player can name the settlement; the name appears on the World Map. Confirm or adjust (e.g. 15 or 25 NPCs).
- **Base visual growth:** each upgrade makes the building visibly bigger and more detailed (extra buildings, walls, watchtowers). Sprite `size_tiles` scales from [4,4] (T1) to [64,64] (T10). Confirm.
- **Final upgrade visual:** "full on big base of operations" — multiple wings, watchtowers, walls, gate, gardens, as one composite sprite. Confirm.
- **Asset strategy:** every new content category ships with a procedural sprite generator in its phase. ~600 new asset files total. Confirm OK with this scope.
- **Rift design (already implemented):** procedural RiftInstance, 75% boss at end, close mechanism returns player to upworld entry position. Verifying this matches the current design — no changes needed unless something is missing.

---

## 11. Open questions for you

1. **Phase 0 first** (drop rift_scar tile) — confirm OK?
2. **Armor tier count** — confirm 13 tiers per slot per class? Or simpler (8 tiers, 4 levels each)?
3. **Stations in start hex vs global Outpost** — both? Or just one?
4. **Class → weapon type mapping** — confirm: Scavenger=blade, Technician=pistol, Survivor=rifle, Striker=heavy blade, Riftbinder=focus/staff, Warden=shield+hammer?
5. **Inventory capacity** — 30 slots feels right for a 2.5D RPG. Bump to 50?
6. **Currency name** — EarthCoin or EC. The user said both. I'll use "EarthCoin" in UI, "EC" in code.

## 12. Next steps

1. You review this plan, mark anything to add/remove.
2. I confirm ambiguities above.
3. We start Phase 0 immediately (it's a 30-min cleanup).
4. After Phase 0, we decide whether to chain 1-2-3-4 in this session or split.

---

## 15. v0.4.0 changes from this revision (vs initial draft)

| Section | Change |
|---------|--------|
| Phase 1 | +Sticks and stones floor pickups; +`stone_axe_basic` recipe (1 stick + 2 stones → Stone Axe); the entire progression starts at L1 with zero stations. |
| Phase 1b | Tooltip dwell is now **1 second** (was instant). |
| Phase 2 | HUD is now a full in-game Character HUD (HP/MP/XP/EC, level, minimap, hotbar). +10-slot hotbar bound to 1–0. +Small minimap. |
| Phase 3 | +NPC town placement during world gen (even faction percentage, 3 templates). +Riftspire capital hex (exactly one per world, L50 gate, hand-authored layout, full city of shops/quest givers). |
| Phase 4 | **Tools share MainHand with weapons (no separate Tool slot).** Hotbar handles swap. +Stone Axe as T0 entry tool. +7 tools total (3 pickaxes + 3 metal axes + 1 stone axe). |
| **Phase 5 (new)** | **Party joinable NPCs** — random procedural spawn of race/class/gender NPCs; **reuse existing character sprites** (no new NPC art); invite conditions (level + faction rep + quest unlock); party roster and dismiss flow. |
| **Phase 6 (new)** | **Base building** — L10 unlock, auto-placed first hut, 10 upgrade levels with +5 capacity each, sprite grows with level. |
| **Phase 7 (new)** | **Base shops** — 10 NPC-initiated shop types, opening cost scales by archetype, base becomes a service hub. |
| Phase 8 (renumbered) | Character creation info panels (2 separate) + unified menu + button assets + save/load + polish. |
| **Asset strategy (new section 11)** | Every new content category ships with a procedural sprite generator in its phase. ~600 new asset files total. `tools/verify_assets.py` runs at the end of each phase to confirm. |
| Data files | +`data/joinable_npc_templates.json` (4 templates), +`data/base.json` (10 upgrade levels), +`data/base_shops.json` (10 shops + 10 offerings). |
| Scripts | +`scripts/PartyNPCManager.gd`, +`scripts/PartyMemberGenerator.gd`, +`scripts/Base.gd`, +`scripts/BaseManager.gd`, +`scripts/ui/BaseManagerUI.gd`, +`scripts/ui/BaseShopUI.gd`, +`scripts/ui/PartyInviteUI.gd`, +`tools/generate_base_sprites.py`, +`tools/generate_item_icons.py`, +`tools/verify_assets.py`. |
| Time estimate | 32-43h → 44-58h (added ~12-15h for party + base + base-shops, +~1h for asset verification). |

---

*This is a Remedy plan. If you want me to start coding Phase 0 right now while you finish reviewing, say "go" and I'll begin.*
