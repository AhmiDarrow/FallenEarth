---
name: v040-phase2-hud-hotbar-minimap
description: v0.4.0 Phase 2 complete. Full HUD + hotbar + minimap + ProgressionManager + LootRoller. 6 test groups green. Next: Phase 3 crafting + towns + Riftspire.
---

## Current Focus: v0.4.0 Phase 2 complete; Phase 3 next

`ProgressionManager` (XP/level/EC autoload) and `LootRoller` (mob drops + XP/EC) are in. The new `HUD.gd` composes top bar + HP/MP/XP bars + Minimap + Hotbar; the old `CharInfoBar` is hidden. The 10-slot Hotbar uses keys 1-0 and HubWorld resolves the selected slot through `data/tools.json` for the gather action. All 6 test groups green.

### Immediate Next Step

F5 to confirm the HUD looks right, then move to Phase 3 (crafting inventory tab + 3 stations + NPC towns + Riftspire capital hex) per `docs/PLAN_v040_crafting_progression.md` §5. **Only after explicit "go"** per the per-phase delivery workflow.

### Relevant Handoffs

- [[v040-phase2-hud-hotbar-minimap]] — this handoff (current focus)
- [[v040-phase1b-hover-tooltips]] — Phase 1b (predecessor)
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0300.md` — full 9-section details

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design for Phases 3-8
- `memory/CURRENT_STATE.md` — v0.4.0-dev state, Phase 2 changes documented
- `backups/2026-07-05_0240_pre_phase_2/` — pre-Phase 2 snapshot

---

**Awaiting permission to start Phase 3 (crafting + towns + Riftspire).**
