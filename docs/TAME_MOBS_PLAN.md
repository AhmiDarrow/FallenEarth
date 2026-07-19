# Tamable Mobs System — Final Adjusted Plan

> Research-validated corrections applied. See footnotes for rationale.

---

## Architecture Principles

- **Autoload singletons** with `extends Node`, signals, `get_snapshot()` / `restore_from_snapshot()`
- **Cross-manager refs** via `const PATH := "/root/ManagerName"` + `get_node_or_null()`
- **Data loading** via `ResourceLoader.exists()` + `load()` with `raw.data if "data" in raw else raw` unwrap
- **UI screens** as `class_name XScreen extends Control`, built programmatically in `_build_ui()`
- **Save/load** via `SaveManager.aggregate_snapshot()` and `restore_all()` routing

---

## Combat UI Layout (Revised v2)

Two separate framed boxes bottom-left and bottom-right, plus existing top-center + top-right:

```
┌──────────────────────────────────────────────────────────┐
│                                         ┌──────────────┐ │
│           [ Top Prompt ]                │ Enemy Info   │ │
│                                         │ Name  HP bar │ │
│                                         └──────────────┘ │
│                                                           │
│                                                           │
│ ┌──────────────────┐                   ┌────────────────┐ │
│ │ [Move]           │                   │ Player Name    │ │
│ │ [Attack]         │                   │ HP ██████░░ 80│ │
│ │ [Tame]           │                   │ MP ██████░░ 60│ │
│ │ [End Turn]       │                   │ Lv. 12  Class │ │
│ │ [Retreat]        │                   └────────────────┘ │
│ └──────────────────┘                                       │
└──────────────────────────────────────────────────────────┘
```

### New/Modified Combat UI Files

| File | Action | Purpose |
|------|--------|---------|
| `scripts/combat/ui/CombatActionPanel.gd` | **New** | Framed `PanelContainer` bottom-left, vertical action buttons. Same `Callable` pattern as removed ActionBarV110. |
| `scripts/combat/ui/PlayerStatsPanel.gd` | **New** | Framed `PanelContainer` bottom-right. Shows player name/HP/MP/level. Mirrors `EnemyInfoPanel` pattern. |
| `CombatLevel3D.tscn` | **Modify** | Replace `ActionBar` node with `CombatActionPanel`. Add `PlayerStatsPanel` to HUDLayer. |
| `CombatLevel3D.gd` | **Modify** | Rewire action bar calls → `_action_panel.*`. Add `_player_stats.set_stats()` call. |
| `scripts/combat/ui/ActionBarV110.gd` | **Remove** | Replaced by `CombatActionPanel`. |

### CombatActionPanel.gd Specs

```
CombatActionPanel (Control, anchors bottom-left)
└── PanelContainer (MT.panel() frame)
    └── VBoxContainer (separation 6)
        ├── Button "Move"    — on_move Callable
        ├── Button "Attack"  — on_attack Callable
        ├── Button "Tame"    — on_tame Callable (hidden by default)
        ├── Button "End Turn" — on_end_turn Callable
        └── Button "Retreat" — on_retreat Callable
```

- **Position**: `offset_left=vp.x*0.03, offset_top=vp.y*0.62, size=160×220`
- **Buttons**: 120×36px each, MT styling, same color accents as current
- **Callables**: `on_move`, `on_attack`, `on_tame`, `on_end_turn`, `on_retreat`
- **Visibility**: `show_actions(enabled: bool)` (all), `set_tame_visible(enabled: bool)` (tame only)

### PlayerStatsPanel.gd Specs

```
PlayerStatsPanel (Control, anchors bottom-right)
└── PanelContainer (MT.panel() frame)
    └── VBoxContainer
        ├── Label "Player Name" (font_size=14, bold)
        ├── HBoxContainer
        │   ├── Label "HP"
        │   ├── ColorRect (HP bar, 100×10)
        │   └── Label "cur/max"
        ├── HBoxContainer
        │   ├── Label "MP"
        │   ├── ColorRect (MP bar, 100×10)
        │   └── Label "cur/max"
        └── Label "Lv. 12  Class"
```

