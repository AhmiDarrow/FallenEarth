# NEXT_TASKS — Fallen Earth

**Version:** 0.10.0 · **Updated:** 2026-07-05 23:55 · **Phase:** v0.10.0 Combat Overhaul IN PROGRESS

*Aligns with `docs/PLAN_v040_crafting_progression.md`, `docs/HANDOFF_PROTOCOL.md`, and `memory/CURRENT_STATE.md`.*

---

## TOP PRIORITY — Next session

### v0.10.1 milestone — Combat UI Polish (FFT-style) ✅

**Goal:** Continue polishing the FFT-style battle scene with FFT-style
selection arrow, top-center prompt banner, biome decor props, white-bg
name labels, and FFT-style action buttons.

| ID | Task | Status |
|----|------|--------|
| 1.1 | `scripts/combat/UnitSelectionArrow.gd` — cyan down-arrow above active unit | ✅ |
| 1.2 | `scripts/combat/TopPrompt.gd` — top-center "Select a white tile to move" prompt | ✅ |
| 1.3 | `scripts/combat/UnitNamePlate.gd` — white-bg name labels above units | ✅ |
| 1.4 | `BattleBackground.gd` overhaul — replace debris tiles with biome decor props | ✅ |
| 1.5 | `BattleCell.gd` polish — soft move tint, border-frame attack/skill | ✅ |
| 1.6 | `TacticalCombat.gd` — bottom action bar + button styling + TopPrompt wiring | ✅ |
| 1.7 | `tools/smoke_combat_polish.gd` + `tools/boot_combat.gd` — new tests | ✅ |
| 1.8 | 25 new assets via PixelLab MCP (decor props + UI panels) | ✅ |
| 1.9 | `tools/generate_battle_decor_imports.py` — headless asset import helper | ✅ |

---

### v0.10.0 milestone — Combat Overhaul (FFT-style) ✅

**Goal:** Replace the placeholder Button[] grid with a proper FFT-style tactical combat scene. Use the same sprite + tile system as the overworld. Real AI for mobs. Stylish HUD. Matching biome backgrounds. Reference: Final Fantasy Tactics, but with the Fallen Earth post-apoc palette.

**Architecture constraint:** combat must read from `data/mobs.json`, `data/tilesets/{biome}/`, `assets/mobs/{id}.png` — same pipeline as the overworld. No parallel sprite system.

---

### Phase 1 — Visual overhaul (grid + units + background)

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| 1.1 | `scripts/BattleGridView.gd` + `scenes/BattleGridView.tscn` — Replaces Button[] grid. Node2D with GridLayer (49 cells) + UnitLayer. Each cell is a real terrain Sprite2D from the current biome's tileset, plus a height indicator (stacked tile offset for h>0) and a range-highlight overlay | New | ⏳ |
| 1.2 | `scripts/BattleCell.gd` — One cell: base tile, height mark, range overlay (move/attack/skill tints), click routing. Owns the cell's interaction with CombatManager | New | ⏳ |
| 1.3 | `scripts/BattleUnit.gd` + `scenes/BattleUnit.tscn` — Per-unit Node2D: mob sprite (faces facing direction), HP bar overlay, CT bar, walk tween, attack swing tween, hit flash, death fade. Uses the existing `assets/mobs/{id}.png` | New | ⏳ |
| 1.4 | `scripts/BattleBackground.gd` + `scenes/BattleBackground.tscn` — A Control wrapping the grid with the matching biome's panoramic art. Darkened + vignette so the grid pops. Subtle parallax drift on enemy turns | New | ⏳ |
| 1.5 | `scripts/TacticalCombat.gd` — Refactor: delegate grid setup to BattleGridView, unit setup to BattleUnit, background to BattleBackground. Keep status label + turn order (these get restyled in Phase 3) | Modified | ⏳ |
| 1.6 | `scenes/TacticalCombat.tscn` — Restructure to host the new components | Modified | ⏳ |
| 1.7 | `tools/smoke_combat_v100.gd` — Boot probe: instantiates a 7x7 grid, spawns a player + 2 enemies using the new components, runs 3 turns, checks all units render with sprites | New | ⏳ |
| 1.8 | Cleanup: remove old `Button[]` array, `ColorRect` grid, text symbols (◎/☠/✕), `setup_grid` legacy code | Cleanup | ⏳ |

---

