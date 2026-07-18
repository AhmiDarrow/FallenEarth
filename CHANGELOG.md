---

## [Unreleased] — Godot 4.7.1 Upgrade

### Engine Upgrade
- Upgraded from **Godot 4.3** to **Godot 4.7.1** (stable, 2026-07-14)
- Updated `project.godot` config/features from `"4.3"` to `"4.7"`
- Added `.godot-version` file pinning the project to 4.7.1

### Fixes for Breaking Changes
- **GDScript class resolution**: Added `preload("res://scripts/WorldGenerator.gd")` to scripts that use `WorldGenerator` static methods directly (NPCGenerator.gd, MissionGenerator.gd, CombatEncounterBuilder.gd) — required because Godot 4.4+ uses stricter GDScript dependency tracking
- **GameManager.gd**: Changed `var hub: HubWorld = ... as HubWorld` type cast to `var hub: Node = ...` to avoid HubWorld class resolution failure during autoload compilation

### Documentation
- `docs/VERSION.md`: Godot 4.3 → 4.7.1, updated validation command path
- `docs/PROJECT_OVERVIEW.md`: Updated Godot version reference
- `tools/` — All smoke tests pass on Godot 4.7.1

---

## [Unreleased — v0.10.0] — Combat Overhaul (FFT-style)

- **v0.10.0** — Complete combat overhaul. The 7×7 grid of plain
  `ColorRect` buttons with text symbols is now a real tactical
  scene with the same sprite + tile pipeline as the overworld.

  ### Visual overhaul (Phase 1)
  - `scripts/combat/BattleCell.gd` — one cell: terrain tile, height
    mark, range highlight (move/attack/skill). Click routes to the
    parent grid.
  - `scripts/combat/BattleGridView.gd` — 7×7 grid, configurable size.
    Lays out 49 cells with real biome `ground.png` tiles. Spawns
    `BattleUnit` nodes from the encounter's units array. Range
    highlighting follows the player's subphase.
  - `scripts/combat/BattleUnit.gd` — per-unit Node2D with the mob's
    sprite (8 directions, flips for E/W), HP bar overlay, CT bar,
    name label, walk tween, attack swing, hit flash, death fade.
    Uses `assets/mobs/{id}.png` for enemies and the character
    sprite folder for the player.
  - `scripts/combat/BattleBackground.gd` — atmospheric backdrop:
    biome-themed dark tint + ~64 scattered biome tiles around the
    grid + 18 drifting motes (sine-wave tween) for motion.
  - `scripts/TacticalCombat.gd` refactored to delegate to the new
    components. Old `Button[]` grid, text symbols (◎/☠/✕), `_setup_grid`,
    and `_update_grid` rendering are removed. `scenes/TacticalCombat.tscn`
    restructured with a `BattleBackgroundLayer` (z=-10),
    `BattleLayer` (z=1, contains the grid + feedback), and `HUDLayer`
    (z=10) for the existing status/turn-order/buttons.

  ### AI overhaul (Phase 2)
  - `scripts/ai/CombatAI.gd` — base class. Static helpers
    `chebyshev`, `facing_toward`, `facing_bonus`, and `score_attack`.
  - `scripts/ai/AggressiveAI.gd` — melee rush. Prefers flanking
    (back/side bonus) and finishing off low-HP targets.
  - `scripts/ai/RangedAI.gd` — maintains optimal distance. Retreats
    if too close; advances cautiously otherwise.
  - `scripts/ai/CasterAI.gd` — prefers skills when MP ≥ cost.
    Positions for max AOE skill targets. Falls back to attack when
    out of MP.
  - `scripts/ai/DefensiveAI.gd` — guards low-HP allies. Retreats at
    < 30% HP. Uses height advantage.
  - `scripts/ai/BossAI.gd` — multi-phase: aggressive at >50% HP,
    mixed AOE at 25-50%, enrage at <25% with signature ability used
    once.
  - `scripts/ai/CombatAIEngine.gd` — factory (`build(archetype)`)
    and state builder (`build_state(...)`).
  - `scripts/CombatManager.gd._run_enemy_turn` refactored to call
    the AI and execute the returned action (move / attack / skill
    / wait / defend). Per-unit AI instances are cached (BossAI
    keeps state across turns).
  - `data/mobs.json` — `ai_archetype` added to all 27 mobs.
    Distribution: aggressive=11, defensive=3, ranged=4, boss=5,
    caster=4.

  ### UI polish (Phase 3)
  - `scripts/combat/BattleHUD.gd` — top status bar with portrait,
    name, class, HP / MP / CT bars. Auto-refreshes on
    `active_unit_changed` and `unit_updated`.
  - `scripts/combat/TurnOrderPanel.gd` — right-side sidebar with
    mini-portraits and CT progress for the next 6 units. Highlights
    the active unit.
  - `scripts/combat/BattleResultPanel.gd` — styled victory / defeat
    panel with biome-themed backdrop. Pop-in tween.
  - `scripts/combat/CombatPopup.gd` — floating "MISS" / "CRITICAL" /
    "BACK!" / "SIDE" / "DODGE" / "COUNTER" text with zoom-in
    + rise + fade.
  - `scripts/combat/TargetingReticle.gd` — 4-corner bracket sprite
    that follows the cursor during TARGET_ATTACK / TARGET_SKILL.
    Pulses (1.0 ↔ 1.15 scale). Color-coded for attack / skill / move.

  ### Assets (Phase 4, PixelLab MCP)
  - `assets/battle_ui/battle_hud_panel.png` — dark rusted metal
    panel with weathered edges and glowing teal accents (512×256).
  - `assets/battle_ui/victory_panel.png` — stained parchment with
    iron rivets (512×256).
  - `assets/battle_ui/defeat_panel.png` — cracked crimson stone
    tablet (512×256).
  - `assets/battle_ui/reticle.png` — 4-corner golden yellow
    targeting reticle (64×64).
  - `assets/battle_ui/icon_attack.png` — sword-crossing-shield
    action icon (32×32).
  - `assets/battle_ui/icon_skill.png` — magical blue flame (32×32).
  - `assets/battle_ui/icon_wait.png` — hourglass wait symbol
    (32×32).

  ### Smoke tests
  - `tools/smoke_combat_v100.gd` — Phase 1 (visual): 27 checks,
    covers BattleCell, BattleGridView, BattleUnit, BattleBackground,
    terrain generation, scene composition, legacy removal.
  - `tools/smoke_combat_ai.gd` — Phase 2 (AI): 11 checks, covers
    each archetype on controlled 7×7 grids, plus mobs.json
    distribution check.
  - `tools/smoke_combat_ui.gd` — Phase 3 (UI): 15 checks, covers
    HUD updates, turn-order rendering, victory/defeat panel,
    popups, reticle, asset presence.

  ### Modified
  - `scripts/CombatManager.gd` — added `ai_archetype` / `abilities`
    / `mp` fields to enemy units. `_run_enemy_turn` refactored to
    call the AI. New helpers: `_compute_attackable`,
    `_compute_skillable`, `_build_blocked_grid`, `_chebyshev`.
  - `data/mobs.json` — `ai_archetype` added to all 27 mobs.
  - `validate_scripts.gd` — new scripts added.
  - `docs/NEXT_TASKS.md` — v0.10.0 plan documented.

