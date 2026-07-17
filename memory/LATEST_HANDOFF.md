---
name: ui-design-system
description: Full UI design system implementation — tokens, theme, backgrounds, component library, wiring across all screens.
---
# UI Design System

## User request
Build a comprehensive UI Design System for the Fallen Earth Godot 4 project. The goal was consistency, maintainability, and visual polish across all UI screens.

## What shipped

### Design System Foundation (5 new files)
- `assets/ui/UI_Colors.gd` — 50+ design tokens: palette (BG_DEEP, BG_PANEL, BG_HUD, ACCENT_PRIMARY, etc.), spacing (XS/S/M/L/XL), font sizes (FS_CAPTION through FS_HERO), bar dimensions (BAR_HEIGHT_SM/MD/LG), cell sizes (CELL_SM/MD/LG)
- `assets/ui/UI_Theme.gd` — Programmatic Godot Theme builder. Applied globally via `UI_Theme.apply_to(get_tree().root)` in `GameManager._ready()`. Covers Panel, Button, LineEdit, ItemList, ProgressBar, RichTextLabel, Label, ScrollBar, TabContainer
- `scripts/StyleBoxHelper.gd` — 10 static factory methods for StyleBoxFlat (panel_flat, panel_rounded, button_normal, button_hover, button_pressed, button_focus, tooltip, hud_bar, inventory_cell, side_panel)
- `scripts/UIBackgrounds.gd` — Texture overlay system with `apply_modal_bg`, `apply_hud_bar`, `apply_side_panel`, `apply_panel_bg`, `apply_tooltip_bg` functions
- `scripts/ButtonStyleHelper.gd` — Rewritten: 5 states (normal/hover/pressed/focus/disabled), 5 variants (primary/secondary/danger/success/ghost), design system palette

### UI Background Textures (6 files via PixelLab MCP)
- `assets/ui/bg_modal.png` — Dark with subtle tech pattern
- `assets/ui/bg_panel.png` — Slightly lighter panel background
- `assets/ui/bg_tooltip.png` — Small tooltip texture
- `assets/ui/bg_hud_bar.png` — Horizontal bar texture for HUD
- `assets/ui/bg_inventory_cell.png` — Inventory cell background
- `assets/ui/bg_side_panel.png` — Side panel texture

### Screens Wired (20+)
All major screens updated with design system backgrounds, styled buttons, and consistent typography:
- MainMenu, WorldGeneration, CharacterSelection, PauseMenu, Options, OptionsMenu
- CharacterMenu, DialogueUI, ShopInterface, MissionBoardInterface, RiftEntryUI
- LootWindow, BaseShopUI, InventoryScreen, Settlement, SettlementInterior
- Base, WorldMapScreen, CookingTableUI, BattleResultsUI, HUD, Hotbar
- QuestTrackerUI, EquipmentScreen, CraftingScreen, StatsScreen

### Cleanup
- All inline StyleBoxFlat removed from MainMenu.tscn, PauseMenu.tscn, WorldGeneration.tscn
- 25+ sites migrated from `anchor_right=1.0` to `set_anchors_preset()`
- 6 scripts fixed: FOCUS_NONE → FOCUS_ALL (visible focus rings)

### UI Layout Fixes (this session)
- ShopInterface: absolute positions → VBoxContainer/HBoxContainer responsive layout
- MissionBoardInterface: absolute positions → container layout
- BaseShopUI: absolute positions → container layout
- InventoryScreen: center-anchored panel → full-rect (fixes overlap with CharacterMenu header)
- EquipmentScreen: slots 110x96→90x80, left panel 360→300
- InventoryScreen: panel 900x620→800x560, side panels 160→140
- WorldMapScreen: HEX_SIZE 22→30, hex buttons 40x36→50x44
- HUD: top bar 56→48, bars 260x18→220x16, level/EC labels moved into top bar
- LootWindow: CELL_SIZE 40→48 (matches InventoryScreen)
- StatsScreen: hardcoded fonts → design tokens, left panel 240→200

### UI Graphical Fixes (this session)
- CharacterSelection: removed invalid `[/br]` BBCode closing tag
- UI_Theme: PanelContainer default `SB.panel(BG_DEEP)` → transparent (was causing dark squares)
- UIBackgrounds: `apply_modal_bg` texture overlay 0.6→0.15 alpha, ColorRect alpha cap 0.35→0.55
- WorldMapScreen: removed `apply_modal_bg` (was reducing bg alpha, letting HubWorld tiles bleed through)
- HUD bar group: background alpha 0.75→0.45, corner radius 6→4

### Bug Fixes (this session)
- CharacterMenu: use-after-free in `select_tab()` — added `is_instance_valid()` checks
- HoverTooltip: `add_theme_constant_override` → `add_theme_font_size_override` (font_size bug)
- HUD: `bar.show_percentage = false` → `true`
- InventoryManager: item icon loading via `load("res://assets/sprites/items/<item_id>.png")`
- ResourceVisualManager: SPRITE_FOLDER → `assets/sprites/resource_nodes/`, PICKUP_FOLDER → `assets/sprites/items/`
- CharacterVisual: sprite loading fallback for `_spritesheet.png` / `_sheet.png`; renamed `human_female_sheet.png` → `human_female_spritesheet.png`
- CharacterVisual: `slot_offsets` dictionary in `update_equipment()`, added offhand to `layer_order`

### Character Sprites (this session)
- Human male complete: 128px base, 64px animation ref, 8 idle rotations, 4-frame walk × 8 dirs = 42 PNGs
- Tool sprites: 6 of 8 generated (crowbar, pickaxe, mining_drill, laser_cutter, wrench, knife)

## Files created
```
assets/ui/
├── UI_Colors.gd
├── UI_Theme.gd
├── bg_modal.png
├── bg_panel.png
├── bg_tooltip.png
├── bg_hud_bar.png
├── bg_inventory_cell.png
└── bg_side_panel.png

scripts/
├── StyleBoxHelper.gd
├── UIBackgrounds.gd
└── ButtonStyleHelper.gd (rewritten)

assets/characters/human_male_test/
├── human_male_test_base_128.png
├── human_male_test_base_64.png
├── human_male_test_{S,SE,E,NE,N,NW,W,SW}.png (8 rotations)
└── human_male_test_walk_{dir}_{0..3}.png (32 walk frames)

assets/sprites/tools/
├── crowbar.png, pickaxe.png, mining_drill.png
├── laser_cutter.png, wrench.png, knife.png
```

## Verification
- All existing smoke tests pass (no regression)
- `validate_scripts.gd` — All scripts and scenes OK

## Lessons learned
- PanelContainer default theme should be transparent — programmatic themes should not add unexpected backgrounds
- `apply_modal_bg` alpha should be subtle (0.15) — too high (0.6) causes texture to overpower background content
- Container-based layouts are more maintainable than absolute positioning in .tscn files
- `set_anchors_preset()` is safer than manual anchor_right/anchor_bottom values
- `.gdignore` files prevent Godot editor filesystem watcher from interfering with file generation

## What's next
1. Remaining 23 character sprites (human_female + 22 race×gender combos)
2. Remaining 2 tool sprites (chainsaw, welder)
3. Idle + attack animation frames for characters
4. v0.11.1 combat UI panels (TurnOrderBar, UnitInfoCard, SkillBar)
