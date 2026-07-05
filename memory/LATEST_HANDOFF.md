---
name: v060-combat-damage-and-consumables
description: v0.6.0 real combat damage wiring (per-class weapon stats + dynamic equipment) + 3 new consumables (mana_potion, cooked_meat, antidote). 11 smoke_v060 tests green; full 15-script suite all pass.
---

## Current Focus: v0.6.0 combat damage + consumables COMPLETE

v0.6.0 is shipped. The user's key reminder ("not all class weapons use the same stat") drove the fix: `em.get_attack` now sums stat_mods from all equipment, so Technicians get +1 int (not +0 str), Riftbinders get +3 int+wis, Wardens get +2 str+con, etc. Equipment reads are now dynamic in `_effective_attack` / `_effective_armor` (equip changes mid-combat take effect). 3 new consumables: `mana_potion` (restore 25 MP), `cooked_meat` (heal 15 + +1 attack for 3 turns), `antidote` (heal 10 + status-cure placeholder).

**Key insight:** v0.5.0's `attack_bonus += em.get_attack - maxi(4, str/2+2)` math was buggy (double-subtracted the base). v0.6.0 stores base only on the unit, then adds equipment dynamically at damage time. Cleaner separation, more flexible, and matches the user's intent for per-class scaling.

### Immediate Next Step

Small v0.6.0 follow-ups (stamina_potion, status effects for antidote, crafting recipes for new items) OR v0.7.0 candidates from the PLAN's "Not yet done" list. Recommended: **v0.7.0 real procedural NPC spawn in settlements** — replace the 3 hard-coded test NPCs with biome-aware procedural generation. Builds on PartyNPCManager, which already has the template system.

### Relevant Handoffs

- [[v060-combat-damage-and-consumables]] — this handoff (v0.6.0 complete)
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1400.md` — full 9-section details
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1300.md` — v0.4.0 polish (4 fixes + bonus prod bug)
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_0530.md` — v0.5.0 final

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design
- `memory/CURRENT_STATE.md` — v0.6.0-complete state
- `docs/NEXT_TASKS.md` — v0.7.0 candidates

---

**Awaiting your decision: v0.6.0 follow-ups (small) or v0.7.0 procedural NPC spawn (medium)?**