- **Position**: `offset_right=vp.x-20, offset_top=vp.y*0.78, size=180×110`
- **Method**: `set_stats(name: String, level: int, hp_cur: int, hp_max: int, mp_cur: int, mp_max: int, class_name: String)`
- **Same pattern** as EnemyInfoPanel.gd (dynamic ColorRect bars, MT colors)

---

## Phase 1: Data Layer

### 1A — `data/tame_config.json` (New)

```json
{
  "data": {
    "base_cooldown_turns": 3,
    "failure_attack_damage_mult": 0.8,
    "max_tamed_base": 1,
    "max_tamed_per_level_tier": [
      {"min_level": 1, "max_tamed": 1},
      {"min_level": 10, "max_tamed": 2},
      {"min_level": 25, "max_tamed": 3},
      {"min_level": 50, "max_tamed": 4},
      {"min_level": 100, "max_tamed": 5},
      {"min_level": 200, "max_tamed": 6}
    ],
    "tame_chance_floor": 0.01,
    "tame_chance_ceiling": 0.95,
    "level_diff_multiplier": 0.02,
    "level_diff_base": 0.1,
    "health_weight": 1.0
  }
}
```

### 1B — Add 20 quadruped mobs to `data/mobs.json`

Each entry adds:
```json
{
  "is_tamable": true,
  "tamable_type": "mount",
  "tame_difficulty": 0.5,
  "mount_bonus": {"movement_speed_mult": 1.25},
  "sprite_id": "PLACEHOLDER"  
}
```
> **Note**: `sprite_id` stores the PixelLab `character_id` UUID after generation, not a human-readable name.

| Biome | Neutral (mount) | Aggressive (mount) | Quadruped Template |
|-------|-----------------|-------------------|-------------------|
| Scorched Plains | Ember Strider (spd 1.25) | Flameback Charger (spd 1.3) | horse / lion |
| Ash Wastes | Cinder Hound (spd 1.2) | Dust Lurker (spd 1.25) | dog / cat |
| Neon Bogs | Glowfin Stalker (spd 1.2) | Bogmire Crawler (spd 1.15) | cat / bear |
| Ironwood Thicket | Ironjaw Stag (spd 1.3) | Brambleback Beast (spd 1.2) | horse / bear |
| Rust Canyons | Rustfang Wolf (spd 1.25) | Canyon Grinder (spd 1.15) | dog / dog |
| Glass Dunes | Sandglass Rattler (spd 1.3) | Dune Prowler (spd 1.35) | lion / cat |
| Corpse Fields | Bonegrinder (spd 1.15) | Carrion Stalker (spd 1.2) | bear / dog |
| Toxin Marshes | Toxic Salamander (spd 1.15) | Miasma Toad (spd 1.1) | cat / bear |
| Stormspire Highlands | Stormmane Elk (spd 1.35) | Thunderclaw Raptor (spd 1.4) | horse / lion |
| Dead City Outskirts | City Crawler (spd 1.2) | Ruin Hound (spd 1.25) | dog / cat |

### 1C — Add `is_tamable` to humanoid archetypes

Add to `data/enemy_archetypes.json` for: `raider`, `smuggler`, `cultist`, `tech_cultist`, `mercenary`

```json
{
  "is_tamable": true,
  "tamable_type": "companion",
  "tame_difficulty": 0.4
}
```

---

## Phase 2: TameCalculator (Pure Logic)

**File**: `scripts/TameCalculator.gd`

### Interface
```gdscript
static func calculate_chance(
    player_level: int,
    mob_level: int,
    mob_current_hp: int,
    mob_max_hp: int,
    tame_difficulty: float
) -> float

static func get_max_tamed(player_level: int) -> int
static func get_cooldown_turns() -> int
```

### Formula
```
base = 0.1 + (player_level - mob_level) * 0.02    (clamped 0.01–0.50)
health_mod = 1.0 - (current_hp / max_hp)
chance = base * (1.0 + health_mod) * tame_difficulty  (clamped 0.01–0.95)
```

---

## Phase 3: TamedMobManager (Autoload)

**File**: `scripts/TamedMobManager.gd`

### Signals
```gdscript
signal tamed_mob_added(mob: Dictionary)
signal tamed_mob_removed(mob_id: String)
signal mount_changed(mount_id: String)
```

