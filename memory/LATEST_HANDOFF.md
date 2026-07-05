---
name: v060-followup-cooking
description: v0.6.0 follow-up — cooking table station + raw_meat drops + 3 cooking recipes. 15 smoke_cooking tests green; full 16-script suite all pass.
---

## Current Focus: v0.6.0 follow-up (cooking table) COMPLETE

The user's brief — "if we have food we'll also need a cooking table, and associated recipes, raw meat drops from certain mobs, and the ability to cook it" — landed as 4 features: (1) raw_meat drops on 7 mobs (charnel_stalker, mycelial_behemoth, rift_elk, etc.), (2) 3 new cooking recipes (`cooked_meat` L1, `mana_potion` L5, `antidote` L3), (3) a CookingTable node + scene in a new generic `StationLayer`, and (4) the E-key interaction that opens the CookingTableUI modal. The `StationLayer` is generic so future stations (Worktable, ArmorTable, Blacksmith from Phase 3) can reuse it.

**Key design choice:** `LootRoller.roll` and `CraftingManager.craft` were already station-aware from previous phases, so the loot-drop data change was a JSON-only edit and the recipes slotted in via the existing `station: "cooking_table"` filter — no production code change for those subsystems.

### Immediate Next Step

Two small polish items remain: (1) wire `LocalMapGenerator` to emit `cooking_tables` in `map_data` so a cooking table auto-spawns in the start hex (~30 min), and (2) generate a real `cooking_table.png` sprite (~1 hour PIL). After that, v0.7.0 candidates (procedural NPC spawn, settlement interiors, settlement-to-Riftspire travel, button asset set).

### Relevant Handoffs

- [[v060-followup-cooking]] — this handoff (cooking table complete)
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1500.md` — full 9-section details
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1400.md` — v0.6.0 combat damage + consumables
- `memory/SESSION_NOTES/HANDOFF_2026-07-05_1300.md` — v0.4.0 polish

### Context Files

- `docs/PLAN_v040_crafting_progression.md` — canonical design
- `memory/CURRENT_STATE.md` — v0.6.0 + cooking complete
- `docs/NEXT_TASKS.md` — P0 done; P1 = local-map wiring + sprite gen

---

**Awaiting your decision: P1 polish (local-map wiring + sprite), or v0.7.0 candidate?**
