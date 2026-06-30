# PROJECT_OVERVIEW — Fallen Earth (Godot 4 Survival RPG)

**Goal:** Build a top-down 2.5D apocalyptic sci-fi survival RPG in Godot 4 focused on exploration, rift-running, tactical grid combat, character progression, settlement building, and faction/lore systems. Data-driven design (JSON first) for easy iteration.

**Success Criteria:**
- Playable loop: Hub exploration → enter Rift → tactical combat → loot/return.
- Core systems functional: World generation (biomes), Character creation (races/classes/appearance), Save/Load, basic combat, UI flow.
- Data tables complete and validated for races, factions, biomes, mobs, etc.
- Clean GDScript architecture using autoloads (GameState, various Managers).
- Multi-session development without losing state via the handoff/memory system.

**Constraints:**
- Godot 4.x, GDScript (data-first: JSON configs loaded at runtime).
- Single-dev friendly; modular, testable where practical.
- Top-down 2.5D aesthetic (grim decay + cosmic horror).
- Existing assets/scenes: project.godot, data/ JSONs, basic managers in scripts/, starter UI scenes.
- Use the external shared memory + strict handoff system for long-form work across Hermes/Remedy, Claude Code (or local distilled models), and sub-agents.

**Key Risks / Open Questions:**
- World generation complexity (hexasphere/biomes/rifts).
- Balancing data-driven systems with Godot scene/node architecture.
- Combat depth vs. scope.
- Save format robustness.
- Performance on larger generated worlds.

**Primary Agent:** Hermes running as Remedy (automatic meta-orchestrator) with delegation to sub-agents or Claude Code (local Ollama claude-code models or CLI) for complex refactors/bursts.

**Memory Layer:** Shared `memory/` + `docs/` + `skills/` (remedy orchestrator + handoff skills) + root AGENTS.md / REMEDY.md / CLAUDE.md for automatic behavior. LATEST_HANDOFF + SESSION_NOTES for git-free cross-agent continuity.

**Current Project State (as of setup):** data/*.json largely defined (races, factions, biomes, mobs, classes, story). Basic GDScript managers and autoload stubs present. dev_plan.md and IDEA_SYNOPSIS.md outline milestones. .hermes/plans/ already used previously.
