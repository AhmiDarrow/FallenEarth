# Fallen Earth — Version & Phase Reference

Single source of truth for release version, save format, and development phase alignment.

## Current Release

| Field | Value |
|-------|-------|
| **Game version** | `0.12.0` |
| **Save format version** | `0.5.0` (`SaveManager.VERSION`) |
| **Godot** | 4.7.1 |
| **Last updated** | 2026-07-21 |
| **Development phase** | Living world / harvest loop |

## Version History (summary)

| Version | Date | Milestone |
|---------|------|-----------|
| `0.12.0` | 2026-07-21 | Harvestable world props, Sprite2D resource visuals, minimap polish, PixelLab wildlife spawn |
| `0.11.0` | 2026-07-06 | Combat Architecture Rewrite (R/S/M) + UI Design System |
| `0.10.10` | 2026-07-06 | Square grid fix, decor polish, legacy UI cleanup |
| `0.10.1` | 2026-07-06 | FFT-style combat UI (arrow, prompt, plates, buttons) |
| `0.9.0` | 2026-07-05 | Settlement Life & Combat Polish (Phases A-F) |
| `0.8.0` | 2026-07-05 | Settlement interiors, NPC sprites, furniture, button assets, riftspire travel, save/load wiring |
| `0.2.0` | 2026-07-01 | Two-layer world (planet + local maps), FFT combat, missions, NPCs, rift loop, chunk renderer |
| `0.0.1` | 2026-06-30 | Core flow: Splash → Menu → Character Select → Hub stub; memory/handoff system |

## Save Format `0.5.0` Top-Level Keys

```
version, character, appearance, equipment, game_state,
world_data, player_position {q, r, local_x, local_y},
hex_states, discovered_hexes, overworld_mobs, rift_state,
world_npcs, faction_rep, recruited_npc_ids, missions
```

- `hex_states` terrain is **not** saved — regenerated from `local_seed` on load.
- `entity_blocked` is rebuilt on load from resource/decor placement.
- Legacy saves without `local_x/local_y` default spawn to hex center `(256, 256)`.

## Phase Map (dev_plan alignment)

| Phase | Name | Status |
|-------|------|--------|
| 1–3 | Core engine, data, playable flow | ✅ Complete |
| 4 | World gen + two-layer maps | ✅ Complete |
| 5 | Rifts as tunnels + dungeons | ✅ Complete |
| 6 | Local perf + settlement + tile overlay | ✅ Complete |
| 7 | Settlement life + combat polish | ✅ Complete (v0.9.0) |
| 8 | UI Design System | ✅ Complete (v0.11.0) |
| 9 | Living local map (harvest, wildlife, props) | ✅ Complete (v0.12.0) |
| 10+ | Riftspire content, economy, party expansion | ⏳ Planned |

## Files That Must Match Game Version `0.12.0`

- `project.godot` → `config/version`
- `docs/VERSION.md` → Current Release table
- `docs/PROJECT_OVERVIEW.md` / `docs/ARCHITECTURE.md` header
- `memory/CURRENT_STATE.md` → Version line
- `CHANGELOG.md` → latest section

## Files That Must Match Save Format (`SaveManager.VERSION`)

- `scripts/SaveManager.gd` → `const VERSION`
- `scripts/GameState.gd` → `data["version"]` in `save_game()` when set

## Validation Command

```powershell
& ".\Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s tools/validate_scripts.gd
```