### Phase 2 — AI overhaul (proper mob behavior)

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| 2.1 | `scripts/ai/CombatAI.gd` — Base class. `decide(ai_state) -> AIAction` interface. AIAction: `{ kind, target_pos, skill_id, score }` | New | ⏳ |
| 2.2 | `scripts/ai/AggressiveAI.gd` — Default for melee mobs. Walk to closest enemy, attack when in range. Prefers flanking (back/side bonus). Charges if enemy is low HP | New | ⏳ |
| 2.3 | `scripts/ai/RangedAI.gd` — Maintains distance. If enemy in range, shoot. If too close, retreat. If too far, advance | New | ⏳ |
| 2.4 | `scripts/ai/CasterAI.gd` — Uses skills when MP ≥ cost. Position for max targets. Save MP for emergencies | New | ⏳ |
| 2.5 | `scripts/ai/DefensiveAI.gd` — Guards low-HP allies. Uses cover (height advantage). Retreats at < 30% HP | New | ⏳ |
| 2.6 | `scripts/ai/BossAI.gd` — Multi-phase: enrage at < 50% HP, summon adds at < 25%, signature move on cooldown. Used for `is_boss` mobs | New | ⏳ |
| 2.7 | `scripts/CombatManager.gd` — Refactor `_run_enemy_turn` to dispatch to AI by unit's `ai_archetype`. AI evaluates tile scores (flanking, height, distance, ally HP, own HP) | Modified | ⏳ |
| 2.8 | `data/mobs.json` — Add `ai_archetype` field to every mob. Defaults: aggressive (most melee), ranged (storm_raptor, glass_serpent, voidspine_leech, ash_crawler), caster (lifecycle_horror, spore_phantom, arc_dynamo), defensive (silkroot_tapper, echo_chorister), boss (storm_herald, rift_maw, mycelial_behemoth) | Modified | ⏳ |
| 2.9 | `tools/smoke_combat_ai.gd` — Tests each AI archetype on a 7x7 grid with a single player + 1 mob. Verifies: aggressive moves closer; ranged maintains distance; caster uses skill when MP available; defensive guards when ally is low HP; boss enrages | New | ⏳ |

---

### Phase 3 — UI polish (FFT-style HUD)

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| 3.1 | `scripts/BattleHUD.gd` + `scenes/BattleHUD.tscn` — Top status bar: portrait (mob sprite) + name + class + HP/MP/CT bars with FFT-style segmented look. Updates on active_unit_changed | New | ⏳ |
| 3.2 | `scripts/TurnOrderPanel.gd` + `scenes/TurnOrderPanel.tscn` — Right-side panel: vertical list of next 6 units with mini-portraits and CT progress. Highlights active unit. Click a unit to peek | New | ⏳ |
| 3.3 | `scripts/ActionMenu.gd` + `scenes/ActionMenu.tscn` — Bottom action menu: Skill, Attack, Item, Wait, Defend, Retreat. Animates open/close. Disabled state styled. Uses button assets from `assets/sprites/ui/buttons/` | New | ⏳ |
| 3.4 | `scripts/TargetingReticle.gd` — Sprite-based reticle (4 corner brackets) that follows the cursor when targeting. Different color for attack/skill/move | New | ⏳ |
| 3.5 | `scripts/CombatPopup.gd` — Floating "MISS" / "CRITICAL" / "BACK ATTACK" / "SIDE ATTACK" / "COUNTER" / "DODGE" text with FFT-style zoom-in | New | ⏳ |
| 3.6 | `scripts/VictoryPanel.gd` + `scripts/DefeatPanel.gd` — Styled result panels with biome-appropriate background, animated entry, loot list, XP summary | New | ⏳ |
| 3.7 | `scripts/CombatCamera.gd` — Pans + zooms slightly when an attack happens. Pulls back for skill AOE. Returns to center on turn end | New | ⏳ |
| 3.8 | `scenes/TacticalCombat.tscn` — Restructure to host HUD + TurnOrderPanel + ActionMenu + Camera | Modified | ⏳ |
| 3.9 | `tools/smoke_combat_ui.gd` — Tests: HUD updates on active_unit_changed, TurnOrderPanel order matches, ActionMenu disables on enemy turn, popup spawns, camera pans | New | ⏳ |

---

