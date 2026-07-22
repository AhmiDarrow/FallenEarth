# ARCHITECTURE — Fallen Earth Godot Project + Multi-Agent Workflow

**Version:** 0.12.0 (Godot 4.7.1) · **Save format:** 0.5.0 · See `docs/VERSION.md`

## Table of Contents
1. [Game Architecture](#game-architecture)
2. [Autoload Stack (37 Total)](#autoload-stack-37-total)
3. [UI Theming System](#ui-theming-system)
4. [Helper Modules](#helper-modules)
5. [Data System](#data-system)
6. [Event System](#event-system)
7. [Modding System](#modding-system)
8. [Script Directory Map](#script-directory-map)
9. [Game Flow](#game-flow)
10. [Two-Layer World Model](#two-layer-world-model)
11. [Anti-Duplication: What NOT to Create](#anti-duplication-what-not-to-create)
12. [Multi-Agent Workflow](#multi-agent-workflow)

---

## Game Architecture

- **Godot 4.7.1 Project** with 37 autoloads for global managers.
- **Data-driven core**: All content defined in `data/*.json`. Scripts load and interpret at runtime via `DataRegistry`.
- **UI**: Every UI screen uses `UIHelper` + `MasterTheme` — never raw Control node creation.

---

## Autoload Stack (37 Total)

Ordered by load priority (top loads first):

| # | Name | File | Role |
|---|------|------|------|
| 1 | `ModLoader` | `scripts/ModLoader.gd` | Discovers, validates, dependency-sorts, loads mods |
| 2 | `ModAPI` | `scripts/ModAPI.gd` | Extension registry: overlays, saves, UI extensions, settings |
| 3 | `ThemeManager` | `scripts/ThemeManager.gd` | Runtime theme switching (8 built-in themes), persistence |
| 4 | `EventBus` | `scripts/EventBus.gd` | Global signal bus with before/after hooks for mod interception |
| 5 | `DataRegistry` | `scripts/DataRegistry.gd` | Centralized JSON loading with mod overlay merge |
| 6 | `SaveManager` | `scripts/SaveManager.gd` | Save/load game state |
| 7 | `GameState` | `scripts/GameState.gd` | Runtime game state singleton |
| 8 | `RaceManager` | `scripts/RaceManager.gd` | Race data and logic |
| 9 | `ClassManager` | `scripts/ClassManager.gd` | Character class data and logic |
| 10 | `AppearanceManager` | `scripts/AppearanceManager.gd` | Character appearance/procedural visuals |
| 11 | `DisplayManager` | `scripts/DisplayManager.gd` | Display/resolution management |
| 12 | `GameManager` | `scripts/GameManager.gd` | Core game loop, scene transitions |
| 13 | `RiftRunner` | `scripts/RiftRunner.gd` | Rift lifecycle: spawn, enter, clear, collapse |
| 14 | `GraphicsManager` | `scripts/GraphicsManager.gd` | Graphics quality settings |
| 15 | `NPCManager` | `scripts/NPCManager.gd` | NPC spawning, faction rep |
| 16 | `MissionManager` | `scripts/MissionManager.gd` | Quest/mission lifecycle |
| 17 | `InventoryHandler` | `scripts/InventoryHandler.gd` | Inventory management |
| 18 | `DragHandler` | `scripts/ui/components/DragHandler.gd` | Drag-and-drop for inventory slots |
| 19 | `ProgressionManager` | `scripts/ProgressionManager.gd` | XP, leveling, EC currency |
| 20 | `PartyNPCManager` | `scripts/PartyNPCManager.gd` | Party NPC recruitment/dismissal |
| 21 | `CraftingManager` | `scripts/CraftingManager.gd` | Recipe unlocking and crafting |
| 22 | `TownManager` | `scripts/TownManager.gd` | Town data and state |
| 23 | `SettlementManager` | `scripts/SettlementManager.gd` | Settlement management |
| 24 | `EquipmentManager` | `scripts/EquipmentManager.gd` | Equipment slots and changes |
| 25 | `BaseManager` | `scripts/BaseManager.gd` | Player home base logic |
| 26 | `BaseShopManager` | `scripts/BaseShopManager.gd` | Base shop offerings |
| 27 | `DialogueManager` | `scripts/DialogueManager.gd` | NPC dialogue system |
| 28 | `QuestTracker` | `scripts/QuestTracker.gd` | Quest tracking |
| 29 | `LoadingTips` | `scripts/LoadingTips.gd` | Loading screen tips |
| 30 | `AmbientAudio` | `scripts/AmbientAudio.gd` | Ambient sound management |
| 31 | `MusicManager` | `scripts/MusicManager.gd` | Music playback |
| 32 | `KeybindManager` | `scripts/KeybindManager.gd` | Keybinding configuration |
| 33 | `TamedMobManager` | `scripts/TamedMobManager.gd` | Tamed creature management |
| 34 | `NetworkManager` | `scripts/network/NetworkManager.gd` | Multiplayer networking core |
| 35 | `LobbyManager` | `scripts/network/LobbyManager.gd` | Lobby creation/joining |
| 36 | `NetworkSync` | `scripts/network/NetworkSync.gd` | State sync across peers |
| 37 | `PlayerPartyManager` | `scripts/network/PlayerPartyManager.gd` | Player group management |
| 38 | `ChatManager` | `scripts/network/ChatManager.gd` | In-game chat |
| 39 | `TradeManager` | `scripts/network/TradeManager.gd` | Player-to-player trading |
| 40 | `RespawnManager` | `scripts/RespawnManager.gd` | Player death/respawn |
| 41 | `MobManager` | `scripts/MobManager.gd` | Mob lifecycle management |

---

## UI Theming System

**Architecture**: MasterTheme (design tokens + factories) → UIHelper (widget factory) → UI Screens

### MasterTheme (`assets/ui/MasterTheme.gd`)
`class_name MasterTheme extends RefCounted`

The **single consolidated UI theming module**. Import in any script with:
```gdscript
const MT = preload("res://assets/ui/MasterTheme.gd")
```

**Provides:**
- **Color Palette** (Section 1): `BG_DEEP`, `BG_SURFACE`, `BG_ELEVATED`, `BG_INPUT`, `BG_PANEL`, `BORDER_SUBTLE`, `BORDER_STRONG`, `BORDER_INPUT`, `ACCENT_PRIMARY/SECONDARY/DANGER/SUCCESS/NEON`, `TEXT_PRIMARY/SECONDARY/MUTED/ACCENT/DANGER/SUCCESS/LINK`, `HP_FILL/BG`, `MP_FILL/BG`, `XP_FILL/BG`, `RARITY_*` (5 tiers), `OVERLAY_DARK/LIGHT`, `SELECTED_BG/TINT`, `GLOW_PRIMARY/RIFT`, minimap colors (`MM_*`)
- **Font constants** (Section 2): `FS_HERO`(42), `FS_H1`(28), `FS_H2`(22), `FS_H3`(18), `FS_BODY`(14), `FS_SMALL`(12), `FS_TINY`(10), `FS_STAT`(16), `FS_BUTTON`(16)
- **Spacing constants** (Section 2): `SPACE_XS`(4) through `SPACE_3XL`(48)
- **Radius constants**: `RADIUS_SM`(2), `RADIUS_MD`(4), `RADIUS_LG`(6), `RADIUS_XL`(8)
- **StyleBox Factory** (Section 3): `panel()`, `input_field()`, `focus_ring()`, `button_stylebox()`, `bar_background()`, `bar_fill()`, `scrollbar_grabber()`, `tooltip()`
- **Button Styles** (Section 4): `apply_button_style(btn, variant)` — variants: `primary`, `secondary`, `danger`, `success`, `ghost`
- **Theme Builder** (Section 6): `apply_to(window)` / `apply_theme_to_control(control)` — builds a complete Godot Theme resource
- **Fonts**: Inter (Regular, Bold, Italic) from `assets/fonts/extras/ttf/`
- **Runtime theme switching**: `apply_theme_data(data)` — called by ThemeManager

### UIHelper (`scripts/ui/UIHelper.gd`)
`class_name UIHelper extends RefCounted`

**Central factory for ALL themed UI elements.** Every UI screen MUST use UIHelper methods instead of creating raw Control nodes.

Import pattern:
```gdscript
const UH = preload("res://scripts/ui/UIHelper.gd")
```

**Factory methods:**
| Category | Methods |
|----------|---------|
| **Buttons** | `make_button(text, variant, min_w, min_h, is_toggle)`, `make_icon_button(icon_text, variant, min_w, min_h)` |
| **Labels** | `make_label(text, font_size, color)`, `make_small_label(text, color)`, `make_muted_label(text)`, `make_accent_label(text, font_size)`, `make_success_label(text, font_size)`, `make_danger_label(text, font_size)` |
| **Rich Text** | `make_rich_header(text, min_height)`, `make_rich_section(text, min_height, color)` |
| **Inputs** | `make_line_edit(placeholder, min_w, min_h)` |
| **Selectors** | `make_checkbox(text)`, `make_option_button(items, min_w, min_h)` |
| **Sliders** | `make_slider(min_val, max_val, step_val, default_val, min_w)` |
| **Progress** | `make_progress_bar(min_w, min_h, fill_color, bg_color)` |
| **Containers** | `make_vbox(separation, expand_h, expand_v)`, `make_hbox(separation, expand_h)`, `make_margin(amount)`, `make_center_hbox()` |
| **Panels** | `make_panel(bg, border, radius, border_width, min_size)`, `make_surface_panel(min_size)`, `make_elevated_panel(min_size)` |
| **Scroll** | `make_scroll_container(expand_v)`, `make_scrollable_vbox(parent, separation)`, `make_scrollable_section(parent, header_text, separation)` |
| **Tabs** | `make_tab_container()` |
| **Separators** | `make_separator()` |
| **Backdrop** | `make_backdrop(color)`, `apply_backdrop(parent, color)` |
| **Form Rows** | `make_option_row(parent, label_text, label_w, control_w)`, `make_check_row(parent, label_text, label_w)`, `make_slider_row(parent, label_text, label_w, slider_w, default_val)` |
| **Modals** | `build_modal_screen(parent_size, title, panel_w, panel_h)` |
| **Responsive** | `make_scrollable(vbox)`, `make_page_shell(parent, bg_color, margin_*, separation)` |
| **Sizing** | `compute_top_bar_height()`, `compute_status_block_height()` |

### ButtonStyleHelper (`scripts/ButtonStyleHelper.gd`)
`class_name ButtonStyleHelper extends RefCounted`

**Backward-compatibility wrapper.** Entirely delegates to `MasterTheme`. All methods (`apply_style`, `apply_primary`, `apply_secondary`, `apply_danger`, `apply_success`, `apply_ghost`, `apply_focus`, `get_available_styles`, `apply_all_states`) just call `MT.*` equivalents. No new code should use this — use `MT.apply_button_style()` directly.

### ThemeManager (`scripts/ThemeManager.gd`)
Autoload singleton. **Runtime theme switching** with persistence to `user://options.cfg`.

**Built-in themes (8):**
| Name | Display | Palette Style |
|------|---------|---------------|
| `twilight` | Twilight | Purple-tinted (default) |
| `ember` | Ember | Warm red/orange |
| `frost` | Frost | Cool blue/cyan |
| `viridian` | Viridian | Green |
| `nocturne` | Nocturne | Dark with hot pink accents |
| `abyss` | Abyss | Pure grayscale dark |
| `ochre` | Ochre | Gold/yellow on dark |
| `terra` | Terra | Original warm earth tones (empty data = MasterTheme defaults) |

**API**: `register_theme(mod_id, name, display_name, data)`, `get_themes()`, `get_current_theme()`, `apply_theme(name)`, `theme_changed` signal.

---

## Helper Modules

### Constants (`scripts/Constants.gd`)
`class_name Constants extends RefCounted`

Minimal global constants: `CELL_SIZE`(64), `MAP_SIZE`(512), `TILE_SIZE`(16), `HALF_MAP`(256).

### Terrain System (`scripts/terrain/TerrainSystem.gd`)
`class_name TerrainSystem extends RefCounted`

Unified terrain tile pipeline: loads PixelLab Wang metadata+PNG pairs, builds single atlas TileSet, paints vertex-Wang terrain onto TileMapLayer. See `docs/WANG_TERRAIN.md` for full architecture.

### Other shared scripts (non-autoload, preloaded as needed):
| Script | Import Path | Purpose |
|--------|-------------|---------|
| `TerrainSystem.gd` | `res://scripts/terrain/TerrainSystem.gd` | Terrain tile loading + painting |
| `LocalMapGenerator.gd` | `res://scripts/LocalMapGenerator.gd` | Procedural 512x512 terrain generation |
| `LocalMapView.gd` | `res://scripts/LocalMapView.gd` | Terrain rendering + entity management |

---

## Data System

### DataRegistry (`scripts/DataRegistry.gd`)
Autoload #5. **Centralized JSON loading with mod overlay merge.**

Loads 31 base game JSON files from `data/`:
`items`, `weapons`, `armor`, `accessories`, `tools`, `recipes`, `mobs`, `biomes`, `resource_nodes`, `factions`, `dialogue`, `missions` (mission_templates), `races`, `classes` (character_classes), `appearance`, `towns`, `base`, `base_shops`, `loot_tables`, `tips`, `joinable_npc_templates`, `npc_name_parts`, `npc_archetypes`, `enemy_archetypes`, `mob_sprites`, `settlement_rooms`, `riftspire_layout`, `seeds`, `story_chapters`, `dynamic_threat`, `tame_config`

**Overlay merge strategies** (for mods):
- `merge` — deep dictionary merge (default)
- `append` — append arrays within matching keys
- `override` — wholesale replacement
- `patch` — JSON Patch (RFC 6902) operations

**API**: `get_data(key)` returns merged result, `get_base(key)` returns unmodified base data, `clear_cache(key)` invalidates merge cache.

---

## Event System

### EventBus (`scripts/EventBus.gd`)
Autoload #4. **Global signal bus with before/after hooks.**

All game events flow through EventBus. Connected signals from: `GameState`, `InventoryHandler`, `ProgressionManager`, `MissionManager`, `RiftRunner`, `NPCManager`, `PartyNPCManager`, `EquipmentManager`, `CraftingManager`, `BaseManager`, `BaseShopManager`, `TamedMobManager`, `RespawnManager`, `ChatManager`, `LobbyManager`, `PlayerPartyManager`, `GameManager`.

**Hook system**: Mods can register `before` hooks (can modify data or `cancel()` the event) and `after` hooks (reactive). Hooks sorted by priority.

**Key events**: `character_created`, `game_saved`, `game_loaded`, `active_scene_changed`, `level_up`, `xp_gained`, `inventory_changed`, `mission_*`, `rift_*`, `npc_recruited`, `faction_rep_changed`, `equipment_changed`, `recipe_*`, `base_*`, `shop_*`, `tamed_mob_*`, `mount_changed`, `player_respawning`, `message_received`, `lobby_*`, `party_*`, `scene_changed`.

---

## Modding System

### ModLoader (`scripts/ModLoader.gd`)
Autoload #1. Scans `user://mods/` and `res://user/mods/`, parses `mod.cfg` manifests, resolves dependencies via topological sort (Kahn's algorithm), loads entry scripts. Signals: `mods_loaded`, `mod_failed`.

### ModAPI (`scripts/ModAPI.gd`)
Autoload #2. Extension registry:
- **Data overlays**: `register_data_overlay(mod_id, key, data, strategy)`
- **Save data**: `register_save_key(mod_id, key, getter, setter)`
- **Snapshot managers**: `register_snapshot_manager(mod_id, path, key, wrapper_key)`
- **UI extensions**: `add_tab()`, `add_hud_overlay()`, `add_pause_menu_entry()`
- **Theme registration**: `register_theme(mod_id, name, display_name, data)`
- **Settings**: `register_setting()`, `get_setting()`, `set_setting()`
- **Scene injection**: `add_scene_to(parent_path, scene_path)`
- **Logging**: `log(mod_id, message, level)`

---

## Script Directory Map

```
scripts/
├── ai/                        # AI controllers
│   ├── AggressiveAI.gd        # Aggressive enemy behavior
│   ├── BossAI.gd              # Boss fight AI
│   ├── CasterAI.gd            # Spellcaster AI
│   ├── CombatAI.gd            # Base combat AI
│   ├── CombatAIEngine.gd      # Combat AI state machine
│   ├── DefensiveAI.gd         # Defensive enemy behavior
│   └── RangedAI.gd            # Ranged combat AI
│
├── combat/                    # Tactical combat system
│   ├── models/arena/          # Arena resource definitions
│   ├── models/participant/    # Combat participant data
│   ├── models/tile/           # Tile resource definitions
│   ├── models/unit/           # Unit resource definitions
│   ├── services/              # Combat services
│   │   ├── BiomeTileService.gd
│   │   ├── opponent/opponent_service.gd
│   │   ├── pathfinding/pathfinding_service.gd
│   │   ├── player/player_service.gd
│   │   ├── turn/turn_service.gd
│   │   └── unit/              # unit_combat_service, unit_movement_service
│   ├── ui/                    # Combat UI
│   │   ├── BattleResultsUI.gd
│   │   ├── CombatActionPanel.gd
│   │   ├── EnemyInfoPanel.gd
│   │   ├── PlayerStatsPanel.gd
│   │   └── TopPromptV110.gd
│   └── v2/                    # 3D combat refactor
│       ├── CombatArena3D.gd
│       ├── CombatLevel3D.gd
│       ├── CombatPawn3D.gd
│       ├── CombatTile3D.gd
│       ├── DestructibleDecor.gd
│       ├── TacticsCamera3D.gd
│       ├── TacticsInput3D.gd
│       └── UnitMovementService3D.gd
│
├── mob/                       # Mob/creature system
│   ├── MobAIController.gd
│   ├── MobData.gd
│   ├── MobInstance.gd
│   ├── MobSpawner.gd
│   ├── OverworldMobManager.gd
│   └── OverworldMobPool.gd
│
├── mount/                     # Mount system
│   └── MountFollower.gd
│
├── network/                   # Multiplayer
│   ├── ChatManager.gd
│   ├── ChatUI.gd
│   ├── LobbyManager.gd
│   ├── NetworkManager.gd
│   ├── NetworkSync.gd
│   ├── PlayerPartyManager.gd
│   ├── RemotePlayer.gd
│   ├── TradeManager.gd
│   └── TradeUI.gd
│
├── overworld/                 # Overworld managers
│   ├── OverworldHUDManager.gd
│   ├── OverworldInteractionManager.gd
│   ├── OverworldMapManager.gd
│   ├── OverworldNetworkManager.gd
│   ├── OverworldNPCManager.gd
│   ├── OverworldPlayerManager.gd
│   └── OverworldRiftManager.gd
│
├── procedural/                # Procedural entity generation (3D)
│   ├── EntityAnimator.gd
│   ├── EntityVisualComponent.gd
│   ├── MaterialLibrary.gd
│   ├── Phase1Previewer.gd
│   ├── PrimitiveMeshLibrary.gd
│   └── ProceduralEntityGenerator.gd
│
├── ui/                        # UI screens (see UI Theming System above)
│   ├── UIHelper.gd            # ★ Central UI factory
│   ├── BaseShopUI.gd
│   ├── CharacterMenu.gd
│   ├── ContextMenu.gd
│   ├── CookingTableUI.gd
│   ├── CraftingScreen.gd
│   ├── EquipmentDoll.gd
│   ├── EquipmentScreen.gd
│   ├── HexCell.gd
│   ├── Hotbar.gd
│   ├── HUD.gd
│   ├── InventoryGrid.gd
│   ├── InventoryScreen.gd
│   ├── JobsScreen.gd
│   ├── KeybindsScreen.gd
│   ├── LootPopup.gd
│   ├── Minimap.gd
│   ├── MissionBoardInterface.gd
│   ├── MountScreen.gd
│   ├── OptionsMenu.gd
│   ├── PartyScreen.gd
│   ├── RiftEntryUI.gd
│   ├── ShopInterface.gd
│   ├── StatsScreen.gd
│   ├── TameResultPopup.gd
│   └── components/
│       ├── DragHandler.gd     # Drag-and-drop system
│       ├── ItemIcon.gd        # Item icon rendering
│       ├── ItemSlot.gd        # Single inventory slot
│       └── ItemTooltip.gd     # Hover tooltip
│
├── [Root scripts/]            # Core systems (all autoloads listed above)
│   ├── ModLoader.gd           # Autoload #1
│   ├── ModAPI.gd              # Autoload #2
│   ├── ThemeManager.gd        # Autoload #3
│   ├── EventBus.gd            # Autoload #4
│   ├── DataRegistry.gd        # Autoload #5
│   ├── SaveManager.gd         # Autoload #6
│   ├── GameState.gd           # Autoload #7
│   ├── ButtonStyleHelper.gd   # ★ Backward-compat wrapper for MT
│   ├── Constants.gd           # ★ Shared constants
│   ├── Base.gd                # Home base interior UI
│   ├── BaseManager.gd         # Base management autoload
│   ├── BaseNode.gd            # World-map base node
│   ├── ... (remaining ~30 autoload scripts)
│   └── SpriteLoader.gd        # Sprite loading utility
```

---

## Game Flow

1. **New Game** (MainMenu)
2. **World generation**: Full geodesic hexasphere (icosahedron frequency-F; 12 pentagons + hexes), biomes via lat/lon + noise + target-share rebalance
3. **Start tile selection**: Player chooses starting tile on the 3D globe / 2D equirect unwrap
4. **Character creation**: Race/class/appearance from data
5. **Local overworld**: 512x512 playfield for the chosen sphere hex. WASD exploration; walk off map edge to enter adjacent hex
6. **World Map** (M key): Strategic sphere view — factions, quests, rift activity, fog-of-war
7. **Rifts**: Spawn at local coordinates (5-30 min windows or quest-triggered). Enter → instanced procedural dungeon → close at core → return
8. **Some rifts** have bosses; others are standard loot runs

---

## Two-Layer World Model

- **Planet layer** (`WorldGenerator` + `WorldGeneration` 3D preview + `WorldMapScreen`): full-sphere hexasphere, biome/climate metadata, travel, factions, quests
- **Local layer** (`LocalMapGenerator` + `HubWorld`): one 512x512 procedural map per hex (`hex_states` in GameState), edge-connected to neighbors
- **Clutter placement (v0.12.1)**: paint `TERRAIN_VEGETATION` from forest noise; place harvestables via `forest_patch` / `vein` / `field` / `pocket` / `scatter` modes in `data/resource_nodes.json`; gate yields with `min_biome_tier` vs biome `difficulty_tier`. Decor uses meadow/understory/ruin masks. Bump `TERRAIN_VERSION` when placement changes so cached hex maps regenerate.

**Loop**: Local exploration → Enter rift → Dungeon → Close rift → Return to local map → World Map for strategic travel

---

## Planet Hexasphere (2026-07-20)

True full-globe coverage. Not an axial disk projected onto a sphere.

| Concern | Implementation |
|---------|----------------|
| Topology | Geodesic icosahedron, frequency `F`. Tile count = `10*F²+2` (12 vertices degree-5 / pentagons, rest hexes) |
| Size UI | Small `R=8→F=5` (252), Medium `R=12→F=7` (492), Large `R=18→F=10` (1002) via `size_to_hex_frequency` |
| Tile keys | Still `"q,r"` strings for GameState compatibility. On sphere: `key = "%d,0" % id` (`q=id`, `r=0`) |
| Adjacency | Graph on each tile: `neighbor_keys: Array[String]` (5 or 6). Use `get_neighbors(q,r)` — do **not** assume axial `±1` offsets |
| Distance | `hex_distance` uses angular step on unit sphere when `_sphere_unit` cache is filled |
| Positions | Tile field `unit_pos: [x,y,z]` (JSON-safe array). Coerce with `WorldGenerator.unit_pos_vec(tile)` / `_coerce_vec3` |
| Packing | `HEX_PACK_RATIO=0.97`; `hex_size = (min_nn * ratio) / √3`. Shared prism mesh; tangent from first graph neighbor |
| Climate | Lat/lon from unit position + FastNoise elev/rain; `BIOME_CLIMATE_PROFILES` + `BIOME_TARGET_WEIGHTS`; soft `BIOME_MAX_SHARE=0.18` / `MIN=0.04` + `_rebalance_biome_shares` |
| Caches | Static `_sphere_unit`, `_sphere_neighbors`, `_sphere_tile_count` filled by `generate` / `build_hexasphere` / `load_from_tile_map` |
| 3D preview | `WorldGeneration._render_3d_globe` → `build_hex_sphere_layout` |
| 2D map | `WorldMapScreen` plots lon/lat from `unit_pos` (equirect unwrap) |
| Diag | `tools/diag_hex_sphere_pack.gd` (headless), `tools/check_hex_spacing.py` — gates count, nn_ratio≤1.40, pack∈[0.90,0.99], 8 octants, biome shares |

**Gotchas**
- Never `positions.get(key, expensive_default())` — GDScript evaluates defaults eagerly; use `has` then branch.
- Never store raw `unit_pos` arrays into `_sphere_unit` without `_coerce_vec3` / `unit_pos_vec`.
- Pure axial neighbor math is wrong on the sphere; always use `neighbor_keys`.
- Euler: a closed sphere cannot be all hexes — the 12 pentagons are required.

---

## Anti-Duplication: What NOT to Create

The following functionality already exists. **Do not create duplicates:**

| If you need... | Use this existing module |
|----------------|-------------------------|
| UI color constants | `MasterTheme` static vars (BG_DEEP, TEXT_PRIMARY, etc.) |
| Font size/spacing constants | `MasterTheme` (FS_H1, SPACE_LG, RADIUS_MD, etc.) |
| A themed button | `UIHelper.make_button("text", "primary")` |
| A themed label | `UIHelper.make_label("text", MT.FS_BODY, MT.TEXT_PRIMARY)` |
| A panel/container | `UIHelper.make_panel(...)` or `make_vbox(...)` |
| A modal screen | `UIHelper.build_modal_screen(...)` |
| A progress bar (HP/MP/XP) | `UIHelper.make_progress_bar(...)` |
| A StyleBoxFlat for buttons | `MT.button_stylebox("primary", "hover")` — DO NOT inline StyleBoxFlat |
| A full Godot Theme | `MT.apply_to(window)` or `MT.apply_theme_to_control(control)` |
| Button color/styling | `MT.apply_button_style(btn, "primary")` — DO NOT use ButtonStyleHelper (deprecated) |
| Theme switching | `ThemeManager.apply_theme("frost")` — Autoload, already wired |
| Register a mod theme | `ModAPI.register_theme(mod_id, name, display, data)` |
| Game data (items, mobs, etc.) | `DataRegistry.get_data("items")` — DO NOT load JSON files directly |
| Event broadcasting | `EventBus.emit("event_name", data)` |
| Character state (HP, XP, etc.) | `GameState` autoload |
| Save/load | `SaveManager` autoload |
| Scene transitions | `GameManager` autoload |
| World/hex constants | `Constants.CELL_SIZE`, `Constants.MAP_SIZE` |

**For new UI screens:**
```gdscript
const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
# Build UI using UH.make_*() and MT.* constants ONLY
# DO NOT: new() raw Control nodes, inline StyleBoxFlat, hardcode colors
```

---

## Multi-Agent Workflow

- **Remedy (Hermes primary)**: Meta-orchestrator. Loads context, decomposes work, routes tasks
- **Sub-agents**: Hermes native delegation for focused sub-work
- **Claude Code / Local**: Automatic dispatch for deep reasoning or large refactors
- **Shared Layer**:
  - `docs/` — goals, architecture, protocol, tasks
  - `memory/` — handoffs (SESSION_NOTES/), state, dispatches
  - `skills/` — reusable procedures

## Implementation Notes
- Data JSONs are the "soul" of content
- Managers are stubs or partial — focus on data loading first
- See `docs/PROJECT_OVERVIEW.md` for goals and success criteria
- See `docs/UI_DESIGN_SYSTEM.md` for full design token reference
- See `docs/VERSION.md` for phase map and save format versioning
