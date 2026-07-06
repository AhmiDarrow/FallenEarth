---
name: v101-combat-polish
description: v0.10.1 Combat UI Polish — FFT-style selection arrow, top prompt, decor props, name plates, action bar.
---
# v0.10.1 Combat UI Polish

## User request
"We need to keep polishing and fixing battle" — with a Final Fantasy
Tactics reference showing the desired look (blue down-arrow above the
active unit, "Select a white tile to move" prompt, biome-themed decor
props, white-bg name labels, FFT-style action bar).

## What shipped

### New components
- `scripts/combat/UnitSelectionArrow.gd` — bright cyan-blue down-arrow
  with 3-layer (outer/mid/inner) Polygon2D triangles. Bobs up-and-down
  + inner alpha pulses for a glow effect.
- `scripts/combat/TopPrompt.gd` — top-center styled banner with
  optional sub line and auto-fade. Uses the new
  `assets/battle_ui/top_prompt_panel.png` as the backdrop (falls back
  to styled rect).
- `scripts/combat/UnitNamePlate.gd` — white-bg, dark-border name
  label above each unit. Team-tinted text (player=green, enemy=red,
  ally=blue, boss=gold). Bosses get a slightly cream bg.

### BattleBackground overhaul
- Replaced the old debris/vegetation tile scatter with biome-themed
  decor props from `assets/battle_decor/{kind}/`.
- 7 decor types generated via PixelLab: boulders, animal skulls,
  cacti, rubble, thorns, stumps, gnarled roots. Each with 3-4
  variants.
- Per-biome decor selection: Ash Wastes uses boulder/rubble/stump/
  skull/roots; Neon Bogs uses roots/thorns/cactus/stump/rubble; etc.
- New `BIOME_DECOR` map in `BattleBackground.gd`.
- Props have random rotation + scale variance, so they read as
  scattered scenery not as a grid of identical sprites.

### BattleCell polish
- HIGHLIGHT_MOVE is now a soft white tint (was a blue full-cell).
- HIGHLIGHT_ATTACK / HIGHLIGHT_SKILL use border-only frames
  (4 ColorRect edges) so the ground texture still shows inside the
  cell. This matches the FFT reference: red borders = attack range,
  purple borders = skill range.
- New `_highlight_border: Control` + `_build_border()` /
  `_set_border_color()` helpers.

### BattleUnit polish
- Each unit now owns a `UnitNamePlate` and a `UnitSelectionArrow`.
- Arrow visibility follows `set_active(true/false)`.
- New `display_name` field so the engine can override the
  auto-generated name (e.g. "TestHero").

### BattleGridView helpers
- `get_unit(id)`, `get_all_units()`, `cell_to_world(x, y)` for
  consumers (TacticalCombat, TargetingReticle).

### TacticalCombat wiring
- New `TopPrompt` is created on `_ready` and updated by
  `_update_instructions()` whenever the subphase changes:
  - MOVE → "Select a white tile to move" / "Then choose an action"
  - ACTION → "Choose an action" / "Skill / Attack / Wait / Finish"
  - TARGET_ATTACK → "Select a target" / "Red tiles = attack range"
  - TARGET_SKILL → "Select a skill target" / "Purple tiles = skill range"
  - enemy turn → "Enemy acting…"
  - end of battle → hide.
- New `_build_bottom_action_bar()` builds a dedicated bottom-center
  HBox with the styled End Turn + Retreat buttons. The legacy
  ActionsHBox is hidden so the player has a clean bottom row.
- New `_style_action_button()` / `_style_finish_button()` apply
  chunky FFT-style metal styleboxes (red/blue/grey for actions,
  gold border for End Turn).
- Legacy MainVBox labels (status, turn_order, instructions, log)
  hidden — replaced by the new HUD components.

### New assets (PixelLab MCP)
- `assets/battle_ui/selection_arrow.png` (192×192) — cyan arrow
- `assets/battle_ui/top_prompt_panel.png` (512×192) — gold-trim banner
- `assets/battle_ui/name_plate_panel.png` (256×192) — blue-trim plate
- `assets/battle_ui/button_red.png` / `button_blue.png` /
  `button_grey.png` / `button_gold.png` (256×192 each)
- `assets/battle_decor/boulder/` ×4 variants
- `assets/battle_decor/skull/` ×3 variants
- `assets/battle_decor/cactus/` ×4 variants
- `assets/battle_decor/rubble/` ×4 variants
- `assets/battle_decor/thorns/` ×4 variants
- `assets/battle_decor/stump/` ×3 variants
- `assets/battle_decor/roots/` ×3 variants
- `tools/generate_battle_decor_imports.py` — generates
  `.import` files for headless workflows (Godot rewrites them on
  next editor import).

Total: 25 PNGs + 25 .import files = 50 new asset files.

## Verification

| File | Checks | Status |
|------|--------|--------|
| `validate_scripts.gd` | All | All OK |
| `tools/smoke_combat_v100.gd` | 27 (visual) | All pass |
| `tools/smoke_combat_ui.gd` | 15 (UI) | All pass |
| `tools/smoke_combat_polish.gd` | NEW — 7 groups | All pass |
| `tools/boot_combat.gd` | NEW — full scene boot | All pass |
| `tools/boot_probe.gd` | 60 frames | 0 errors |

## Architecture constraints held
- New components are pure data-driven (no new tile pipeline,
  no new sprite system). Decor uses the same PixelLab pipeline
  as the existing battle_ui/ assets.
- BattleBackground reuses the existing `TileSetService.biome_to_dir()`
  for the bg tile.
- New scripts are added to `validate_scripts.gd` SCRIPTS list
  (TopPrompt, UnitNamePlate, UnitSelectionArrow) so they get
  compile-checked alongside the rest of the codebase.

## What's next (P1 for future)
- Per-decor-test: a 6×6 visual grid test in `tools/smoke_combat_polish.gd`
  that takes a screenshot for visual QA.
- Consider adding a "Move preview" tooltip (FFT shows the range cost
  on each tile when the unit is selected to move).
- Bouncing battle damage popup: when the FloatingDamage numbers spawn,
  they should arc from the attacker to the target rather than appear
  in a fixed spot.
- A "queue" indicator on the TurnOrderBar: a tiny pip showing how many
  more turns until a unit's next action.
