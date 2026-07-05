---
name: v070-procedural-npc-spawn
description: v0.7.0 — replace hard-coded test NPCs with biome- AND faction-aware procedural spawn. Settlements reflect their owning faction (Iron Accord towns get Iron-Accord-themed NPCs, Hollow Covenant towns get Hollow-themed NPCs, etc.). 12 smoke_v070 tests green; full 17-script suite all pass.
---

## Current Focus: v0.7.0 procedural NPC spawn COMPLETE

Replaced the Phase 3 hard-coded test NPCs with procedural spawn that respects both the settlement's biome AND its owning faction. Per the user's brief: "settlements belong to a specific faction, the world needs to balance the weights between settlements to faction ratio."

**Key design decisions:**
- Template roll weighting: match_both 4x, match_faction_only 3x, match_biome_only 2x, universal 1x. Faction matches get a stronger boost than biome matches because settlement identity is primarily faction-based.
- Faction theme overrides biome theme for `name_prefix` and `race_pref`. Biome theme wins for the role title (e.g., "bogs-runner" in Neon Bogs).
- 18 templates (was 4): 4 universal + 7 biome-specific + 7 faction-specific.
- `spawn_for_settlement(hex, biome, faction, size)` is deterministic per settlement (FNV-1a hash of `hex|biome|faction`).
- `clear_settlement_residents(hex)` prevents duplicate accumulation on re-enter.

### Immediate Next Step

v0.7.1 polish (small, 1-2 hours): wire `spawn_for_settlement` into the actual settlement enter flow in `SettlementManager`; add `preferred_race` to faction themes. OR v0.8.0 candidates: full settlement interiors, settlement-to-Riftspire travel, button asset set, "place station" interaction.

### Relevant Handoffs

- [[v070-procedural-npc-spawn]] — this handoff
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1700.md` — full 9-section details
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1600.md` — v0.6.0 follow-up polish
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1500.md` — v0.6.0 cooking table + mob drops

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design
- `memory/CURRENT_STATE.md` — v0.7.0-complete
- `docs/NEXT_TASKS.md` — v0.7.1 + v0.8.0 candidates

---

**Awaiting your decision: v0.7.1 polish, v0.8.0 candidate, or something else?**
