# HANDOFF 2026-07-05 — Character hotkeys must work even when paused

## Bug

User reported: "character screen does not show up, pause menu shows up,
character screen, equipment screen craft etc should all work the same."

The character menu / inventory / equipment / craft / party / stats
tabs were not opening when their hotkeys (I/E/C/P/S) were pressed
*while the pause menu was open*. The pause menu itself worked fine
(opened on Escape, closed on Escape).

Two distinct issues caused this:

### Issue 1: `if get_tree().paused: return` blocks all hotkeys

`HubWorld._unhandled_input` started with:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed):
        return
    if get_tree().paused:        # ← this short-circuited everything
        return
    ...
    if km.is_action_pressed("inventory", event):
        open_character_tab("inventory")
        ...
```

When the pause menu opened, it set `get_tree().paused = true`.
HubWorld's input handler then returned early for every key, including
I/E/C/P/S. The character menu never got a chance to open.

The original intent of the early-return was to prevent the player
from moving their character or interacting with the world while the
game is paused. But it also blocked the character-menu hotkeys, which
are pure UI and don't mutate game state.

**Fix:** Removed the early-return on paused. The character-menu
hotkeys now always run. The game-specific input (movement, interact,
world map) is now gated by the combined `_is_ui_overlay_open() or
get_tree().paused` check that sits *after* the character-menu hotkey
block, so the world still can't be manipulated while paused.

Same fix applied to `_fallback_unhandled_input` (the path used when
the KeybindManager autoload isn't available).

### Issue 2: HUD had size (0, 0), breaking all child character menus

The previous round's "fix" for the cosmetic `Nodes with non-equal
opposite anchors` warning was to switch the HUD (and other UIs) from
`anchor_right = 1.0, anchor_bottom = 1.0` to
`anchors_preset = Control.PRESET_FULL_RECT`. But in Godot 4.3 the
`anchors_preset` property setter does NOT trigger the engine's
anchor-to-size propagation. So the HUD ended up at size (0, 0), and
since the character menu is a child of the HUD, it inherited that 0
size and rendered invisibly.

A headless probe confirmed:

```
--- A: anchors_preset = PRESET_FULL_RECT ---
  BEFORE await: a.size = (0, 0)
  AFTER await:  a.size = (0, 0)
--- B: anchor_right = 1.0, anchor_bottom = 1.0 ---
  BEFORE await: b.size = (1280, 1280)
  AFTER await:  b.size = (1280, 1280)
```

The `anchor_right = 1.0` form *does* trigger the engine's
auto-propagation (and prints the cosmetic warning, which is benign).
The `anchors_preset =` form does NOT.

**Fix:** Reverted the HUD to `anchor_right = 1.0, anchor_bottom = 1.0`,
and added a defensive `_sync_size_to_parent()` so the HUD explicitly
sets its size to the parent's size before building children (same
pattern as CharacterMenu, BaseShopUI, etc.). The cosmetic warning
re-appears for the HUD only — the other 7 UIs still use the
`anchors_preset` form and are unaffected.

The warning is now an acceptable trade-off: it surfaces real layout
configurations, and the auto-propagation works as needed.

## Files changed

- `scripts/HubWorld.gd` — removed `get_tree().paused` early-return;
  combined overlay+paused gate; removed pause menu from
  `_is_ui_overlay_open`; removed `_is_ui_overlay_open` guard from
  `open_character_tab` and `_open_character_menu`
- `scripts/ui/HUD.gd` — reverted anchor pattern, added
  `_sync_size_to_parent` + `_on_parent_resized`

## Verification

A dedicated headless probe simulates real `Input.parse_input_event`
for each of I/E/C/P/S, with and without the pause menu open:

```
[probe] All hotkeys work as expected.
```

All 23 smoke tests still pass; `validate_scripts` is clean.

## Final design for "pause menu" vs "character menu"

The two are now genuinely independent overlays:

- **Escape** opens/closes the pause menu (toggles `get_tree().paused`).
- **I / E / C / P / S** open/switch the character menu tabs.
  These work whether the game is paused or not.
- The HUD "≡ Menu" button opens the character menu regardless of
  pause state.
- The character menu's own Escape handler closes the character menu
  first; the Escape press is then *not* re-handled by HubWorld
  (because the character menu marks the event as handled).
  Re-pressing Escape opens the pause menu.
- The pause menu's own Escape handler closes the pause menu and
  unpauses the tree.
- Game-specific input (WASD movement, E to interact/gather, M for
  world map) is still blocked while the game is paused or while a
  modal overlay (cooking table, base interior, settlement interior)
  is open — only the character menu, which is non-modal, lets its
  hotkeys through.
