---
name: v100-combat-overhaul
description: v0.10.0 Combat Overhaul — real sprites, AI for mobs, fancy UI, biome backgrounds. 4 phases, all green.
---
# v0.10.0 Combat Overhaul

## User request
"Combat overhaul, it should use the same sprite system as the overworld, sprites
and tiles. We also need to write AI for the mobs. and also need the battle ui to
look fancier and more stylish, generate any assets needed. review final fantasy
tactics for inspiration on how this should look and flow but with our styles.
It should have matching backgrounds surrounding the battlegrid tiles."

## What shipped (4 phases, all green)

### Phase 1 — Visual overhaul
- `scripts/combat/BattleCell.gd` — terrain tile + height mark + range highlight
- `scripts/combat/BattleGridView.gd` — 7×7 grid, real biome `ground.png` tiles
- `scripts/combat/BattleUnit.gd` — mob sprite + facing flip + HP/CT bars + tweens
- `scripts/combat/BattleBackground.gd` — biome tint + ~64 scattered tiles + 18 motes
- `scripts/TacticalCombat.gd` refactored; `scenes/TacticalCombat.tscn` restructured
- **Old `Button[]` grid + text symbols (◎/☠/✕) removed**

### Phase 2 — AI overhaul
- `scripts/ai/CombatAI.gd` — base + `chebyshev` / `facing_bonus` / `score_attack` helpers
- `scripts/ai/AggressiveAI.gd` — melee rush, prefers flanking
- `scripts/ai/RangedAI.gd` — maintains distance, retreats too close
- `scripts/ai/CasterAI.gd` — prefers skills, AOE positioning
- `scripts/ai/DefensiveAI.gd` — guards allies, retreats < 30% HP
- `scripts/ai/BossAI.gd` — 3-phase enrage, signature ability once
- `scripts/ai/CombatAIEngine.gd` — factory + state builder
- `scripts/CombatManager.gd._run_enemy_turn` refactored to dispatch to AI
- `data/mobs.json` — `ai_archetype` added to all 27 mobs (5 archetypes)

### Phase 3 — UI polish (FFT-style HUD)
- `scripts/combat/BattleHUD.gd` — top portrait + HP/MP/CT bars
- `scripts/combat/TurnOrderPanel.gd` — right sidebar, 6 mini-portraits + CT
- `scripts/combat/BattleResultPanel.gd` — styled victory/defeat
- `scripts/combat/CombatPopup.gd` — MISS/CRITICAL/BACK floating text
- `scripts/combat/TargetingReticle.gd` — 4-corner pulsing bracket

### Phase 4 — Assets (PixelLab MCP)
- `assets/battle_ui/battle_hud_panel.png` (512×256) — dark rusted metal
- `assets/battle_ui/victory_panel.png` (512×256) — stained parchment
- `assets/battle_ui/defeat_panel.png` (512×256) — cracked crimson stone
- `assets/battle_ui/reticle.png` (64×64) — golden yellow brackets
- `assets/battle_ui/icon_attack.png` (32×32) — sword + shield
- `assets/battle_ui/icon_skill.png` (32×32) — magical blue flame
- `assets/battle_ui/icon_wait.png` (32×32) — hourglass

## Verification

| File | Checks | Status |
|------|--------|--------|
| `tools/smoke_combat_v100.gd` | 27 (visual) | All pass |
| `tools/smoke_combat_ai.gd` | 11 (AI) | All pass |
| `tools/smoke_combat_ui.gd` | 15 (UI) | All pass |
| `validate_scripts.gd` | All | All OK |
| `tools/boot_probe.gd` | 60 frames | 0 errors |
| `tools/smoke_combat_feedback.gd` | 4 (legacy) | All pass (no regression) |

## Architecture constraints held
- Combat reads from `data/mobs.json`, `data/tilesets/{biome}/`, `assets/mobs/{id}.png`
  — same pipeline as overworld. No parallel sprite system.
- Biome backgrounds use the existing biome `tilesets/{biome}/ground.png` scattered
  around the grid + biome-themed tints + drifting motes (no new tile pipeline).
- 7 UI assets generated via PixelLab MCP (uses existing MCP key, 4607→4487
  generations remaining after this session).

## What's next (P1 for future)
- Action menu polish — wire the 3 action icons (attack/skill/wait) into the
  bottom HBoxContainer buttons (currently text-only).
- TargetingReticle follow-the-cursor in `TacticalCombat._process` (currently
  created but not yet positioned by mouse).
- CombatPopup spawn integration in `_resolve_attack` (MISS / CRITICAL / BACK!
  popups based on facing_bonus + crit roll).
- MultiMesh resource visual re-add (deferred from v0.9.1c) so the overworld
  trees/rocks are visible again.
