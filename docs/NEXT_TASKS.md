# NEXT_TASKS — Fallen Earth

**Version:** 0.3.0 · **Updated:** 2026-07-04 · **Phase:** 7 (TileMapLayer system)

*Aligns with `docs/VERSION.md`, `CHANGELOG.md`, and `memory/CURRENT_STATE.md`.*

---

## TOP PRIORITY — Next Session

### P0 — Visual verification

| ID | Task | Status |
|----|------|--------|
| 13 | **F5 playthrough** — New Game → World Gen → pick hex → Character Create → local map. Confirm tiles render via TileMapLayer, mobs visible at 64×64, rift ⚡ / NPC ★ / mission ! markers show as ColorRect+Label. Log any visual issues. | ⏳ READY |

### P1 — Tile polish

| ID | Task | Status |
|----|------|--------|
| 14 | **Tile visual QA** — Open each biome in F5, confirm `ground / debris / vegetation / blocked / rift_scar` look distinct. Replace any tile that's too dark / too similar to neighbours (re-run `tools/generate_tiles.py --biome <x> --force`). | ⏳ PENDING |
| 15 | **Marker polish** — `LocalMapView.add_marker` uses a hard-coded 18×18 ColorRect; size per kind (rift 22, npc 18, mission 16) is the next pass. | ⏳ PENDING |
| 16 | **Mob y-sort** — `MobLayer.y_sort_enabled` is on, but mobs at identical y overlap. Add small jitter to spawn positions if the visual stutter is noticeable. | ⏳ PENDING |

### P2 — Quality of life

| ID | Task | Status |
|----|------|--------|
| 17 | **Autosave during exploration** — Periodic `GameState.save_game(0)` from `HubWorld` (every 2 min or on hex cross). | ⏳ PENDING |
| 18 | **MainMenu load UI** — Display slot list with character name / region / play time. | ⏳ PENDING |

---

## COMPLETED (v0.3.0 — do not re-implement)

### Phase 7 — Godot 4.3 TileMapLayer system ✅

| ID | Task | Notes |
|----|------|-------|
| 19 | Removed old draw tile system | Deleted `LocalMapRenderer.gd`, `BiomeTilesetManager.gd`, `TileSetBuilder.gd`, `TileSetFactory.gd`, `TileTest.tscn/.gd`, `BiomeTilesets` autoload, `assets/tilesets/*` |
| 20 | New `TileSetService` | Godot 4.3 TileSet + TileSetAtlasSource, 5 terrains per biome, blocked tile has full-cell collision polygon. |
| 21 | New `LocalMapView` scene | `TileMapLayer` for ground, y-sorted `MobLayer` for entities, `MarkerLayer` for rift/NPC/mission. |
| 22 | New tile assets | 50 PNGs (10 biomes × 5 terrains) via `tools/generate_tiles.py` + PixelLab pixflux. |
| 23 | `MobVisual` rewrite | No scale-down hack. 64×64 sprite at native size, NEAREST filter, parented to y-sorted `MobLayer`. |
| 24 | `HubWorld` migration | Uses `LocalMapView`; removed `_make_circle_texture` procedural draw entirely. |
| 25 | Smoke test | `tools/smoke_tile_system.gd` exercises TileSetService (10 biomes), LocalMapView, MobVisual, HubWorld scene. |
| 26 | Boot probe | `tools/boot_probe.gd` runs MainMenu 60 frames headless with zero runtime errors. |

### Phase 4 — World gen + two-layer maps ✅ (v0.2.0)

### Phase 5 — Rifts ✅ (v0.2.0)

### Phase 6 — Combat / NPCs / missions ✅ (v0.2.0)

---

## TECH DEBT (reference only)

- ~~Remove `nul` junk files~~ ✅
- ~~Add `.gitignore`~~ ✅
- ~~Save/load shape unification~~ ✅
- ~~GDScript strict-type compile cascade~~ ✅
- ~~Old wang-tile draw system~~ ✅ (v0.3.0)
- ~~Procedural `_make_circle_texture` markers~~ ✅ (v0.3.0 — replaced with ColorRect+Label)

---

## Asset work (PixelLab API — in progress)

- [x] Human male base sprite + 8 rotations + walk frames
- [ ] Remaining 23 race×gender combos (same pipeline)
- [x] 10 mob sprites (regenerated round 2 — visible silhouette)
- [x] 50 terrain tiles (10 biomes × 5 types) — **NEW v0.3.0**
- [ ] Idle animation frames
- [ ] Attack animation frames
- **API key & pipeline documented in `memory/PROJECT_MEMORY.md`**

---

*Milestone: v0.3.0 shipped (Godot 4.3 TileMapLayer). Next: F5 visual verify → tile QA per biome.*
*Reminder: end sessions with `prepare-handoff`; update `CHANGELOG.md` on release.*
