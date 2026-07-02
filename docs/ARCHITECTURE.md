# ARCHITECTURE — Fallen Earth Godot Project + Multi-Agent Workflow

**Version:** 0.2.0 · **Save format:** 0.2.0 · See `docs/VERSION.md`

## Game Architecture
- **Godot 4 Project** with autoloads for global managers.
- **Data-driven core**: All content (races, biomes, factions, mobs, classes) defined in `data/*.json`. Scripts load and interpret at runtime.
- **Key Systems** (from existing scripts/):
  - GameState.gd, SaveManager.gd
  - WorldGenerator.gd (hexasphere) + biomes
  - RaceManager, ClassManager, AppearanceManager, EquipmentManager
  - MobManager, RiftRunner
  - DisplayManager
- **Scenes**: UI (Splash, MainMenu) + WorldGeneration (hex sphere + start tile picker) + CharacterSelection + HubWorld (512×512 local playfield per hex) + WorldMapScreen (strategic sphere map) + RiftInstance (instanced procedural dungeon).
- **Exact Game Flow**:
  1. New Game (MainMenu)
  2. World generation: Generate a hexagonal sphere world (hex tiles with spherical topology, biomes via noise/lat-lon).
  3. Player chooses starting grid/tile on the sphere.
  4. Character creation screen (race/class/appearance from data).
  5. Enter local overworld: 512×512 playfield for the chosen sphere hex. WASD exploration; walk off map edge to enter adjacent hex's local map.
  6. World Map (M key / button): RimWorld-style strategic view — faction settlements (★), quest markers (!), rift activity (⚡), fog-of-war on unexplored hexes. Travel to adjacent regions.
  7. Rifts: Spawn at local coordinates within the current hex region for short random real-time periods (5-30 minutes) or via quests. Entering loads an instanced procedural dungeon.
  8. In rift dungeon: Navigate procedural layout. At end, a close mechanism (e.g. Rift Core interactable). Closing exits and returns player to the local map at entry position.
  9. Some rifts have bosses at the end; others are standard loot runs. RiftRunner manages lifecycle, timers, loot, threat.
- **Two-layer world model**:
  - **Planet layer** (`WorldGenerator` + `WorldMapScreen`): hex sphere, biome/climate metadata, travel, factions, quests.
  - **Local layer** (`LocalMapGenerator` + `HubWorld`): one 512×512 procedural map per hex (`hex_states` in GameState), edge-connected to neighbors.
- **Loop**: Local map exploration (with dynamic rifts) → Enter rift tunnel → Instanced dungeon → Close rift → Return to local map. World Map for strategic travel between regions.

**RimWorld Inspiration for World Gen:**
- World is a sphere of hex tiles (mostly hexes, some pentagons for topology).
- Biomes determined by latitude (temp), elevation, rainfall/noise.
- Detailed tile info on selection: biome, terrain difficulty, resources, rift/threat level, growing/habitability factors.
- Player picks starting site strategically (good biome for survival, resources, low/high challenge).
- Dynamic elements spawn on world map (like rifts here, or sites/factions in RimWorld).

## Multi-Agent Coding Architecture (Automatic)
- **Remedy (Hermes primary)**: Meta-orchestrator. Logs in, automatically loads context via AGENTS.md/REMEDY.md, decomposes work against dev_plan + NEXT_TASKS, routes tasks.
- **Sub-agents**: Hermes native delegation for focused sub-work.
- **Claude Code / Local**: Used via automatic dispatch when deep reasoning or large refactors needed. Hermes can launch via terminal (`claude -p`) or user opens Claude Code (auto-loads CLAUDE.md + dispatch).
- **Shared Layer (Source of Truth)**:
  - `docs/` for goals/architecture/protocol/tasks
  - `memory/` for handoffs (SESSION_NOTES/), state (LATEST_HANDOFF, CURRENT_STATE, PROJECT_MEMORY), dispatches
  - `skills/` for reusable procedures (remedy orchestrator is key)
- Git optional (no .git currently). All critical state externalized.

## Handoff + Dispatch Flow (Automatic)
Remedy handles:
- Auto context refresh every turn.
- Task decomposition → atomic items in NEXT_TASKS.
- Local work or prepare focused handoff + `memory/dispatches/claude/DISPATCH_*.md`.
- Optional: Use Hermes tools to actually execute the dispatch.
- On return: auto-ingest new handoff → update memory/tasks.

See root REMEDY.md, skills/remedy/SKILL.md, and docs/HANDOFF_PROTOCOL.md.

## Current Implementation Notes
- Data JSONs exist and should be treated as the "soul" of content.
- Managers are stubs or partial — focus on making data load cleanly first.
- Use the multi-agent system to keep long dev sessions (weeks/months) coherent across model switches.

## Future
- Add actual scenes for hub, rifts, tactical map.
- Full save/load roundtrips.
- Combat prototype.
- Settlement and faction systems.