### Key Methods
```gdscript
func register_tame(mob_template_id, mob_name, tamable_type, mount_bonus, tame_difficulty, player_level) -> Dictionary
func release_tamed(mob_id: String) -> void
func set_custom_name(mob_id: String, new_name: String) -> void
func get_all_tamed() -> Array[Dictionary]
func get_mounts() -> Array[Dictionary]
func get_companions() -> Array[Dictionary]
func set_active_mount(mob_id: String) -> bool
func get_active_mount() -> Dictionary
func get_mount_speed_mult() -> float
func advance_turn() -> void  # decrements cooldown
func can_tame() -> bool
func get_snapshot() -> Dictionary
func restore_from_snapshot(snap: Dictionary) -> void
```

### Registration in `project.godot`
```ini
TamedMobManager="*res://scripts/TamedMobManager.gd"
```

### Registration in `SaveManager.gd`
```gdscript
# aggregate_snapshot()
["tamed_mobs", "/root/TamedMobManager"],
# restore_all()
["tamed_mobs", "/root/TamedMobManager", null],
# apply_managers_from_payload() — add "tamed_mobs" to extraction key list
```

> **Correction**: Do NOT call `_load_tamed_data()` from `_ready()`. Tamed mobs are player save state, not static data. Initialize `_tamed_mobs = []` and `_active_mount_id = ""` — all state comes from `save/load` only.¹

---

## Phase 4: Tame Combat Integration

### Tame Button in CombatActionPanel

- 5th button "Tame" between Attack and End Turn
- Visibile only when encounter has tamable units
- Same `on_tame: Callable` pattern as other action buttons

### Tame Flow (in `CombatLevel3D.gd`)

1. Player clicks **Tame** → enters `STAGE_SELECT_TAME_TARGET`²
2. Highlight tamable enemies (blue outline)
3. Player clicks a highlighted enemy → `TameCalculator.calculate_chance()`
4. Show `TameResultPopup` with percentage + Confirm/Cancel
5. **Success** → `TamedMobManager.register_tame()` → end encounter
6. **Failure** → mob counterattacks at 80% damage → end turn
7. **Cooldown**: `TamedMobManager.advance_turn()` called each turn start

### TameResultPopup

**File**: `scripts/ui/TameResultPopup.gd`

Simple popup (not a PixelLab panel — just a styled Control):
- Title: "Tame Attempt"
- Body: "You attempt to tame [mob name]..."
- Outcome: Success → naming field + "Tamed!" / Failure → "The mob resists!"
- Buttons: "Confirm Name" (on success), "Close" (on failure)

---

## Phase 5: Mount Screen

**File**: `scripts/ui/MountScreen.gd`

### Interface
- Lists all tamed mounts with: custom name, species, speed bonus, active indicator
- Buttons: **Set Active**, **Release**, **Rename**
- Same framed panel pattern as other character tabs

### Registration in `CharacterMenu.gd`

```gdscript
const TABS := [
    ...
    {"id": "mounts", "label": "Mounts", "key": KEY_H},  # NEW
]

const SCREEN_PATHS := {
    ...
    "mounts": "res://scripts/ui/MountScreen.gd",
}
```

> **Correction**: Use `KEY_H` (not `KEY_M` — conflicts with `world_map`).³ Optionally add `"mounts": KEY_H` to `KeybindManager` if a rebindable action is desired.

---

## Phase 6: Overworld Integration

### Mount Speed — `HubWorld.gd`

```gdscript
var tmm: Node = get_node_or_null("/root/TamedMobManager")
var speed_mult: float = 1.0
if tmm != null and tmm.has_method("get_mount_speed_mult"):
    speed_mult = tmm.get_mount_speed_mult()
# Apply to hex movement cost/distance
```

### Mount Visual — `CharacterVisual.gd`

- Add `_mount_sprite: Sprite2D` layer below the character sprite
- Load texture from `assets/mobs/{character_id}.png` when `TamedMobManager.get_active_mount()` returns non-empty
- Hide mount sprite when no mount active

---

## PixelLab Asset Generation

### Scope (adjusted² → 52 jobs)

| Category | Count | PixelLab Tool | Jobs |
|----------|-------|--------------|------|
| Quadruped mob sprites (8-dir) | 20 | `create_character(quadruped, template=, size=48)` | 20 |
| Walk animations | 20 | `animate_character(mode=template, walk)` | 20 |
| Idle animations | 20 | `animate_character(mode=template, breathing-idle)` | 20 |
| **Total** | **60** | | **60** |

