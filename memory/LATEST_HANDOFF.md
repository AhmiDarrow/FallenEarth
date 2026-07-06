---
name: v102-combat-sizing
description: v0.10.2 Combat sizing pass — bigger cells, bigger bars, bigger arrow, action bar at bottom.
---
# v0.10.2 Combat Sizing Pass

## User request
"still needs work" — screenshot showed the grid was way too small
(7×7×24=168px wide, ~13% of the viewport), HP bars were tiny
(24×4 = barely visible), selection arrow was a small triangle
(18×16), and the action bar was floating in the middle of the
screen rather than at the bottom.

## What shipped

### Cell size: 24 → 40
- `BattleGridView.CELL_SIZE` = 40 (was 24)
- `BattleCell.CELL_SIZE` = 40 (was 24)
- `BattleCell.BORDER_THICKNESS` = 3 (new const for chunky edges)
- `BattleUnit.CELL_SIZE` = 40 (was 24)
- `BattleBackground.TILE_SIZE` = 40 (was 24) — for the local
  "no-decor-in-grid-rect" math
- New grid is 7×7×40 = 280px wide, ~22% of the 1280px viewport

### Bigger HP bars
- `CombatHPBar.BAR_WIDTH` = 36 (was 24), `BAR_HEIGHT` = 6 (was 4)
- New `LABEL_OFFSET_Y` = -8, `BAR_OFFSET_Y` = -2 (constants)
- New dark border ring around the bar for definition
- Now reads as an actual bar, not a thin line

### Bigger selection arrow
- `UnitSelectionArrow.WIDTH` = 28 (was 18), `HEIGHT` = 24 (was 16)
- `BOB_HEIGHT` = 5 (was 4)
- Triangle layers re-tuned for the new size (still 3-layer)

### Bigger name plate
- `UnitNamePlate.WIDTH` = 96 (was 80), `HEIGHT` = 20 (was 16)
- `font_size` = 10 (was 9)
- Re-positioned in BattleUnit to clear the new arrow + bars

### Turn order bar improvements
- `SLOT_SIZE` = 64 (was 56), `SLOT_SPACING` = 8 (was 6)
- Bar height 112 (was 96) to fit the bigger slots
- **Procedural portrait fallback**: missing-sprite slots now draw
  a chunky character silhouette in the team color (head + body
  + eyes + border) so the player still reads "this unit exists"
  even if the race sprite path is missing

### Action bar at the very bottom
- New offset: `offset_top = -160`, `offset_bottom = -124`
- Sits 12px above the SkillBar (-112..-16) and 16px below the
  UnitInfoCard (-208..-16) — matches the FFT reference where
  End Turn is just above the skill bar
- End Turn button: 160×36 (was 140×56) — wider, less tall
- Retreat button: 120×36 (was 110×44)

## Verification

| File | Checks | Status |
|------|--------|--------|
| `validate_scripts.gd` | All | All OK |
| `tools/smoke_combat_v100.gd` | 27 (visual) | All pass |
| `tools/smoke_combat_ui.gd` | 15 (UI) | All pass |
| `tools/smoke_combat_ai.gd` | 11 (AI) | All pass |
| `tools/smoke_combat_feedback.gd` | 4 (feedback) | All pass |
| `tools/smoke_combat_polish.gd` | 7 (polish) | All pass |
| `tools/boot_combat.gd` | full scene boot | All pass |
| `tools/boot_probe.gd` | 60 frames | 0 errors |

## Architecture constraints held
- Cell size is a single `const CELL_SIZE` on each combat node;
  bumping it cascades cleanly through `BattleGridView`,
  `BattleCell`, `BattleUnit`, `BattleBackground`. No magic
  numbers in the layout code.
- HP bar size is a single `const BAR_WIDTH/BAR_HEIGHT` block
  on `CombatHPBar`. Update in one place to scale further.

## What's next (P1 for future)
- Make the unit sprites 32x32 or 48x48 to fill the bigger cells
  (currently they're 64x64 scaled to 0.5× = 32x32 native, which
  looks fine but could be punchier).
- Consider isometric grid (FFT has subtle diamond-shape cells).
- Per-decor-test: 6×6 visual grid test in
  `tools/smoke_combat_polish.gd` that takes a screenshot for
  visual QA.

