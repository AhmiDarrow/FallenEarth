# ARCHITECTURE — Fallen Earth Godot Project + Multi-Agent Workflow

## Game Architecture
- **Godot 4 Project** with autoloads for global managers.
- **Data-driven core**: All content (races, biomes, factions, mobs, classes) defined in `data/*.json`. Scripts load and interpret at runtime.
- **Key Systems** (from existing scripts/):
  - GameState.gd, SaveManager.gd
  - WorldGenerator.gd + biomes
  - RaceManager, ClassManager, AppearanceManager, EquipmentManager
  - MobManager, RiftRunner
  - DisplayManager
- **Scenes**: UI (Splash, MainMenu) + future hub/rift/combat scenes.
- **Loop**: Overworld hub/exploration → Rift instances (procedural pockets) → Grid tactical combat.

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
