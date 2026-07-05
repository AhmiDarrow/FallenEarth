---
name: v050-hpmp-combat-wiring
description: v0.5.0 HP/MP combat wiring COMPLETE. Both outstanding v0.5.0 issues fixed; all 6 smoke_v050 tests green.
---

## Current Focus: v0.5.0 HP/MP combat wiring COMPLETE

v0.5.0 is now fully shipped. The two outstanding issues from the PLAN are both fixed and all 6 `smoke_v050` tests pass. The fixes were entirely in the test harness (`tools/smoke_v050.gd`); production code (CombatManager.use_item, EquipmentManager.get_max_hp/attack) was already correct.

**Key insight:** Autoload `_ready` is deferred to the next idle frame, so any smoke test that calls `root.get_node_or_null("/root/SomeAutoload")` and immediately reads data sees an empty dict. Fix is `await process_frame` at the start of `_initialize`. **This pattern should be in every smoke test that depends on autoload data.**

### Immediate Next Step

The pre-existing v0.4.0 issues surfaced by the test suite (not introduced by v0.5.0) are the next priority:
1. `MissionManager.gd:214` — `GameState.mob_key` reference (autoload treated as class; parser flags but runtime works).
2. `smoke_phase5.gd:203` — `gs.faction_rep_changed = Callable()` (can't assign to signal).
3. `smoke_phase5` — `spawn_for_hex` is RNG-flaky.
4. `smoke_tile_system` — LocalMapView legacy rift_scar normalization logs an ERROR but reports "ok".

After those are cleaned up, plan v0.6.0 (see PLAN's "Not yet done in v0.5.0+" list).

### Relevant Handoffs

- [[v050-hpmp-combat-wiring]] — this handoff (v0.5.0 complete)
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0530.md` — full 9-section details
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0500.md` — v0.4.0 Phase 3 follow-up
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0400.md` — v0.4.0 Phase 3 first half

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design (mark v0.5.0 issues section as resolved)
- `memory/CURRENT_STATE.md` — v0.5.0-dev state

---

**Awaiting your decision: fix the 4 pre-existing v0.4.0 polish issues, or plan v0.6.0?**
