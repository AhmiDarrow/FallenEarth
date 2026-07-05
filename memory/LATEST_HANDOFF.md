---
name: v040-pre-existing-polish
description: All 4 pre-existing v0.4.0 polish issues FIXED. Full v0.4.0 + v0.5.0 test suite is green and deterministic (smoke_phase5 verified 10/10 runs).
---

## Current Focus: Pre-existing v0.4.0 polish COMPLETE

All 4 polish issues from `HANDOFF_2026-07-05_0530.md` are fixed. Plus one bonus production bug (`_faction_rep_for` early-return on empty `_faction_names`) that surfaced when the RNG fix exposed a downstream test bug. Full 14-script test suite is green; smoke_phase5 is now deterministic.

**Key insight chain (Remedy's favorite bug story):** Seeding the RNG → faction rep test started failing consistently → traced to wrong ProgressionManager instance in test → noticed the test was using a local `TestProg7` instead of the autoload → also noticed `_faction_rep_for` had a `_faction_names.is_empty()` early-return that silently broke the function for new players. Two bugs in one investigation.

### Immediate Next Step

Plan v0.6.0. Recommended: **real combat damage wiring + more consumables** (builds directly on v0.5.0). Alternative candidates: procedural NPC spawn in settlements, settlement interiors, settlement-to-Riftspire travel, button asset set.

### Relevant Handoffs

- [[v040-pre-existing-polish]] — this handoff
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1300.md` — full 9-section details
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0530.md` — v0.5.0 final (fixes for 2 outstanding v0.5.0 issues)
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0500.md` — v0.4.0 Phase 3 follow-up

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design
- `memory/CURRENT_STATE.md` — full state
- `docs/NEXT_TASKS.md` — v0.6.0 candidate list

---

**Awaiting your decision: which v0.6.0 candidate to pursue first?**
