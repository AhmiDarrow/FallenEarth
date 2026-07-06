# HANDOFF 2026-07-05 — CharacterMenu rewritten to match the PauseMenu pattern

## User feedback

> "look at how the pause screen works cause I can see it and use the
> same method for all the character screens"

The pause menu worked reliably; the character menu (and its tabs)
had been patched multiple times to fix the size-propagation bug but
the implementation was still ad-hoc. This pass rebuilds the
CharacterMenu to use the exact same pattern as the PauseMenu.

## What the PauseMenu does right (the pattern to copy)

1. **Has a dedicated scene file** (`scenes/ui/PauseMenu.tscn`) with
   the root Control set up correctly:
   ```
   [node name="PauseMenu" type="Control"]
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   ```
   The combination of `anchors_preset = 15` (full rect) plus
   `grow_horizontal/vertical = 2` (expand both directions) is the
   Godot 4 way to say "fill the parent, no matter what".

2. **Script's `open()` method forces full-viewport geometry** as a
   belt-and-braces measure:
   ```gdscript
   func open() -> void:
       var vp_size: Vector2 = get_viewport_rect().size
       set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
       custom_minimum_size = vp_size
       size = vp_size
       position = Vector2.ZERO
       z_index = 100
       move_to_front()
       visible = true
   ```

3. **`process_mode = PROCESS_MODE_ALWAYS`** in `_ready()` so input
   reaches the menu even while the game is paused.

4. **Mounted on a `CanvasLayer`** so the menu overlays everything
   else, including the world and the HUD:
   ```gdscript
   var layer := CanvasLayer.new()
   layer.layer = 100
   add_child(layer)
   layer.add_child(_pause_menu)
   ```

5. **The shell's UI is declared in the scene**; only the dynamic
   content (save/load popups) is built in code.

## What I did to match this

### `scenes/ui/CharacterMenu.tscn` (new)

- Root `Control` with `anchors_preset = 15`, `anchor_right = 1.0`,
  `anchor_bottom = 1.0`, `grow_horizontal/vertical = 2`
- `Background` ColorRect (full rect, dark blue)
- `TitleLabel` Label "[ Character ]" (top-left)
- `CloseButton` Button "X" (top-right)
- `TabBar` HBoxContainer (under the title, will hold 5 tab buttons)
- `ContentPanel` PanelContainer (below the tab bar, will hold the
  dynamic per-tab screen Control)

### `scripts/ui/CharacterMenu.gd` (refactored)

- `@onready` references to the scene's shell nodes
  (`_background`, `_title_label`, `_close_btn`, `_tab_bar`,
  `_content`).
- `_ready()` calls `_ensure_shell()` which no-ops if the scene
  nodes are present but builds them on the fly if the script was
  instantiated via `script.new()` (so smoke tests still work).
- New `open(initial_tab)` method that mirrors PauseMenu's `open()`:
  forces full-viewport geometry, sets `z_index = 50`,
  `mouse_filter = MOUSE_FILTER_STOP`, `move_to_front()`, and selects
  the requested tab. This is the public entry point used by HUD.
- `_ready()` still opens the default "inventory" tab so a
  `script.new()`-style instantiation (e.g. in smoke tests) sees the
  expected initial state.

### `scripts/ui/HUD.gd` (updated)

`open_character_menu` now mirrors HubWorld's `_toggle_pause_menu`:

```gdscript
var scene: PackedScene = load("res://scenes/ui/CharacterMenu.tscn") as PackedScene
if scene == null:
    push_error("[HUD] CharacterMenu.tscn not found")
    return
_character_menu = scene.instantiate() as CharacterMenu
_character_menu.name = "CharacterMenu"
_character_menu.closed.connect(_on_character_menu_closed)
var layer := CanvasLayer.new()
layer.name = "CharacterMenuLayer"
layer.layer = 90   # below the pause menu's 100
add_child(layer)
layer.add_child(_character_menu)
_character_menu.open(initial_tab)
```

The character menu now lives on a dedicated CanvasLayer
(`CharacterMenuLayer`, layer = 90) inside the HUD. The pause menu
lives on its own CanvasLayer (`PauseMenuLayer`, layer = 100) inside
HubWorld, so it sits visually above the character menu — pressing
Escape from inside a character tab closes the character menu and
brings the pause menu into focus.

### `validate_scripts.gd` (updated)

Added `res://scenes/ui/CharacterMenu.tscn` to the SCENES list so the
new scene is verified by the validator.

## Files changed

- `scenes/ui/CharacterMenu.tscn` (new) — the scene file
- `scripts/ui/CharacterMenu.gd` (refactored) — uses @onready refs
  + open() method, defensive build for script.new() use
- `scripts/ui/HUD.gd` (updated) — load from scene + CanvasLayer
- `validate_scripts.gd` (updated) — list the new scene

## Verification

```
$ godot --headless --path . -s validate_scripts.gd
[validate_scripts] All scripts and scenes OK.

# All 23 smoke tests pass
=== Summary: 23 passed, 0 failed ===
```

A dedicated headless probe loaded `HubWorld.tscn`, called
`hub.open_character_tab(tab)` for inventory/crafting/party/stats
(equipment was skipped because it triggers the EquipmentManager
and was hanging the test in this environment), confirmed the menu
opens at full viewport size `(1280, 1280)`, all 5 shell children
are present, and the hotkeys work both standalone and while the
pause menu is open. The probe was removed after verification.

## Behaviour notes

- The character menu now fills the entire viewport (matching the
  pause menu), because `open()` calls `set_anchors_and_offsets_preset`
  + `size = vp_size`.
- The character menu is on a `CanvasLayer` (layer 90) so it overlays
  the world and the rest of the HUD.
- The pause menu is on its own `CanvasLayer` (layer 100), so it
  overlays the character menu. Pressing Escape from inside a
  character tab closes the character menu first; pressing Escape
  again with the character menu gone opens the pause menu.
- Character hotkeys (I/E/C/P/S) work whether or not the pause menu
  is open (already fixed in the previous pass).
- The character menu no longer needs the `_sync_size_to_parent` /
  `_on_parent_resized` workarounds — the scene + `open()` pattern
  gives the menu a deterministic size from the start.
