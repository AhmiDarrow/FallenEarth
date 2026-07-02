# PROJECT_MEMORY — Fallen Earth Shared Facts & Conventions

## Environment & Preferences
- Engine: Godot 4.3 (GDScript primary)
- **Game version: 0.2.0** · Save format: 0.2.0 · See `docs/VERSION.md`
- Project root: C:\Users\Administrator\FallenEarth
- Data philosophy: JSON-first. All game entities (races, biomes, factions, mobs, classes) live in data/*.json and are loaded at runtime.
- Current state: Core data files exist. Manager scripts (GameState, WorldGenerator, RaceManager, etc.) are present as stubs or partial. UI scenes minimal (Splash, MainMenu).
- Multi-agent setup: Full automatic Remedy (Hermes) + handoff + dispatch system installed. See root AGENTS.md, REMEDY.md, CLAUDE.md.
- Models: Local (Ollama Qwen variants, including claude-code distilled) + possible Claude Code CLI. Remedy orchestrates.

## Godot / GDScript Conventions
- Use autoloads for singletons (GameState, Managers).
- Prefer data-driven over hard-coded: load JSON → parse into dictionaries or resources.
- Keep scripts focused: one manager per major system.
- Scenes for UI and levels; code for logic.
- Save format: JSON under user://saves/. Version it early.

## Coding Style (Remedy-enforced)
- Clean, modular, commented where non-obvious.
- Atomic tasks only for handoffs.
- Test data loading early (even simple print or validation).
- When editing Godot files, note scene changes and script paths in handoffs.

## Known Gotchas
- Godot autoload order matters for dependencies (e.g., GameState before others).
- JSON keys must match exactly in GDScript accessors.
- World generation can explode in scope — keep early milestones to deterministic simple grids or hex previews.
- Rift instances should be self-contained to avoid polluting main world state.

## User (Joe) Preferences
- Responses sarcastic/silly but maximally efficient.
- Strict handoff discipline (9 sections, update LATEST_HANDOFF).
- Data first, then systems, then polish.
- Use the automatic Remedy loop: high-level goal in → orchestrator drives.

## Active Systems & Files (as of bootstrap)
- data/: biomes.json, races.json, factions.json, mobs.json, character_classes.json, story_chapters.json, dynamic_threat.json
- scripts/: AppearanceManager.gd, ClassManager.gd, DisplayManager.gd, EquipmentManager.gd, GameState.gd, MobManager.gd, RaceManager.gd, RiftRunner.gd, SaveManager.gd, WorldGenerator.gd
- Existing planning: dev_plan.md (milestones), IDEA_SYNOPSIS.md (gameplay loop), lore.md

Update this file with any new conventions discovered during work (e.g., "Rift encounters always clear inventory temp state on exit").

## 2026-06-30 Fixes Applied
- CHANGELOG.md now used as consistent root changelog (in addition to handoffs/plans).
- All .tscn normalized to Godot 4 format before further scene work.
- Python helpers and core config validated post-fix.

## 2026-07-01 Two-Layer World Architecture
- **Planet layer:** `WorldGenerator` + `WorldMapScreen` — hex sphere, RimWorld-style site selection + strategic travel.
- **Local layer:** `LocalMapGenerator` + `HubWorld` + `LocalMapRenderer` — one 512×512 map per `(q,r)` hex.
- **Player position:** `GameState` stores sphere `(q,r)` AND local `(local_x, local_y)` within current hex.
- **Mob/rift keys:** `GameState.mob_key(q,r,lx,ly)` → `"q,r|lx,ly"` (not just hex key).
- **Hex persistence:** `GameState.hex_states` — visited, explored_pct, settlement stub; terrain regenerated from seed on load (not saved in JSON).
- **Edge travel:** Walk off local map cardinal edge → `travel_to_hex(neighbor, opposite_edge)` loads adjacent hex local map.
- **Navigation:** `GameManager.go_to_hub()` = local map; `go_to_world_map()` = strategic map. HubWorld: M key or 🗺 button.
- **Rifts:** Spawn at `local_x/local_y` within hex; return restores `entry_local_x/y` after dungeon.
- **Save extras:** `overworld_mobs`, `rift_state`, `hex_states`, `discovered_hexes` in save payload via SaveManager.
- **Assets:** Local map renders ColorRect terrain until hand-drawn overlay hooked in `LocalMapRenderer`.