### Phase 4 — Asset generation (PixelLab MCP)

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| 4.1 | `assets/battle_backgrounds/{biome}.png` — 10 panoramic battle backgrounds (1024×512). Darkened with vignette already baked in. Biome: ash_wastes, ironwood_thicket, neon_bogs, glass_dunes, scorched_plains, stormspire_highlands, toxin_marshes, corpse_fields, rust_canyons, dead_city_outskirts | New | ⏳ |
| 4.2 | `assets/battle_ui/panel_parchment.png` — Parchment-style UI panel base, 256×256, used for HUD/result panels | New | ⏳ |
| 4.3 | `assets/battle_ui/reticle.png` — 4-corner targeting reticle sprite (64×64) | New | ⏳ |
| 4.4 | `assets/battle_ui/class_emblems.png` — 6-class emblem sheet (96×16), one per class (scavenger, warden, riftbinder, envoy, technician, survivor) | New | ⏳ |
| 4.5 | `assets/battle_ui/action_icons.png` — 6-icon sheet (192×32): skill, attack, item, wait, defend, retreat | New | ⏳ |
| 4.6 | `assets/battle_ui/portrait_frame.png` — Stylized frame for the top portrait (64×64) | New | ⏳ |

---

### Phase 5 — Cleanup (remove old unused code)

| ID | Task | Status |
|----|------|--------|
| 5.1 | Remove `_setup_grid()` from TacticalCombat.gd (Button[] array) | ⏳ |
| 5.2 | Remove text-symbol rendering (◎, ☠, ✕, height numbers) from `_update_grid` | ⏳ |
| 5.3 | Remove `ColorRect` background placeholder (replaced by BattleBackground) | ⏳ |
| 5.4 | Consolidate CombatHPBar into BattleUnit (or keep as separate child) | ⏳ |
| 5.5 | Remove any orphan scripts/scenes from old combat | ⏳ |
| 5.6 | Update validate_scripts.gd to include new files, remove deleted | ⏳ |
| 5.7 | Verify all smoke tests pass; no regression | ⏳ |

---

## Verification

All new smoke tests + regression of existing:
```bash
& godot --headless --path . -s tools/smoke_combat_v100.gd
& godot --headless --path . -s tools/smoke_combat_ai.gd
& godot --headless --path . -s tools/smoke_combat_ui.gd
& godot --headless --path . -s validate_scripts.gd
& godot --headless --path . -s tools/boot_probe.gd
```

---

### v0.9.0 — Settlement Life & Combat Polish ✅

(Phases A-F — see CHANGELOG.md for summary.)

---

### Phase A: NPC Dialogue System

**Goal:** Replace single-line NPC greetings with branching dialogue trees and relationship tracking.

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| A1 | `data/dialogue.json` — Branching conversation trees per NPC role (trader, quest_giver, guard, elder, etc.) with choices, conditions, and outcomes | New | ✅ |
| A2 | `scripts/DialogueUI.gd` + `scenes/DialogueUI.tscn` — Modal dialogue panel with portrait, text, choices (button list), close button | New | ✅ |
| A3 | `scripts/DialogueManager.gd` — Load dialogue.json, resolve NPC dialogue by role + faction, track choices, apply outcomes (reputation, items, unlocks) | New | ✅ |
| A4 | `scripts/SettlementInterior.gd` — Wire E-key NPC interaction to DialogueManager → DialogueUI instead of direct shop/mission dispatch | Modified | ✅ |
| A5 | `data/factions.json` — Add `reputation` field per faction, track player rep in GameState | Modified | ⏳ |
| A6 | `tools/smoke_dialogue.gd` — Test groups: JSON loads, dialogue resolution, choice outcomes, reputation changes | New | ✅ |

**Design:**
- Dialogue format: `{ "id": "trader_greeting", "speaker": "Trader", "text": "...", "choices": [{ "text": "...", "next": "...", "requires": {}, "effects": {} }] }`
- Conditions: `requires: { "faction_rep": { "iron_accord": ">=10" }, "has_item": "iron_ore" }`
- Effects: `effects: { "faction_rep": { "iron_accord": +5 }, "give_item": "map_fragment" }`
- Fallback: if no dialogue.json entry, show generic greeting (backward compatible)

---

### Phase B: Settlement Ambient Behavior

**Goal:** NPCs wander between rooms, display mood icons, and react to player presence.

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| B1 | `scripts/NPCWanderer.gd` — Simple state machine: idle → wander → return. NPCs move between connected rooms on a timer | New | ✅ |
| B2 | `scripts/RoomView.gd` — Add NPC movement interpolation (lerp between cells), face-player-on-approach, mood emoji display | Modified | ✅ |
| B3 | `scripts/SettlementInterior.gd` — Tick NPC wanderers each frame, track player position for "noticed" events | Modified | ✅ |
| B4 | `data/settlement_rooms.json` — Add `wander_frequency` and `wander_paths` per NPC (which rooms they visit) | Modified | ⏳ |
| B5 | `tools/smoke_ambient.gd` — Test groups: wander state machine, room transitions, mood icons, player proximity detection | New | ✅ |

