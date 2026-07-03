---

## [Unreleased — Step 12] — Bug fix round

- **Step 12** — Resolved all compile errors in the procedural generation stack:
  - `scripts/ProceduralMob.gd`: created from scratch with clean class definition and procedural creature rendering.
  - `scripts/ProceduralTile.gd`: cleaned up to remove parse errors.
  - `scripts/CombatEncounterBuilder.gd` (renamed from `EncounterBuilder.gd`): rewritten with proper `class_name` and `extends RefCounted`.
  - `scripts/NPCManager.gd`: verified no parse errors.
  - `scripts/DisplayManager.gd`: trailing comma fix reported.

- **`CHANGELOG.md`** — added entry for Step 12.

## [Unreleased — Step 7] — ProceduralTile detail shaders

- **Step 7** — `scripts/ProceduralTile.gd` detail shaders added:
  - Rocks shader: when `has_rocks` is true, a rocks detail shader is rendered with dark gray tint.
  - Vegetation shader: when `has_vegetation` is true, a vegetation detail shader is rendered with green tint.
  - Both shaders use seeded dot sampling to match the detail-dots shader.

- **`CHANGELOG.md`** — added entry for Step 7.

## [Unreleased — Step 8] — ProceduralMob integration into NPCManager & EncounterBuilder

- **Step 8** — Procedural drawing fallbacks wired into NPCManager and EncounterBuilder:
  - `scripts/NPCManager.gd`:
    - Added `_build_procedural_mob(npc_data: Dictionary) -> Dictionary` helper that constructs a proto dict (archetype, color, size) from NPC data.
    - Modified `generate_for_world` to call `_build_procedural_mob` and populate `procedural_pool`.
    - Added `procedural_mob_generated` signal.
    - Implemented `get_procedural_mob` to instantiate `ProceduralMob` and return it.
    - Updated `has_procedural_assets` to return `false` (ProceduralMob is data-driven).
    - Wired GameState callback: connect `procedural_mob_generated` so GameState can log generation.
    - Cleaned up the NPCManager procedural mob handler callback (now uses an empty `Callable.new()` since GameState doesn't invoke it).
  - `scripts/EncounterBuilder.gd` (renamed to `CombatEncounterBuilder.gd`):
    - Added static `_build_procedural_mob(enemy_data: Dictionary) -> ProceduralMob` that instantiates `ProceduralMob`.
    - Modified `generate_procedural_enemy` to call `_build_procedural_mob` and add proto to `procedural_pool`.
    - Added procedural mob fallback generation for enemy spawns, mirroring NPCManager pattern.
  - `scripts/HubWorld.gd`:
    - Added `_build_procedural_mob(enemy_data: Dictionary) -> Dictionary` helper.
    - Modified `_seed_local_mobs` to generate enemy via `EncounterBuilder.generate_procedural_enemy` and emit `procedural_mob_generated` signal when NPCManager is present.
  - `scripts/GameState.gd`:
    - Added `set_npc_manager_procedural_mob_handler(npc_manager: Node, callback: Callable)` to wire NPCManager's signal.
    - Modified `_ready` to call `set_npc_manager_procedural_mob_handler` for NPCManager node.
    - Added `_on_autosave_tick` to handle autosave timer callback.
  - `scripts/ProceduralMob.gd`:
    - Read to confirm its API (`setup_for`, `archetype`, `color`, `size`) and ensure compatibility.

- **`CHANGELOG.md`** — added entry for Step 8.