## [v0.9.0] — Settlement Life & Combat Polish

(Phases A-F — see `memory/SESSION_NOTES/HANDOFF_2026-07-05_charmenu_pause_pattern.md`
and related session notes for the full breakdown.)

---

## [Unreleased — v0.9.1c] — Performance pass

- **v0.9.1c** — Four independent bottlenecks fixed; gameplay now
  feels snappy:
  - `GameState` hex-state deep copies were duplicating 262k bytes of
    terrain + 5714 nested dicts on every move. Switched to shallow
    `duplicate(false)` in `get_hex_state`, `get_current_hex_state`,
    `ensure_hex_state`, and `save_hex_state`. Per-move call:
    25 ms → 0.35 ms (**71x**).
  - Per-node Sprite2D creation in `HarvestNode._ready` and
    `FloorPickup._ready` was loading 5714 textures on chunk load
    (16k+ resource nodes + 7.8k pickups in v0.9.1b). Removed
    per-node Sprite2D. Chunk load: 7490 ms → 195 ms (**38x**).
    Resource/pickup densities in `data/resource_nodes.json`
    quartered in tandem (16k → 3.7k nodes, 7.8k → 1.97k pickups).
    ⚠️ **Note:** trees, rocks, ore, crystals, fauna, sticks, and
    stones are no longer visible on the overworld — TODO is to
    re-add visuals via MultiMesh batching.
  - `HubWorld._build_local_view` was clearing and rebuilding all
    marker/mob/NPC sprites on every move. Added `_world_markers_dirty`
    flag, set only on actual state changes. Movement is now
    marker-free.
  - `LocalMapView.get_floor_pickup_at` / `get_resource_nodes_near`
    iterated all 5714 layer children per call. Added
    `_node_by_cell` / `_pickup_by_cell` Dictionary indexes for
    O(1) cell lookups and O(K²) near queries.
  - `HubWorld._process` was iterating 16k+ resource nodes per frame
    to call their `_process(delta)` for respawn timers. Now iterates
    only the small `_active_respawn_nodes` list.
  - `tools/perf_profile.gd` — new test with 4 budgets: configure
    < 300 ms, frame time < 16.67 ms, per-move call < 5 ms.

## [Unreleased — v0.9.1b] — Combat blockers fix

- **v0.9.1b** — Combat is now testable end-to-end. Two blockers fixed:
  - `scenes/RiftInstance.tscn` — six child nodes had relative `parent="<short-name>"` paths
    (`GridContainer`, `EndTurnButton`, `ClearRiftButton`, `BackButton`, `LootTitle`, `LootLabel`).
    In Godot 4 these are scene-root-relative paths, not sibling names, so the children
    were silently orphaned and the rift UI was broken. Fixed to the full path
    (`MainVBox/GridPanel`, `MainVBox/ActionsHBox`, `MainVBox/LootPanel`).
  - Overworld mob visibility — bumped density from 2-9 to 8-20 mobs per hex
    (`scripts/HubWorld.gd` `_seed_local_mobs`); added a guaranteed "near-spawn" pass
    that places 2 mobs within 3-20 cells of the player on initial hex entry; reduced
    cell exclusion from 5 to 2 cells; reduced initial rift spawn distance from
    8-20 to 4-12 cells with bounds clamping.
  - `scripts/ui/Minimap.gd` — added a 80×50 px bottom-left inset showing the local
    map around the player with red dots for hostile mobs, gray-green for neutral,
    so the player can navigate toward fights without scrolling the world.
  - `scripts/HubWorld.gd` `_update_tile_info` — surfaces mob count + nearest mob
    distance in the bottom-left tile info label.
  - `tools/smoke_combat_blockers.gd` — 7 test groups, all pass (12 mobs seeded,
    nearest 15 cells from player).

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
