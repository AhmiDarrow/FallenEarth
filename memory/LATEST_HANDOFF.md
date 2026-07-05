---
name: v040-phase0-rift-scar-drop
description: v0.4.0 Phase 0 complete. Rifts are now entities (markers), terrain atlas is 4 rows. Next: Phase 1 resource nodes.
---

## Current Focus: v0.4.0 Phase 0 complete; Phase 1 next

Dropped the rift_scar terrain type. `TERRAIN_RIFT_SCAR` constant removed from `LocalMapGenerator` and `TileSetService`; atlas is now 24×96 (4 rows: ground, debris, vegetation, blocked); 10 `rift_scar.png` files deleted; 40 tiles regenerated; legacy `terrain[i] == 4` is normalized to `TERRAIN_GROUND` in `LocalMapView.configure()` (backward compatible with old saves). v0.3.0 baseline committed at `883eca5` and pushed; Phase 0 follow-up commit pending.

### Immediate Next Step

F5 visual playthrough to confirm rifts still appear (now as ⚡ markers on the local map) and the new 4-row terrain looks right. Then move to Phase 1 (resource nodes + gathering + tool-tier gating + sticks/stones) per `docs/PLAN_v040_crafting_progression.md` §3 — but **only after explicit "go"** per the per-phase delivery workflow.

### Relevant Handoffs

- [[v040-phase0-rift-scar-drop]] — this handoff (current focus)
- [[v030-tilemap-layer-refactor]] — Phase 0 was built on the v0.3.0 TileMapLayer foundation
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0057.md` — full 9-section details
- `memory/SESSION_NOTES/HANDOFF_2026-07-04_2156.md` — v0.3.0 handoff

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design for Phases 1-8
- `memory/CURRENT_STATE.md` — v0.4.0-dev state
- `memory/PROJECT_MEMORY.md` — PixelLab pipeline notes (for any future asset generation)
- `backups/2026-07-05_0056_pre_phase_0/` — pre-Phase 0 snapshot (excluded from git; `.gdignore` marks it for Godot)

---

**Awaiting permission to start Phase 1 (resource nodes + gathering + sticks/stones).**
