---
name: v040-phase3-character-menu
description: v0.4.0 Phase 3 in progress. CharacterMenu tabs + Party + Crafting + keyboard hotkeys shipped. World-gen towns + Riftspire gating deferred.
---

## Current Focus: v0.4.0 Phase 3 in progress (CharacterMenu + Party + Crafting shipped); world-gen + Riftspire deferred

`CharacterMenu` is a tabbed Control with Inventory / Equipment / Crafting / Party / Stats tabs. `I` `E` `C` `P` `S` open each tab; `Tab`/`Shift+Tab` cycle; `Esc` closes. `PartyScreen` lists party + "Add from available" for `PartyNPCManager` (3 test NPCs seeded). `CraftingManager` autoload handles recipes. All 8 Phase 3 tests green.

### Immediate Next Step

Either (a) do the Phase 3 follow-up (town placement, Riftspire gating, 3 station UIs) before moving to Phase 4, or (b) skip the follow-up and start Phase 4 (Equipment + weapons + armor + accessories + stats). The deferred work doesn't block Phase 4; Phase 4 is independent.

### Relevant Handoffs

- [[v040-phase3-character-menu]] — this handoff (current focus)
- [[v040-phase2-hud-hotbar-minimap]] — Phase 2 handoff
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0400.md` — full 9-section details

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design
- `memory/CURRENT_STATE.md` — v0.4.0-dev state, Phase 3 changes documented
- `backups/2026-07-05_0340_pre_phase_3/` — pre-Phase 3 snapshot

---

**Awaiting your decision: continue Phase 3 follow-up (towns + Riftspire), or start Phase 4 (Equipment + weapons + armor + accessories)?**