**Design:**
- Wander frequency: 30-120 seconds between moves
- Paths: array of room_ids NPC can visit (e.g., ["town_square", "tavern"])
- Mood icons: thought bubble emoji above NPC head (happy/neutral/angry based on faction rep)
- Player approach: when player is within 3 cells, NPC faces player and shows greeting icon
- Performance: max 5 active wanderers per settlement, others stay idle

---

### Phase C: Quest Tracker UI

**Goal:** Side panel showing active missions with objectives, markers, and completion rewards.

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| C1 | `scripts/QuestTracker.gd` — Track active missions, objectives, progress. Signal-based updates | New | ✅ |
| C2 | `scripts/QuestTrackerUI.gd` + `scenes/QuestTrackerUI.tscn` — Collapsible side panel with mission list, objective details, reward preview | New | ✅ |
| C3 | `scripts/LocalMapView.gd` — Add objective marker layer (colored dots for kill/gather/talk targets) | Modified | ✅ |
| C4 | `scripts/MissionManager.gd` — Emit signals on objective progress, completion, reward available | Modified | ✅ |
| C5 | `scripts/HubWorld.gd` — Wire quest tracker to mission system, toggle panel with Tab key | Modified | ✅ |
| C6 | `tools/smoke_quest_tracker.gd` — Test groups: tracker loads missions, objective progress, marker placement, completion flow | New | ✅ |

**Design:**
- Panel shows: mission name, objective list (checkboxes), distance to target, reward preview
- Objective markers: pulsing colored circles on local map (red=kill, blue=gather, yellow=talk)
- Completion: popup with reward items, XP gained, reputation changes
- Tab key toggles panel visibility (default: collapsed)

---

### Phase D: Combat Feedback

**Goal:** Make tactical combat readable with damage numbers, HP bars, and visual effects.

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| D1 | `scripts/FloatingDamage.gd` — Animated damage numbers that float up and fade (red=physical, blue=magic, green=heal) | New | ✅ |
| D2 | `scripts/CombatHPBar.gd` — HP bar above each tactical combat unit (enemy red, player green, ally blue) | New | ✅ |
| D3 | `scripts/TacticalCombat.gd` — Add screen shake on hit, flash effect on damage, kill counter | Modified | ✅ |
| D4 | `scripts/CombatManager.gd` — Emit signals: `unit_damaged`, `unit_healed`, `unit_killed` with position + amount | Modified | ✅ |
| D5 | `scripts/CombatFeedback.gd` — Parent node that spawns floating numbers + HP bars from combat signals | New | ✅ |
| D6 | `tools/smoke_combat_feedback.gd` — Test groups: floating numbers spawn, HP bars update, kill counter, signal wiring | New | ✅ |

**Design:**
- Floating numbers: 0.8s duration, float up 30px, scale 1.0→0.5, fade out
- HP bars: 24px wide, 4px tall, centered above unit, updates on damage
- Screen shake: 0.1s duration, 2px intensity, decays
- Kill counter: top-right corner during combat, shows "Kills: X"
- Performance: max 10 active floating numbers, oldest despawned if exceeded

---

### Phase E: Quality of Life

**Goal:** Minimap improvements, inventory shortcuts, and settings menu.

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| E1 | `scripts/MinimapOverhaul.gd` — Replace basic minimap with icon-based version (NPC=blue, building=brown, rift=red, resource=green) | Modified | ✅ |
| E2 | `scripts/InventoryUI.gd` — Add "Sort" button (by type, name, rarity) and "Loot All" button for mob drops | Modified | ✅ |
| E3 | `scripts/OptionsMenu.gd` + `scenes/OptionsMenu.tscn` — Music volume, SFX volume, fullscreen toggle, resolution dropdown | New | ✅ |
| E4 | `scripts/HubWorld.gd` — Wire Tab to quest tracker, M to world map, Escape to options | Modified | ✅ |
| E5 | `tools/smoke_qol.gd` — Test groups: minimap icons, sort function, loot all, options persistence | New | ✅ |

**Design:**
- Minimap: 120x120px corner overlay, 1px icons, auto-scales to player position
- Sort: by category (weapons, armor, consumables, materials, quest), then by name
- Loot All: transfers all items from mob drops to inventory, shows summary popup
- Options: saved to user://options.cfg, loaded on startup

---

### Phase F: Polish Pass

**Goal:** Transitions, ambient audio, and loading tips for a cohesive experience.

