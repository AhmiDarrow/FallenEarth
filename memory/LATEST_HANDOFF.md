---
name: hubworld-mob-combat-fix
description: Fixed scene parse error that broke HubWorld mob spawning and combat
---

## Current Focus: HubWorld Mob Visibility & Combat Fix

Fixed scene parse error in `HubWorld.tscn` (and 3 test scenes) that was caused
by a stale `[ext_resource]` to `res://scripts/procedural/Entity3DViewport.gd`
— a file that was deleted from the working tree but still referenced in
scenes. Removed the broken ext_resource and the now-orphaned
`Entity3DLayer` / `Entity3DDisplay` nodes from all 4 affected scenes.
Added diagnostic `print` in `_seed_local_mobs()` so future F5 runs surface
biome / danger / seeded / skipped counts.

### Immediate Next Step

F5 playthrough: New Game → World Gen → pick start hex → Character → HubWorld.
Verify mobs render as PNG sprites (27 mobs in `assets/mobs/`) and that
walking into a mob cell triggers tactical combat. Watch for the new
`[HubWorld] Mob seed: biome=...` line in Godot Output.

### Relevant Handoffs

- [[hubworld-mob-combat-fix]] — this handoff (current focus)
- [[stardew-sprite-pipeline-handoff]] — display options (still relevant)
- [[latter-handoff]] — procedural drawing milestone (mostly obsolete post-fix)

### Context Files

- `docs/NEXT_TASKS.md` — project task queue (P0 F5 playthrough is now the active test)
- `memory/PROJECT_MEMORY.md` — display conventions unchanged
- `memory/SESSION_NOTES/HANDOFF_2026-07-04_2034.md` — full 9-section details on this fix

---

Proceed with F5 verification, then continue with `docs/NEXT_TASKS.md` P1 items.