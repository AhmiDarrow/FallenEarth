# NEXT_TASKS — Fallen Earth (Prioritized Atomic)

Living list. Max ~5-7 visible. Remedy maintains this automatically. Pull from dev_plan.md and current handoff.

## Current Priorities (Seeded from dev_plan + existing files)

1. **Core Data Validation & Loading** (foundational)
   - Ensure all data/*.json load cleanly in Godot (schema checks or simple parser in a manager).
   - Add basic validation script (Python or GDScript) for races, biomes, factions, mobs.
   - Wire initial autoloads (GameState, at least one Manager) in project.godot.

2. **World Generation Scaffolding**
   - Implement basic biome tile mapping from biomes.json.
   - Create WorldGenerator.gd logic for simple overworld grid or hex preview (no full 3D yet).
   - Add seed handling and preview UI stub (extend existing scenes or new).

3. **Character Creation Flow** (high priority per plan)
   - Race selection + stats from races.json + RaceManager.gd.
   - Class selection from character_classes.json.
   - Basic appearance preview using AppearanceManager.
   - Simple character creation scene flow (menu → creation → save stub).

4. **Save/Load Foundation**
   - Implement basic JSON save to user:// for player data (appearance, stats, inventory stub).
   - Load flow from MainMenu → existing game state.
   - Integrate SaveManager.gd.

5. **Minimal Overworld + Rift Stub**
   - Basic player movement in a placeholder hub scene using data-driven biome info.
   - Trigger for entering a "rift" (simple scene change or instance stub).
   - Touch/aggro hook that leads to a tactical combat placeholder.

## Done / Archived
- Initial data JSONs populated (races, biomes, factions, mobs, classes, story).
- Basic manager script stubs and project structure.
- Multi-agent handoff + automatic Remedy system bootstrapped (2026-06-29).

## Guidance for Remedy
When decomposing, keep tasks atomic and reference specific files (e.g., "Extend WorldGenerator.gd to load biomes.json and generate a 32x32 tile array"). Always end with handoff + state update.
