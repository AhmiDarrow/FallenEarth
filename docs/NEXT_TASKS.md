# NEXT_TASKS — Fallen Earth

**Version:** 0.2.0 · **Updated:** 2026-07-01 · **Phase:** 6 in progress

*Aligns with `docs/VERSION.md`, `CHANGELOG.md`, and `memory/CURRENT_STATE.md`.*

---

## TOP PRIORITY — Next Session

### P0 — Manual verification

| ID | Task | Status |
|----|------|--------|
| 7 | **F5 playthrough** — New Game → World Gen → pick hex → Character Create → local map (WASD) → World Map travel → enter rift → dungeon → close → return to entry local pos. Log Godot Output errors. | ⏳ READY |

### P1 — Phase 6 coding (assets parallel)

| ID | Task | Status |
|----|------|--------|
| 9 | **Settlement building** — Build mode on local map; place structures at `(local_x, local_y)`; persist in `hex_state.settlement`; toggle via key/button. | ⏳ PENDING |
| 10 | **Tile overlay hook** — When asset agent delivers PNGs, overlay `TileSetBuilder` / `WorldGenerator.get_tile_visual()` in `LocalMapRenderer` (replace ColorRect cells). | ⏳ BLOCKED on assets |
| 11 | **World map polish** — Pan/zoom on `WorldMapScreen`; discovered % per hex; optional faction territory tint. | ⏳ PENDING |

### P2 — Quality of life

| ID | Task | Status |
|----|------|--------|
| 12 | **Autosave during exploration** — Periodic `GameState.save_game(0)` from `HubWorld` (e.g. every 2 min or on hex cross). | ⏳ PENDING |
| 13 | **MainMenu load UI** — Display slot list with character name / region / play time. | ⏳ PENDING |

---

## COMPLETED (v0.2.0 — do not re-implement)

### Phase 4 — World gen + two-layer maps ✅

| ID | Task | Notes |
|----|------|-------|
| 1 | Hex sphere world generation | `WorldGenerator.gd` — axial hex, climate biomes |
| 2 | Starting grid selection | `WorldGeneration.tscn` — RimWorld-style site browse |
| 3 | Game flow reorder | Menu → WorldGen → CharacterSelect → HubWorld |
| 4 | Two-layer world | `WorldMapScreen` (strategic) + `HubWorld` (512×512 local) + edge travel |

### Phase 5 — Rifts ✅

| ID | Task | Notes |
|----|------|-------|
| 5 | Rift spawning at local coords | `RiftRunner` — `local_x/y`, world map ⚡ markers |
| 6 | Dungeon + close + return | `RiftInstance` — restore `entry_local_x/y`; save `rift_state` |
| 8 | Chunk streaming | `LocalMapRenderer.gd` — 32×32 cell chunks |

### Also shipped in 0.2.0 ✅

- FFT tactical combat (`CombatManager`, `TacticalCombat`)
- Six classes + Lv.1–256 progression
- Procedural NPCs + recruitment (`NPCManager`)
- Procedural missions (`MissionManager`) with local mob placement
- Save/load: `hex_states`, `discovered_hexes`, `overworld_mobs`, missions, NPCs

---

## TECH DEBT (resolved — reference only)

- ~~Remove `nul` junk files~~ ✅
- ~~Add `.gitignore`~~ ✅
- ~~Save/load shape unification~~ ✅ (v0.2.0)
- ~~GDScript strict-type compile cascade~~ ✅

---

## Asset work (parallel agent — not coding queue)

- Hand-drawn tilesets per biome (ComfyUI)
- Character sprites (24 race×gender combos)
- UI panels/icons
- Integration point: `LocalMapRenderer` overlay + `CharacterVisual`

---

*Milestone: v0.2.0 shipped (code). Next: F5 verify → settlement → tile overlay.*
*Reminder: end sessions with `prepare-handoff`; update `CHANGELOG.md` on release.*