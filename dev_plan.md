# Fallen Earth — Development Milestone Plan (Weighted by Size/Scope/Effort)

**Version:** 0.2.0 · **Phase:** 6 in progress · **Canonical task list:** `docs/NEXT_TASKS.md` · **Release notes:** `CHANGELOG.md`

## Milestone Status (2026-07-01)

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Core Engine Setup | ✅ Done |
| 2 | World Generation | ✅ Done (two-layer: planet + local 512×512) |
| 3 | Character Systems | ✅ Done (D&D stats, race/class, appearance) |
| 4 | Combat Implementation | ✅ Done (FFT tactical, 6 classes, Lv.1–256) |
| 5 | Settlement Building | ⏳ Next (Phase 6) |
| 6 | UI/UX Polish | 🔄 Partial (ColorRect terrain; assets in progress) |
| 7 | Save/Load & Autoloads | ✅ Done (save format v0.2.0) |
| 8 | Factions & Lore | 🔄 Partial (NPCs, missions, rep; no dialogue UI) |
| 9 | Multiplayer | ⏳ Not started |
| 10 | Performance & Stability | 🔄 Partial (`LocalMapRenderer` chunks; F5 verify pending) |

## Base Assumptions
- Godot 4.x, single-dev or small team; building from scratch in `FallenEarth/`.
- Plan follows synopsis systems and weights them realistically (large upfront scaffolding → mid-game complexity → final polish).

| # | Milestone | Scope / Weight | Key Deliverables | Est. Effort |
|---|-----------|----------------|------------------|-------------|
| 1 | **Core Engine Setup** | High — foundational scaffolding; no gameplay yet. | • `project.godot` with autoloads placeholder array<br>• Minimal scene structure (`Main.tscn`, `Assets/`)<br>• Autoload stub scripts: `GameState`, `DisplayManager`, `SaveManager` (no logic)<br>• Unit tests for project config load (Python)<br>• CI lint/check workflow (pre-commit hooks) | 2–3 days |
| 2 | **World Generation** | High — the bulk of overworld content and runtime generation. | • Hexasphere generator: tileset, biome rules, edge transitions<br>• `WorldPreview` scene stubs + seed UI input (no actual rendering yet)<br>• Biome data files & JSON schema validation<br>• Deterministic random seed handling (both player-chosen and auto)<br>• Placeholder terrain heightmap (single float field) | 5–6 days |
| 3 | **Character Systems** | High — one of the most complex systems; interlocks with UI, combat, settlement. | • Origin / Race dropdowns + swatch grids<br>• Gender / Appearance preview panel containers<br>• Class archetypes provide stat mods to core D&D stats (STR/DEX/CON/INT/WIS/CHA)<br>• Save format spec: `appearance`, `equipment` dict (JSON)<br>• Autoload stub: `AppearanceManager`, `RaceManager`, `ClassManager`<br>• Unit tests for appearance serialization | 5–6 days |
| 4 | **Combat Implementation** | Medium-High — grid tactical combat is core but still placeholder. | • Turn-based grid movement + move+act per unit<br>• Aggro / encounter trigger stub (touch node → `TacticalCombat` scene)<br>• Rift creature definitions (10 overworld mobs, modular underearth parts)<br>• Taming & Elemental Fruits table integration<br>• Placeholder AP system (no real costs yet) | 4–5 days |
| 5 | **Settlement Building** | Medium — building placement and NPC recruitment. | • Free-form wall / floor / workbench tiles (top-down grid)<br>• Build mode toggle via Space key<br>• NPC recruitment stub + reputation scaling placeholder<br>• Settlement JSON schema: `structures`, `npcs` arrays | 3–4 days |
| 6 | **UI/UX Polish** | Medium — visual enhancements and animation. | • Animated backgrounds (falling ash, spores, vignettes)<br>• Nine-patch UI assets generation stub<br>• HUD health / resource indicators (placeholder icons)<br>• Pause menu overlay stub → real implementation | 3–4 days |
| 7 | **Save/Load & Autoloads** | Medium — integration of persistence. | • Autosave to `user://saves/slot_0.json`<br>• Load flow: Main Menu → World Creation → Character Creation → Hub / Load<br>• Full autoload set populated (DisplayManager, AppearanceManager, etc.)<br>• Corrupt save recovery stub | 4–5 days |
| 8 | **Factions & Lore Integration** | Medium — narrative layer. | • Faction data tables + reputation UI stubs<br>• Dialogue system placeholder (no text assets yet)<br>• Quest log structure stub | 2–3 days |
| 9 | **Multiplayer Foundations** | Low-Medium — network basics only, no full lobby logic. | • Join / connect buttons (UI) → network client stub<br>• Sync protocol draft document (no implementation) | 2–3 days |
|10| **Performance & Stability** | Medium — final hardening before launch build. | • Canvas size warnings mitigations (`MAX` caps)<br>• Asset streaming / texture atlasing stubs<br>• Memory leak sweeps (profiler runs) | 2–3 days |

## Notes on Weighting
- Milestones 1–4 are the biggest because they involve creating entire subsystems from scratch and establishing data contracts.
- Combining "Character Systems" with UI work could shave a day, but that risks code-base tangling; keeping them separate yields cleaner tests.
- Settlement building is modest: free-form placement on an existing world grid isn't heavy unless you add complex structure interactions later.
- Performance/Stability comes last, as it's iterative and depends on having most features coded first.

## 2026-07-01 Update (v0.2.0)
- **Two-layer world:** `WorldMapScreen` (strategic hex sphere) + `HubWorld` (512×512 local map per hex).
- D&D stats, FFT combat, procedural NPCs/missions, rift loop with local coords + save persistence.
- Released as **v0.2.0** — see `CHANGELOG.md`, `docs/VERSION.md`, `docs/NEXT_TASKS.md`.
- Next: F5 verify → settlement building → tile overlay when assets land.