> **UI panels removed from PixelLab scope**: Both the mount screen and tame popup use `MT.panel()` styling — no custom PixelLab assets needed.⁴

### Batch Schedule (6 batches × 10 jobs)

| Batch | Content | Est. |
|-------|---------|------|
| **1** | 6 mobs (Scorched Plains, Ash Wastes, Neon Bogs) | ~3min |
| **2** | 4 mobs (Ironwood Thicket, Rust Canyons) + 6 walk anims | ~3min |
| **3** | 6 mobs (Glass Dunes, Corpse Fields, Toxin Marshes) + 4 walk anims | ~3min |
| **4** | 4 mobs (Stormspire, Dead City) + 6 walk anims | ~3min |
| **5** | 10 idle anims | ~3min |
| **6** | 10 idle anims + retries | ~3min |
| **Total** | | **~18 min** |

### Post-Generation Integration

1. `get_character(id)` → rotation URLs → download PNG to `assets/mobs/{character_id}.png`
2. Update `data/mobs.json` entries: set `"sprite_id"` to the PixelLab UUID
3. Walk/idle animations stored alongside character (accessed via `get_character(id)`)

---

## Orphaned Asset Cleanup

| File | Status |
|------|--------|
| `assets/battle_ui/top_prompt_panel.png` | Unused — `TopPromptV110` uses `MT.panel()` instead⁵ → **Delete** |

---

## Full Implementation Order

| Step | Task | Est. | Dependencies |
|------|------|------|-------------|
| 1 | Create `data/tame_config.json` | Low | None |
| 2 | Add 20 quadruped mobs + `is_tamable` to `data/mobs.json` + archetypes | Med | Step 1 |
| 3 | Create `scripts/TameCalculator.gd` | Low | Step 1 |
| 4 | Create `scripts/TamedMobManager.gd` | Med | Step 3 |
| 5 | Register in `project.godot` + `SaveManager.gd` | Low | Step 4 |
| 6 | Create `scripts/combat/ui/CombatActionPanel.gd` | Med | None |
| 7 | Create `scripts/combat/ui/PlayerStatsPanel.gd` | Med | None |
| 8 | Update `CombatLevel3D.tscn` + `CombatLevel3D.gd` layout + wiring | Med | Steps 6-7 |
| 9 | Remove old `ActionBarV110.gd` + delete orphaned `top_prompt_panel.png` | Low | Step 8 |
| 10 | Create `scripts/ui/MountScreen.gd` + register in `CharacterMenu.gd` | Med | Step 4 |
| 11 | Apply mount speed in `HubWorld.gd` | Low | Step 4 |
| 12 | Add mount sprite layer in `CharacterVisual.gd` | Med | PixelLab done |
| 13 | Create `scripts/ui/TameResultPopup.gd` | Med | None |
| 14 | Wire tame logic (Tame button → popup → success/failure) in `CombatLevel3D.gd` | High | Steps 3-4, 6, 13 |
| 15 | **PixelLab batches 1-6** (asset generation) | ~18min | Step 2 |
| 16 | Download sprites → `assets/mobs/{uuid}.png` + update `sprite_id` in mobs.json | Med | Step 15 |

---

## Footnotes

¹ **Tamed mobs are save state**: Originally the plan had `_load_tamed_data()` reading from a static JSON path. That's wrong — tamed mobs are player-specific state created during gameplay. All data must flow through `SaveManager.restore_from_snapshot()`.

² **No new stage constant**: `STAGE_SELECT_TAME_TARGET` is handled as a sub-state of `STAGE_SELECT_ACTION` (same as Move/Attack targeting), not a separate participant stage.

³ **KEY_M conflict**: `KeybindManager` binds `world_map` to `KEY_M`. Using `KEY_H` for mounts avoids the conflict. Optionally register a `mounts` action in KeybindManager.

⁴ **UI panels don't need PixelLab**: The mount screen and tame popup are styled controls using `MasterTheme.panel()`, `MT.button_stylebox()`, and standard Godot nodes. No custom texture assets needed.

⁵ **top_prompt_panel.png orphan**: The file exists at `assets/battle_ui/top_prompt_panel.png` but `TopPromptV110.gd` uses `MT.panel()` with solid colors, never loading this texture.