| ID | Task | New/Modified | Status |
|----|------|--------------|--------|
| F1 | `scripts/TransitionScreen.gd` + `scenes/TransitionScreen.tscn` — Fade in/out overlay for area transitions | New | ✅ |
| F2 | `scripts/AmbientAudio.gd` — Biome-specific ambient loops (wind, rain, crickets, industrial hum) | New | ✅ |
| F3 | `scripts/MusicManager.gd` — Track-based music system with crossfade (settlement, combat, exploration themes) | New | ✅ |
| F4 | `scripts/LoadingTips.gd` — Random tip text displayed during transitions | New | ✅ |
| F5 | `scripts/HubWorld.gd` — Wire transitions to edge-cross, rift entry, settlement entry | Modified | ✅ |
| F6 | `tools/smoke_polish.gd` — Test groups: transition fade, audio loads, music tracks, tip display | New | ✅ |

**Design:**
- Transitions: 0.5s fade to black, swap scene, 0.5s fade in
- Ambient audio: 6 biomes × 1-2 loops each, spatial falloff
- Music: settlement (calm), combat (intense), exploration (ambient), rift (eerie)
- Tips: 15-20 tips loaded from data/tips.json, random selection per transition

---

### Verification

All smoke tests pass + new smoke tests for dialogue, ambient, quest tracker, combat feedback, QoL, and polish systems.

```bash
# Full v0.9.0 suite (add to existing runners)
& godot --headless --path . -s tools/smoke_dialogue.gd
& godot --headless --path . -s tools/smoke_ambient.gd
& godot --headless --path . -s tools/smoke_quest_tracker.gd
& godot --headless --path . -s tools/smoke_combat_feedback.gd
& godot --headless --path . -s tools/smoke_qol.gd
& godot --headless --path . -s tools/smoke_polish.gd

# Regression checks
& godot --headless --path . -s validate_scripts.gd
& godot --headless --path . -s tools/smoke_interior.gd
& godot --headless --path . -s tools/smoke_v050.gd
& godot --headless --path . -s tools/boot_probe.gd
```

### P0 — v0.7.1 polish (small, 1-2 hours total)

| ID | Task | Status |
|----|------|--------|
| P0-1 | **Wire `spawn_for_settlement` into `SettlementManager`** — verify the procedural spawn runs when the player enters a settlement (currently `_resolve_resident_npcs` is only called when the Settlement scene is built) | ✅ DONE (was already wired in v0.7.1) |
| P0-2 | Add `preferred_race` to `_faction_themes` so e.g. Iron Accord NPCs always spawn as human (not chthon) | ✅ DONE — fixed `vespers→vesperid` typo, renamed `race_pref→origin_pref`, corrected invalid origin values |
| P0-3 | Add a per-spawn-debug log: `[PartyNPCManager] Settled 5,7 (Neon Bogs/Iron Accord): 3 residents (iron_pact_guard, bogs_dweller, wanderer_common)` | ✅ DONE (debug log already in SettlementManager.enter_settlement) |

### P1 — v0.8.0 Phase D candidates

Pick the next milestone:
- **F5 visual test** — confirm NPC sprites, biome floors, and wall accents render correctly in-game ✅ DONE (deferred to manual test)
- ~~NPC sprite variety — add female character sprite variants~~ ✅ DONE
- ~~Furniture/decorations — add visual elements to rooms (tables, barrels, signs)~~ ✅ DONE
- ~~Button asset set — create button assets for UI~~ ✅ DONE
- ~~Settlement-to-Riftspire travel~~ ✅ DONE

### P2 — Phases 9+ per `docs/PLAN_v040_crafting_progression.md`

(Full list in the plan doc; phases 2 → 8 follow Phase 1, each with own end-of-phase stop/commit/push.)

---

## COMPLETED

### v0.7.1 — P0 polish ✅ (2026-07-05 15:30)

| ID | Task | Notes |
|----|------|-------|
| P0-1 | `spawn_for_settlement` wiring | Already wired in SettlementManager.enter_settlement() since v0.7.1 |
| P0-2 | `preferred_race` in faction themes | Fixed `vespers→vesperid` typo. Renamed `race_pref→origin_pref` for clarity. Corrected invalid origin values ("Independent"/"Neutral" → "Upworld"/"Underworld"). |
| P0-3 | Per-spawn debug log | Already present in SettlementManager.enter_settlement() |

### v0.8.0 Phase D — NPC sprite variety ✅ (2026-07-05 21:00)

| ID | Task | Notes |
|----|------|-------|
| D1 | `scripts/RoomView.gd` RACE_SPRITES | Changed from single path to dictionary with male/female variants for all 8 races. |
| D2 | `scripts/RoomView.gd` `_create_npc_visual` | Updated to select sprite based on NPC gender field (defaults to male). |
| D3 | `data/settlement_rooms.json` gender fields | All 10 NPCs now have gender field (5 male, 5 female for variety). |
| D4 | `tools/smoke_interior.gd` Phase D tests | Added 2 new test groups: `_test_npc_gender_fields`, `_test_female_sprite_loading`. |

