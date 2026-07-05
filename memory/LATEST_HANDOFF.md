---
name: v040-phase1-resource-nodes
description: v0.4.0 Phase 1 complete. Resource nodes + floor pickups + InventoryManager + gather action. Next: Phase 1b hover tooltips.
---

## Current Focus: v0.4.0 Phase 1 complete; Phase 1b next

Resource nodes (trees, formations, ore, crystals, fauna) and floor pickups (sticks, stones) are now on the local map. `InventoryManager` autoload holds the 30-slot stack inventory. `E` key gathers; walking onto a pickup auto-collects. 41 procedural sprites via PIL. All 5 test groups green.

### Immediate Next Step

F5 to confirm nodes + pickups look right, then move to Phase 1b (hover tooltips — 1s dwell, Label follows mouse) per `docs/PLAN_v040_crafting_progression.md` §3.1. **Only after explicit "go"** per the per-phase delivery workflow.

### Relevant Handoffs

- [[v040-phase1-resource-nodes]] — this handoff (current focus)
- [[v040-phase0-rift-scar-drop]] — Phase 0 (foundation for Phase 1)
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0200.md` — full 9-section details

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design for Phases 2-8
- `memory/CURRENT_STATE.md` — v0.4.0-dev state, Phase 1 changes documented
- `backups/2026-07-05_0101_pre_phase_1/` — pre-Phase 1 snapshot

---

**Awaiting permission to start Phase 1b (hover tooltips, 1s dwell).**
