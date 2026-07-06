# HANDOFF 2026-07-05 — Final pass on remaining UI issues

## Two more issues found and fixed

After the first round of fixes (8 UIs with size-propagation bug), the
project still had two latent issues noted as "out of scope". This pass
addresses both.

### 1. `_is_ui_overlay_open()` didn't include the pause menu

**Bug:** In `scripts/HubWorld.gd`, `_is_ui_overlay_open()` checked for
the character menu, cooking table, base interior, and settlement
interior — but not the pause menu. So if the user clicked the HUD's
"≡ Menu" button while the pause menu was open, the CharacterMenu
opened on top of the PauseMenu (both visible at once, both
interactive).

**Fix:**

```diff
 func _is_ui_overlay_open() -> bool:
     if _hud != null and ... is_character_menu_open():
         return true
     if _cooking_table_ui != null and is_instance_valid(_cooking_table_ui):
         return true
     if _base_interior != null and is_instance_valid(_base_interior):
         return true
+    if _pause_menu != null and is_instance_valid(_pause_menu) and _pause_menu.visible:
+        return true
     var sm: Node = ...
     if sm != null and sm.is_inside_settlement():
         return true
     return false
```

Also added an `_is_ui_overlay_open()` guard to the public
`open_character_tab()` and private `_open_character_menu()` so neither
hotkeys nor the menu button can open the CharacterMenu over the
PauseMenu.

### 2. Cosmetic `WARNING: Nodes with non-equal opposite anchors...`

**Root cause:** `anchor_right = 1.0; anchor_bottom = 1.0` leaves
`offset_right` and `offset_bottom` at their previous (non-zero) values.
The engine then warns that the size will be overridden by the anchor
computation. `anchors_preset = Control.PRESET_FULL_RECT` (property
syntax) atomically resets all 4 offsets to 0 and avoids the warning.
`set_anchors_preset(PRESET_FULL_RECT)` (method syntax) does NOT
avoid it.

**Fix:** Replaced `anchor_right = 1.0; anchor_bottom = 1.0` with
`anchors_preset = Control.PRESET_FULL_RECT` in the 9 root-level UIs
that had the pattern (and added a comment pointing to the others).
The pattern is preserved for child nodes (e.g. `bg.anchor_right = 1.0`)
where the parent's size keeps the offset bookkeeping consistent.

## Files changed in this pass

- `scripts/HubWorld.gd` — added `_pause_menu` check to `_is_ui_overlay_open`,
  added overlay guard to `open_character_tab` / `_open_character_menu`
- `scripts/QuestTrackerUI.gd` — `anchor_right = 1.0` → `anchors_preset = PRESET_FULL_RECT`
- `scripts/ui/HUD.gd` — same anchor-syntax change
- `scripts/ui/InventoryScreen.gd` — same anchor-syntax change
- `scripts/ui/BaseShopUI.gd` — same (also fixed earlier)
- `scripts/ui/MissionBoardInterface.gd` — same (also fixed earlier)
- `scripts/ui/ShopInterface.gd` — same (also fixed earlier)
- `scripts/ui/OptionsMenu.gd` — same (also fixed earlier)
- `scripts/Base.gd` — same (also fixed earlier)
- `scripts/Settlement.gd` — same (also fixed earlier)
- `scripts/SettlementInterior.gd` — same (also fixed earlier)

## Verification

```
$ godot --headless --path . -s validate_scripts.gd
[validate_scripts] All scripts and scenes OK.

# All 23 smoke tests pass, 0 size-override warnings
=== FINAL: 23/23 tests pass, 0 size-override warnings ===
```

A dedicated headless probe loads 16 UIs (CharacterMenu, BaseShopUI,
MissionBoard, Shop, OptionsMenu, Base, Settlement, SettlementInterior,
QuestTrackerUI, HUD, DialogueUI, Options, KeybindsScreen, Minimap,
MinimapOverhaul, Hotbar) into a 1280×720 parent — produces zero
warnings.

## Remaining warnings (all pre-existing, unrelated)

Running all 23 smoke tests with `--verbose` shows 9 total warnings.
None of them are size-override:

- `smoke_phase3.gd`: `[CharacterMenu] Unknown tab: nonsense` (deliberate
  test of the unknown-tab guard), `ObjectDB instances leaked at exit`
  (generic Godot engine warning)
- `smoke_quest_tracker.gd`: `ObjectDB instances leaked at exit`,
  `Orphan StringName: _get_configuration_warnings`
- `smoke_hover_tooltip.gd`: `ObjectDB instances leaked at exit`
- `smoke_tile_system.gd`: `[HubWorld] _tile_map is empty — cannot seed
  mobs` (smoke test loads HubWorld without a world)

These are all benign and pre-existing.
