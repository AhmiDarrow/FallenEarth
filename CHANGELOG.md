# Changelog

All notable changes to the Fallen Earth project are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

See `docs/VERSION.md` for phase map and save-format reference.

---

## [Unreleased]

### Planned
- Settlement building on local map (build mode, `hex_state.settlement` persistence).
- Hand-drawn tile overlay in `LocalMapRenderer` (blocked on asset delivery).
- World map pan/zoom and discovered-% display.
- Autosave during local exploration.
- MainMenu load-slot UI polish.

### Pending verification
- Manual F5 playthrough of full v0.2.0 loop (see `docs/NEXT_TASKS.md` #7).

---

## [0.2.0] - 2026-07-01

**Milestone:** Two-layer RimWorld-style world, FFT combat, procedural NPCs/missions, full rift loop.

### Added

#### Two-layer world (planet + local)
- `LocalMapGenerator.gd` — procedural 512×512 playfield per sphere hex `(q,r)`.
- `LocalMapRenderer.gd` — 32×32 cell chunk streaming for local viewport.
- `WorldMapScreen.gd` + `scenes/WorldMapScreen.tscn` — strategic hex map (fog, ★ factions, ! quests, ⚡ rifts, adjacent travel).
- `HubWorld.gd` rewritten as **local map** (WASD, Camera2D, edge-crossing, M / 🗺 World Map).
- `GameState` — `hex_states`, `local_x/y`, `discovered_hexes`, `travel_to_hex()`, `mob_key()` helpers.
- `GameManager.go_to_world_map()` navigation.

#### Combat & progression
- FFT tactical combat (`CombatManager`, `TacticalCombat`, `CombatEncounterBuilder`).
- Six classes in `data/character_classes.json` with FFT combat blocks.
- Class progression Lv.1–256 (`ClassProgression`, XP curve, ability unlock tiers).
- Encounter difficulty scaling to party average level (`EncounterDifficulty`).

#### Rifts & dungeons
- Procedural rift dungeons (`RiftDungeonGenerator`, explorable `RiftInstance`).
- Rifts at **local coordinates** within hex; return restores `entry_local_x/y` after close.
- `RiftRunner` save/load/reset; quest rift overrides.

#### NPCs & missions
- Procedural NPC roster per world seed (`NPCGenerator`, `NPCManager`).
- Procedural missions scaled to party level (`MissionGenerator`, `MissionManager`).
- Mission mobs at deterministic `target_local_x/y` within target hex.

#### World generation & flow
- RimWorld-style flow: Menu → WorldGeneration → CharacterSelection → HubWorld.
- Axial hex sphere with climate-based biomes (`WorldGenerator`).

#### Tooling
- `validate_scripts.gd` — headless compile check for all core scripts/scenes.
- `test_npc_generation.gd`, `test_asset_loads.gd`.

### Changed
- **HubWorld** role: strategic hex buttons → 512×512 local playfield (strategic view moved to `WorldMapScreen`).
- **Save format** bumped to `0.2.0` — adds `hex_states`, `discovered_hexes`, `overworld_mobs`, `rift_state`, `player_position.local_x/y`.
- `SaveManager` persists all world-layer keys from `GameState` payload.

### Fixed
- GDScript strict-type inference cascade across autoloads and scenes (Godot 4.3).
- `class_name RiftRunner` removed (conflicted with autoload singleton).
- Save/load shape unification (top-level `character`/`appearance`/world keys).
- MainMenu load-game wiring; `reset_session()` on New Game.
- Review-driven hygiene (`.gitignore`, zombie file removal, data path fixes).
- `HubWorld` mission markers updated for local-map coordinates (was hex-button era).

### Validation
- `validate_scripts.gd`: all core scripts + scenes OK.
- Python validators pass.
- Headless autoload init: zero script errors.
- Manual F5 playthrough recommended (not run in CI).

---

## [0.0.1] - 2026-06-30

### Added
- Core playable flow: Splash → MainMenu → CharacterSelection → HubWorld.
- Multi-agent memory, handoff, and planning system (`memory/`, `docs/`, skills).
- Data tables and manager stubs (`data/*.json`, `scripts/*Manager.gd`).

### Changed
- UI wiring and bug fixes in MainMenu, GameManager, HubWorld, CharacterSelection.

### Fixed
- `run/main_scene` set to `Splash.tscn` in `project.godot`.
- D&D stat system (race base + class mods).
- Godot 4 `.tscn` normalization; Python helper repairs.

---

[Unreleased]: https://github.com/fallen-earth/fallen-earth/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/fallen-earth/fallen-earth/releases/tag/v0.2.0
[0.0.1]: https://github.com/fallen-earth/fallen-earth/releases/tag/v0.0.1