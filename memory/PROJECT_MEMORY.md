# PROJECT_MEMORY — Fallen Earth Shared Facts & Conventions

## Environment & Preferences
- Engine: Godot 4.x (GDScript primary)
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
