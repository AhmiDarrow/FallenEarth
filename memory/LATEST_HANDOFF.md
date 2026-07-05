---
name: v090-milestone-complete
description: v0.9.0 "Settlement Life & Combat Polish" milestone COMPLETE — All 6 phases (A-F) implemented and tested.
---

## Current Focus: v0.9.0 COMPLETE — Ready for v0.10.0 or new milestone

### Session Summary

Completed v0.9.0 "Settlement Life & Combat Polish" milestone by implementing all 6 phases:

**Phase A: NPC Dialogue System**
- Created `data/dialogue.json` — 11 dialogue trees with conditions, responses, rewards
- Created `scripts/DialogueManager.gd` — Autoload singleton for dialogue state
- Created `scripts/DialogueUI.gd` + `scenes/DialogueUI.tscn` — Full dialogue UI with portrait, text, responses
- Modified `SettlementInterior.gd` — E-key triggers dialogue

**Phase B: Settlement Ambient Behavior**
- Created `scripts/NPCWanderer.gd` — State machine (IDLE→WANDER→RETURN) for NPC movement
- Modified `scripts/RoomView.gd` — Interpolation, mood emojis, proximity detection
- Modified `scripts/SettlementInterior.gd` — Wanderer tick loop, NPC spawning

**Phase C: Quest Tracker UI**
- Created `scripts/QuestTracker.gd` — Autoload singleton for active missions
- Created `scripts/QuestTrackerUI.gd` + `scenes/QuestTrackerUI.tscn` — Collapsible panel, Tab toggle

**Phase D: Combat Feedback**
- Created `scripts/FloatingDamage.gd` — Animated damage numbers (red=physical, blue=magic, green=heal)
- Created `scripts/CombatHPBar.gd` — HP bar above tactical units
- Created `scripts/CombatFeedback.gd` — Parent node spawning effects, kill counter

**Phase E: Quality of Life**
- Created `scripts/ui/MinimapOverhaul.gd` — Icon-based minimap (NPC=blue, building=brown, rift=red, resource=green)
- Modified `scripts/InventoryUI.gd` — Sort button, Loot All button
- Created `scripts/ui/OptionsMenu.gd` + `scenes/ui/OptionsMenu.tscn` — Volume sliders, fullscreen, resolution
- Modified `scripts/HubWorld.gd` — Tab/Escape key wiring

**Phase F: Polish Pass**
- Created `scripts/TransitionScreen.gd` + `scenes/TransitionScreen.tscn` — Fade in/out overlay
- Created `scripts/LoadingTips.gd` + `data/tips.json` — 18 random gameplay tips
- Created `scripts/AmbientAudio.gd` — Biome-specific ambient loops (6 biomes)
- Created `scripts/MusicManager.gd` — Track-based music with crossfade (5 themes)
- Modified `scripts/HubWorld.gd` — Transitions wired to settlement/rift/world map

### v0.9.0 Final Status

| Phase | Name | Status |
|-------|------|--------|
| A | NPC Dialogue System | ✅ |
| B | Settlement Ambient Behavior | ✅ |
| C | Quest Tracker UI | ✅ |
| D | Combat Feedback | ✅ |
| E | Quality of Life | ✅ |
| F | Polish Pass | ✅ |

### New Files (Phase F)
- `scripts/TransitionScreen.gd` + `scenes/TransitionScreen.tscn` — Fade overlay
- `scripts/LoadingTips.gd` + `data/tips.json` — 18 gameplay tips
- `scripts/AmbientAudio.gd` — Biome ambient audio
- `scripts/MusicManager.gd` — Music crossfade system
- `tools/smoke_polish.gd` — 7 test groups

### Modified Files (Phase F)
- `scripts/HubWorld.gd` — Transition screen integration, fade effects on scene changes
- `project.godot` — Added LoadingTips, AmbientAudio, MusicManager autoloads
- `validate_scripts.gd` — Added new scripts/scenes

### Verification

```bash
# Polish smoke test (7 groups)
& godot --headless --path . -s tools/smoke_polish.gd
# → All checks passed.

# Full v0.9.0 suite
& godot --headless --path . -s tools/smoke_dialogue.gd
& godot --headless --path . -s tools/smoke_ambient.gd
& godot --headless --path . -s tools/smoke_quest_tracker.gd
& godot --headless --path . -s tools/smoke_combat_feedback.gd
& godot --headless --path . -s tools/smoke_qol.gd
& godot --headless --path . -s tools/smoke_polish.gd

# Regression checks
& godot --headless --path . -s validate_scripts.gd
```

### Notes for Next Milestone

- Audio files need to be added to `res://audio/ambient/` and `res://audio/music/` for AmbientAudio and MusicManager to play actual sounds
- TransitionScreen fade duration can be tuned per transition type
- LoadingTips can be expanded with more tips as new features are added