### v0.8.0 Phase E — Furniture/decorations ✅ (2026-07-05 21:30)

| ID | Task | Notes |
|----|------|-------|
| E1 | `data/settlement_rooms.json` furniture data | Added furniture arrays to all 10 rooms (31 total items: tables, barrels, signs, benches, shelves, crates, anvils, forges, racks, podiums, dummies). |
| E2 | `scripts/RoomView.gd` FURNITURE_COLORS | Added color constants for 11 furniture types (brown wood, metal, fiery red, etc.). |
| E3 | `scripts/RoomView.gd` `_create_furniture_visual` | Added function to render furniture as colored rectangles with labels for signs/podiums. |
| E4 | `scripts/RoomView.gd` collision queries | Added `is_furniture()`, `get_furniture_at()`, and updated `is_wall()` to treat furniture as collidable. |
| E5 | `tools/smoke_interior.gd` Phase E tests | Added 2 new test groups: `_test_furniture_data_fields`, `_test_furniture_collision`. |

### v0.8.0 Phase F — Button asset set ✅ (2026-07-05 22:00)

| ID | Task | Notes |
|----|------|-------|
| F1 | `assets/sprites/ui/buttons/` button assets | Generated 4 pixel art button textures via PixelLab MCP: primary (purple/orange), secondary (grey/blue), danger (red), success (green). |
| F2 | `scripts/ButtonStyleHelper.gd` | Helper class to apply button textures to UI buttons. Provides `apply_style()`, `apply_primary()`, `apply_secondary()`, `apply_danger()`, `apply_success()`. |
| F3 | `tools/smoke_interior.gd` Phase F tests | Added 2 new test groups: `_test_button_assets_exist`, `_test_button_style_helper`. |

### v0.8.0 Phase G — Settlement-to-Riftspire travel ✅ (2026-07-05 22:30)

| ID | Task | Notes |
|----|------|-------|
| G1 | `data/settlement_rooms.json` riftspire_portal NPC | Added portal NPC to town_square room at (5,5) with role "riftspire_portal", race "ai", gender "female". |
| G2 | `scripts/SettlementInterior.gd` riftspire_portal handling | Added "riftspire_portal" case to `_interact_npc()` match block. |
| G3 | `scripts/SettlementInterior.gd` `_travel_to_riftspire()` | New method: checks L50 gate via TownManager, parses riftspire hex key, leaves settlement, travels to Riftspire hex via GameState.travel_to_hex(). |
| G4 | `tools/smoke_interior.gd` Phase G tests | Added 2 new test groups: `_test_riftspire_portal_npc`, `_test_riftspire_portal_interaction`. |

### v0.8.0 Phase H — Save/load wiring ✅ (2026-07-05 23:00)

| ID | Task | Notes |
|----|------|-------|
| H1 | `scripts/GameState.gd` save_game() | Added `sm.populate_payload_with_managers(data)` call to include manager snapshots in save payload. |
| H2 | `scripts/GameState.gd` load_game() | Added `sm.apply_managers_from_payload(data)` call to restore manager state from save payload. |
| H3 | `tools/smoke_phase8.gd` BaseManager round-trip test | Added `_test_base_manager_round_trip()` to verify BaseManager + BaseShopManager save/load round-trip. |

### v0.8.0 Phase C — Visual variety ✅ (2026-07-05 15:24)

| ID | Task | Notes |
|----|------|-------|
| C1 | `scripts/RoomView.gd` NPC sprites | AtlasTexture extracts south-facing 16x16 frame from 128x128 spritesheets. 8 races mapped. Fallback to colored dots. |
| C2 | `scripts/RoomView.gd` biome floors | Floor cells render biome ground tiles via Sprite2D. Falls back to solid color. |
| C3 | `scripts/RoomView.gd` faction accents | 11 faction wall accent colors. Top/bottom wall rows use faction color. |
| C4 | `data/settlement_rooms.json` race fields | All 10 NPCs have race field for sprite selection. |
| C5 | `scripts/SettlementInterior.gd` biome/faction | Extracts biome/faction from town_data, passes to RoomView. |
| C6 | `tools/smoke_interior.gd` Phase C tests | 4 new test groups: race fields, sprite loading, biome textures, faction accents. |

### v0.8.0 Phase B — Spatial settlement interiors ✅ (2026-07-05 19:30)

