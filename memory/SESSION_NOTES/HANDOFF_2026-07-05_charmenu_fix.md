# HANDOFF 2026-07-05 — Project-wide UI size-propagation fix

## Scope of work

User reported character / inventory / equipment screens invisible on
hotkey press. Root cause: a project-wide anti-pattern in UI scripts.
Audit found 8 UIs affected. All fixed.

## Root cause (recap)

`Control.set_anchors_preset(PRESET_FULL_RECT)` only sets the anchor
ratios — it does NOT update the `size` property. When a UI is
instantiated via `script.new()` and added to a non-Container `Control`
parent (the HUD, a Settlement interior, the Base interior, etc.), the
engine does not always auto-size the child from the parent's rect.
The child's `size` is `(0, 0)` during `_ready` / `_build_ui`, so any
`Vector2(size.x - N, size.y - M)` math produces a negative or
zero-rect, and the content panel is clipped to nothing.

The original CharacterMenu case was the worst hit because it assigned
the negative size to a `PanelContainer` (`_content.size = (-40, -100)`),
so every screen inside the tab shell was invisible.

## Files fixed (8)

| File | Pattern | Was the bug actually visible? |
|------|---------|-------------------------------|
| `scripts/ui/CharacterMenu.gd`    | `size.x - 40, size.y - 100` → PanelContainer | YES — every tab invisible (the original report) |
| `scripts/ui/BaseShopUI.gd`       | `size.y - 70`, `size.x - 100, size.y - 50` | masked (engine sometimes auto-propagates; size 0 case would break it) |
| `scripts/ui/MissionBoardInterface.gd` | `size.y - 70`, `size.x - 100, size.y - 50` | same as above |
| `scripts/ui/ShopInterface.gd`    | same as above | same as above |
| `scripts/ui/OptionsMenu.gd`      | `size.x * 0.5 ± 150` for centered panel | same as above |
| `scripts/Base.gd`                | `size.y - 70`, `size.x - 140, size.y - 50` | same as above |
| `scripts/Settlement.gd`          | `size.x - 220, size.y - 60` for Leave button | same as above |
| `scripts/SettlementInterior.gd`  | dialog panel uses `size.y - 120 / - 40` | same as above |

## Fix pattern

Added to each `_ready`:

```gdscript
func _ready() -> void:
    # ... existing setup ...
    _sync_size_to_parent()   # NEW — runs BEFORE any _build_ui
    _build_ui()              # now sees correct size
    # ... existing setup ...

    var parent := get_parent()
    if parent is Control and not (parent as Control).resized.is_connected(_on_parent_resized):
        (parent as Control).resized.connect(_on_parent_resized)

func _sync_size_to_parent() -> void:
    var parent := get_parent()
    if parent is Control:
        var p: Control = parent as Control
        if p.size.x > 0 and p.size.y > 0:
            size = p.size
            position = Vector2.ZERO

func _on_parent_resized() -> void:
    _sync_size_to_parent()
    # re-place any children whose position depends on `size`
```

The fix sets `size` from the parent before children are built, and
re-syncs on parent resize so the UI stays in lockstep.

## Side issues found & fixed in `validate_scripts.gd`

1. `scenes/ui/LocalMapView.tscn` → corrected to `scenes/LocalMapView.tscn` (path typo)
2. Added missing `res://scripts/ui/OptionsMenu.gd` entry to the SCRIPTS list

Both were pre-existing — neither blocked the game, but they produced
false "missing" warnings from the validator.

## Verification

```
$ godot --headless --path . -s validate_scripts.gd
[validate_scripts] All scripts and scenes OK.

# All 23 smoke tests pass
smoke_phase2, phase3, phase3b, phase4, phase5, phase6, phase7, phase8,
smoke_dialogue, quest_tracker, ambient, combat_feedback, qol, polish,
smoke_v050, v060, v070, cooking, hover_tooltip, settlement, interior,
resource_nodes, tile_system           → 23/23 PASS
```

A targeted headless probe (HubWorld.tscn loaded, `HUD.open_character_menu(tab)`
called for each of the 5 tabs) confirms the menu and every tab now
render at `(1280, 1280)` / `(1240, 1180)`.

## Pre-existing issues NOT fixed (out of scope)

- `_is_ui_overlay_open()` in HubWorld does not include `_pause_menu`.
  If the user presses I/E/C/P/S while the pause menu is open, the
  CharacterMenu opens on top of it. Minor UX issue; not a regression.
- `BaseShopUI` still emits a `WARNING: Nodes with non-equal opposite
  anchors will have their size overridden after _ready()` in headless
  smoke runs. This is a benign Godot warning — the engine keeps our
  size — but it's noisy. Suppressing it would require either
  `@warning_ignore` annotations or restructuring to use Containers,
  neither of which is worth the churn for a cosmetic warning.

## Out-of-pattern UIs (NOT broken)

These UIs also use `size` in `_ready`, but they are loaded via
**scene files** where the scene defines a Container parent or already
sets the right `size` on the root node, so the engine propagates
correctly:

- `scripts/ui/CookingTableUI.gd` (uses scene `Margin/VBox/...` nodes)
- `scripts/PauseMenu.gd` (uses scene + `set_anchors_and_offsets_preset`
  in `open()`)
- `scripts/MainMenu.gd` (uses @onready scene nodes)
- `scripts/Options.gd` (uses @onready scene nodes)
- `scripts/CharacterSelection.gd` (uses @onready scene nodes)

## Files changed

- `scripts/ui/CharacterMenu.gd`
- `scripts/ui/BaseShopUI.gd`
- `scripts/ui/MissionBoardInterface.gd`
- `scripts/ui/ShopInterface.gd`
- `scripts/ui/OptionsMenu.gd`
- `scripts/Base.gd`
- `scripts/Settlement.gd`
- `scripts/SettlementInterior.gd`
- `validate_scripts.gd`
