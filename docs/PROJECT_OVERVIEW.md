# PROJECT_OVERVIEW — Fallen Earth (Godot 4 Survival RPG)

**Version:** 0.11.0 (2026-07-18) · Godot 4.7.1 · See `docs/VERSION.md` for phase map and save format.

**Goal:** Build a top-down 2.5D apocalyptic sci-fi survival RPG in Godot 4 focused on exploration, rift-running, tactical grid combat, character progression, settlement building, and faction/lore systems. Data-driven design (JSON first) for easy iteration.

Inspired by RimWorld for world generation: Procedural hexagonal sphere world with varied biomes (based on simulated latitude/temperature, elevation, noise/rainfall), player selects starting tile on the world map (showing biome, threats, resources like RimWorld's landing site selection), then proceeds.

**Exact Game Flow (per spec):**
1. New Game from Main Menu.
2. World Generation: Create a hexagonal sphere world (hex tiles on sphere topology, using biomes from data, climate simulation inspired by RimWorld).
3. Player chooses starting grid/tile on the world map (info panel like RimWorld: biome, danger, features).
4. Character creation screen (select race, class, appearance, name).
5. Enter the **local overworld**: 512×512 playfield for the chosen sphere hex (`HubWorld`). WASD exploration; walk off map edge to enter adjacent hex's local map.
6. Open **World Map** (M key / button): RimWorld-style strategic view — travel between adjacent hex regions, see factions, quests, rift activity.
7. Rifts spawn at **local coordinates** within the current hex (5–30 min windows or quest-triggered). Enter → instanced procedural dungeon → close at core → return to local entry position.

**Success Criteria (v0.2.0):**
- Playable loop: Local map exploration → World Map travel → enter rift → dungeon → close → return to local map with loot.
- Core systems: Hex sphere gen + start choice, two-layer maps, character creation, local + strategic navigation, save/load (v0.2.0 schema), rift instances with close mechanic.
- Data tables for biomes, rifts, etc.
- Data tables complete and validated for races, factions, biomes, mobs, etc.
- Clean GDScript architecture using autoloads (GameState, various Managers).
- Multi-session development without losing state via the handoff/memory system.

**Constraints:**
- Godot 4.7.1, GDScript (data-first: JSON configs loaded at runtime).
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

**Gameplay Style:** RimWorld/Stardew Valley hybrid tailored to lore (post-apoc rift runner settles on hex world tile, builds outpost, forages/gathers daily like SDV farm, manages colony/events like RW, closes rifts for progression). Overworld hex map is central play space.

**Memory Layer:** Shared `memory/` + `docs/` + `skills/` (remedy orchestrator + handoff skills) + root AGENTS.md / REMEDY.md / CLAUDE.md for automatic behavior. LATEST_HANDOFF + SESSION_NOTES for git-free cross-agent continuity.

**Current Project State (v0.2.0):** Two-layer world implemented (planet + local maps). FFT combat, NPCs, missions, rift loop wired. Compile-validated; F5 manual test and settlement building are next. Hand-drawn assets in progress (parallel agent). See `memory/CURRENT_STATE.md` and `docs/NEXT_TASKS.md`.