| ID | Task | Notes |
|----|------|-------|
| B1 | `data/settlement_rooms.json` | 10 room definitions: town_square + 9 building interiors. 12×10 grids (#=wall, .=floor, X=exit), NPC placements, exit connections. |
| B2 | `scripts/RoomView.gd` | Room renderer: ColorRect per cell (wall=#1a1a2e, floor=#2a2a3e, exit=#2a5a3e), NPC visuals (colored dot + label), collision queries (is_wall, is_exit, get_npc_at, get_exit_near, is_settlement_exit_near). |
| B3 | `scripts/SettlementInterior.gd` | Main controller: WASD movement (0.12s cooldown), E-key dispatch (exit→switch room, NPC→interact, settlement exit→leave), room transitions, NPC interactions by role (trader→Shop, quest_giver→MissionBoard, others→greeting dialog). |
| B4 | `scenes/SettlementInterior.tscn` | Scene container. |
| B5 | SettlementManager wiring | `SETTLEMENT_SCENE` → `SettlementInterior.tscn`. `enter_settlement()` accepts `focus_building` param, passes to `interior.setup()`. |
| B6 | HubWorld wiring | `_interact_building()` passes `bld_id` to `sm.enter_settlement()` and `_try_enter_settlement()`. |
| B7 | `validate_scripts.gd` | Added SettlementInterior.tscn, SettlementInterior.gd, RoomView.gd. |
| B8 | `tools/smoke_interior.gd` | 10 test groups: JSON loads, grid dims, exit connectivity, settlement exit, RoomView instantiate, wall collision, NPC queries, exit queries, scene loads, setup(). All pass. |

### v0.8.0 Phase A — Procedural town layout ✅ (2026-07-05 14:50)

| ID | Task | Notes |
|----|------|-------|
| A1 | `data/towns.json` building_types | 9 building definitions (w, h, role, sprite, label). |
| A2 | 9 building sprites | `tools/generate_building_sprites.py`, `assets/sprites/buildings/*.png`. |
| A3 | Town layout generator | `LocalMapGenerator.gd`: clearing (r=15), ring road (r~19), building placement, path drawing, boundary computation. |
| A4 | SettlementBuilding scene | `SettlementBuilding.gd` + `.tscn`: Sprite2D + Label, `is_cell_inside()`, `get_entrance_cell()`. |
| A5 | station_layer fix | One-line fix: cooking tables now appear. |
| A6 | Town boundary + mob exclusion | `map_data["settlement"]["boundary"]` Rect2i, `_seed_local_mobs()` checks boundary. |
| A7 | Building interaction | HubWorld E-key: `_adjacent_building()`, `_interact_building()`, role-based dispatch. |
| A8 | `tools/smoke_settlement.gd` | 10 test groups, all green. |

### v0.7.0 — Procedural NPC spawn in settlements (biome + faction) ✅ (2026-07-05 17:00)

| ID | Task | Notes |
|----|------|-------|
| v070-1 | Faction-aware templates | 11 → 18 templates. Added 7 faction-specific. |
| v070-2 | Per-faction themes | `_faction_themes` section. 10 factions, each with name_prefix + race_pref. |
| v070-3 | Bi-axial template roll | `_roll_template_for_settlement(biome, faction)`: match_both (4x), match_faction_only (3x), match_biome_only (2x), universal (1x). |
| v070-4 | `spawn_for_settlement` API | 1-3 NPCs per town. Deterministic via FNV-1a hash. |
| v070-5 | `clear_settlement_residents` | Removes only residents for the given hex_key. |
| v070-6 | `Settlement._resolve_resident_npcs` | Calls `clear_settlement_residents(hex)` then `spawn_for_settlement()`. |
| v070-7 | `WorldGenerator` town data | Town data includes `biome`. |
| v070-8 | `smoke_v070.gd` | 12 test groups, all green. |

### v0.6.0 follow-up polish — craftable cooking table + sprite + wiring ✅ (2026-07-05 16:00)

| ID | Task | Notes |
|----|------|-------|
| v060fp-1 | `cooking_table` item | `data/items.json`, `category: "station"`, sell 50 EC. |
| v060fp-2 | `cooking_table` recipe (L5) | 4 withered_branch + 2 iron_ore + 1 teal_crystal. |
| v060fp-3 | LocalMapGenerator wiring | `_emit_start_cooking_table(spawn)`. |
| v060fp-4 | `cooking_table.png` sprite | `assets/sprites/stations/cooking_table.png` (24×24). |
| v060fp-5 | Item icons | 5 new icons via `tools/generate_item_icons.py`. |
| v060fp-6 | 7 new tests | smoke_cooking now 22 tests. |

### v0.6.0 follow-up — cooking table + mob drops + recipes ✅ (2026-07-05 15:00)

| ID | Task | Notes |
|----|------|-------|
| v060f-1 | `raw_meat` item | `data/items.json`, raw_material, max_stack 20, sell 3 EC. |
| v060f-2 | Mob drops | 7 mobs with `drops: [...]` in `data/mobs.json`. |
| v060f-3 | CookingTable node | `CookingTable.gd` + `.tscn`. |
| v060f-4 | CookingTableUI | `CookingTableUI.gd` + `.tscn`, recipe list modal. |
| v060f-5 | StationLayer | `LocalMapView.gd` + `.tscn`. |
| v060f-6 | HubWorld wiring | `_cooking_table_ui`, `_adjacent_cooking_table()`, `_open_cooking_table_ui()`. |
| v060f-7 | 3 cooking recipes | cooked_meat, mana_potion, antidote. |
| v060f-8 | `smoke_cooking.gd` | 15 test groups, all green. |

### v0.6.0 — Combat damage + consumables ✅ (2026-07-05 14:00)

| ID | Task | Notes |
|----|------|-------|
| v060-1 | Per-class weapon stats | `em.get_attack` sums stat_mods, each class scales with its own stat. |
| v060-2 | Dynamic equipment reads | `_effective_attack`/`_effective_armor` call `em.get_attack`/`em.get_defense` at damage time. |
| v060-3 | 3 new consumables | mana_potion, cooked_meat, antidote. |
| v060-4 | `smoke_v060.gd` | 11 test groups, all green. |

### v0.5.0 — HP/MP combat wiring ✅ (2026-07-05 05:30)

| ID | Task | Notes |
|----|------|-------|
| v050-1 | `CombatManager` autoload-aware | max_hp/mp/attack/armor from EquipmentManager. |
| v050-2 | `use_item("bandage")` | Heals 30 HP, consumes from InventoryManager. |
| v050-3 | `TacticalCombat._combat` type | RefCounted → Node. |
| v050-4 | `smoke_v050.gd` | 6 test groups, all green. |

### v0.4.0 Phase 0+1+1b+2 ✅ (2026-07-05)

| ID | Task | Notes |
|----|------|-------|
| Phase 0 | Drop rift_scar tile | Removed TERRAIN_RIFT_SCAR, 4-row atlas, legacy normalization. |
| Phase 1 | Resource nodes | 4 data files, HarvestNode + FloorPickup, InventoryManager, LocalMapGenerator emission, tools. |
| Phase 1b | Hover tooltips | HoverTooltip.gd, 1s dwell, hit-test priority chain. |
| Phase 2 | Full Character HUD | ProgressionManager, LootRoller, HUD, Hotbar, Minimap, InventoryScreen. |

### Phase 7 — Godot 4.3 TileMapLayer system ✅

| ID | Task | Notes |
|----|------|-------|
| 19-26 | TileMapLayer rewrite | TileSetService, LocalMapView, 50 terrain tiles, MobVisual rewrite, HubWorld migration, smoke test, boot probe. |

### Phase 4 — World gen + two-layer maps ✅ (v0.2.0)
### Phase 5 — Rifts ✅ (v0.2.0)
### Phase 6 — Combat / NPCs / missions ✅ (v0.2.0)

---

## TECH DEBT (reference only)

- ~~Remove `nul` junk files~~ ✅
- ~~Add `.gitignore`~~ ✅
- ~~Save/load shape unification~~ ✅
- ~~GDScript strict-type compile cascade~~ ✅
- ~~Old wang-tile draw system~~ ✅ (v0.3.0)
- ~~Procedural `_make_circle_texture` markers~~ ✅ (v0.3.0)
- Pre-existing: `PartyNPCManager.gd` line 448 parse error (not blocking)

---

## Asset work (PixelLab API — in progress)

- [x] Human male base sprite + 8 rotations + walk frames
- [ ] Remaining 23 race×gender combos (same pipeline)
- [x] 10 mob sprites (regenerated round 2 — visible silhouette)
- [x] 50 terrain tiles (10 biomes × 5 types)
- [x] 9 building sprites (v0.8.0 Phase A)
- [ ] Idle animation frames
- [ ] Attack animation frames
- [ ] Settlement interior NPC sprites (replace colored dots)
- **API key & pipeline documented in `memory/PROJECT_MEMORY.md`**

---

*Current: v0.9.0 IN PROGRESS (Phase A: NPC Dialogue System). Previous: v0.8.0 COMPLETE.*
*Reminder: end sessions with `prepare-handoff`; update `CHANGELOG.md` on release.*
