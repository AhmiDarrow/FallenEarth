---
name: v091b-combat-blockers
description: Fixed combat-test blockers — RiftInstance.tscn scene had relative parent paths that orphaned 6 child nodes (grid + buttons + loot panel); overworld mob density bumped from 5 → 12, with 2 guaranteed mobs within camera view; minimap gained a local-map inset showing red/green mob dots; tile info now shows mob count + nearest distance.
---

## Current Focus: v0.9.1b — Combat Blockers Fix

### Two blockers
1. "Rifts don't transport you into the instance"
2. "No mobs are visible to get in fight on the overworld"

### Root cause (1): RiftInstance.tscn — broken scene file
The `.tscn` had 6 child nodes with `parent="<short name>"` instead of the
full path. In Godot 4, `parent="GridPanel"` is interpreted as
"parent is a top-level node called GridPanel" — but GridPanel lives at
`MainVBox/GridPanel`, so the children were silently orphaned at scene
instantiation. The RiftInstance loaded but the grid was empty, the
action buttons were missing, the loot panel never appeared, and
`_enter_dungeon_mode` errored on `grid_container.columns = ...` because
`grid_container` was null.

Smoke test (after fix) confirms all 6 children land at the right paths.

**Fixed by editing the .tscn** — changed relative paths to full paths:
- `parent="GridPanel"` → `parent="MainVBox/GridPanel"` (GridContainer)
- `parent="ActionsHBox"` → `parent="MainVBox/ActionsHBox"` (EndTurnButton, ClearRiftButton, BackButton)
- `parent="LootPanel"` → `parent="MainVBox/LootPanel"` (LootTitle, LootLabel)

### Root cause (2): Mob density + visibility — three fixes
Mobs WERE being seeded (5 of them in 512×512). The user just couldn't
find any. Three compounding issues:

a) **Density** — `count = randi_range(2, 5 + int(danger * 4))` produced
   2-9 mobs in 502×502. The chance a mob is in the camera view
   (~53×30 cells = 3% of map) was ~3% per spawn. Bumped to
   `randi_range(8, 12 + int(danger * 8))` = 8-20 mobs. Test now
   shows 12 seeded.

b) **Exclusion radius** — `abs(lx - _local_x) + abs(ly - _local_y) < 5`
   kept mobs at least 5 cells from the player on the initial hex. With
   24px cells and 1280x720 viewport, that meant no mobs in the visible
   window. Reduced to 2.

c) **Camera visibility** — even with b and c, the user might still
   spawn on a cell with no mobs in view. Added a guaranteed
   "near-spawn" pass that places 2 mobs within 3-20 cells of the
   player (in their camera view). 16-attempt rejection sampling for
   walkable cells, then EncounterBuilder generates the mob.

### Additional UX aids
- **Minimap local-map inset** — the existing minimap is a sphere
  overview (no local info). Added a 80×50 px bottom-left inset to
  `Minimap.gd` showing the player-centered local map with red dots for
  hostile mobs and gray-green for neutral. Updates on every cell
  change (HUD already calls `refresh()` each second).
- **Tile info mob readout** — `_update_tile_info` now prints
  `"N mob(s) in this region. Nearest: K cells away"` so the player
  knows where to walk without reading the minimap.
- **Rift spawn distance** — `_spawn_initial_rift_if_needed` was
  spawning 8-20 cells east of player, but the camera view is 26 cells
  wide so rifts were sometimes just off-screen. Reduced to 4-12 cells
  and added map-bounds clamping. The ⚡ glyph is now reliably visible
  from spawn.

### Files changed
- `scenes/RiftInstance.tscn` — fixed 6 relative parent paths
- `scripts/HubWorld.gd` — bumped mob count, added near-spawn pass,
  added mob info to tile info, reduced rift spawn distance
- `scripts/ui/Minimap.gd` — added `_cached_mobs` + `_local_player_x/y`
  + `_draw_local_inset()` red/green mob dots

### New test
`tools/smoke_combat_blockers.gd` — 7 groups:
1. World + GameState setup (synthetic char at -6,0 / Neon Bogs)
2. EncounterBuilder returns enemy with valid sprite
3. GameState._overworld_mobs gets populated (3 direct seeds)
4. HubWorld instantiates and spawns 5+ mob sprites into mob_layer
   with valid loaded textures
5. RiftRunner.add_rift_entrance + get_rift_at_local round-trip
6. pending_rift round-trip + RiftInstance children all at proper paths
7. At least one mob within 25 cells of player (catches the "no mob
   visible" symptom directly)

### Verification

```bash
& godot --headless --path . -s tools/smoke_combat_blockers.gd   # 7/7 pass
& godot --headless --path . -s validate_scripts.gd              # OK
& godot --headless --path . -s tools/smoke_tile_system.gd      # 4/4 pass
& godot --headless --path . -s tools/boot_probe.gd              # 60 frames OK
& godot --headless --path . -s tools/smoke_v050.gd             # 6/6 pass
& godot --headless --path . -s tools/smoke_v060.gd             # 11/11 pass
& godot --headless --path . -s tools/smoke_audio.gd            # 12/12 pass
& godot --headless --path . -s tools/smoke_ambient.gd          # 5/5 pass
& godot --headless --path . -s tools/smoke_combat_feedback.gd  # 4/4 pass
& godot --headless --path . -s tools/smoke_polish.gd           # 7/7 pass
& godot --headless --path . -s tools/smoke_qol.gd              # 4/4 pass
& godot --headless --path . -s tools/smoke_dialogue.gd         # 5/5 pass
& godot --headless --path . -s tools/smoke_quest_tracker.gd    # 5/5 pass
& godot --headless --path . -s tools/smoke_hover_tooltip.gd    # 4/4 pass
& godot --headless --path . -s tools/smoke_resource_nodes.gd  # 7/7 pass
& godot --headless --path . -s tools/smoke_interior.gd         # 16/16 pass
& godot --headless --path . -s tools/smoke_cooking.gd          # 22/22 pass
```

### Notes for next session
- Combat is now testable end-to-end. The user should be able to spawn,
  see a red mob dot on the minimap inset, walk toward it, and trigger
  tactical combat.
- The Minimap is still 180x180 px sphere overview; the new local inset
  is 80x50 px. Both fit in the top-right HUD without overlap.
- The 12-mob default means each hex has decent combat density. The
  player can still walk off into a corner and find nothing — that's
  intentional (encourage exploration). If user feedback says 12 is
  too many, the knob is `randi_range(8, 12 + int(danger * 8))` in
  `_seed_local_mobs`.
