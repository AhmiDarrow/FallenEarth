---
name: v040-phase1b-hover-tooltips
description: v0.4.0 Phase 1b complete. Hover tooltips with 1s dwell. Next: Phase 2 HUD + hotbar + minimap.
---

## Current Focus: v0.4.0 Phase 1b complete; Phase 2 next

`HoverTooltip` is a Control with a Label that follows the mouse after a 1-second dwell. `HubWorld._hit_test_at_world` does the hit-test with priority: resource node > pickup > mob > rift > NPC > mission > terrain. 4 new tests in `smoke_hover_tooltip.gd`. All 5 test groups green.

### Immediate Next Step

F5 to confirm the tooltip works in-game, then move to Phase 2 (full Character HUD + 10-slot hotbar + minimap + Inventory screen + mob drops + XP/EC + ProgressionManager autoload) per `docs/PLAN_v040_crafting_progression.md` §4. **Only after explicit "go"** per the per-phase delivery workflow.

### Relevant Handoffs

- [[v040-phase1b-hover-tooltips]] — this handoff (current focus)
- [[v040-phase1-resource-nodes]] — Phase 1 (foundation: HarvestNode, FloorPickup, InventoryManager)
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0220.md` — full 9-section details

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design for Phases 2-8
- `memory/CURRENT_STATE.md` — v0.4.0-dev state, Phase 1b changes documented
- `backups/2026-07-05_0215_pre_phase_1b/` — pre-Phase 1b snapshot

---

**Awaiting permission to start Phase 2 (full HUD + hotbar + minimap).**
