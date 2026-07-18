# Fallen Earth — Version & Phase Reference

Single source of truth for release version, save format, and development phase alignment.

## Current Release

| Field | Value |
|-------|-------|
| **Game version** | `0.9.0` |
| **Save format version** | `0.2.0` |
| **Godot** | 4.7.1 |
| **Last updated** | 2026-07-18 |
| **Development phase** | Phase 7 (settlement life + combat polish) — Godot 4.7 upgrade |

## Version History (summary)

| Version | Date | Milestone |
|---------|------|-----------|
| `0.9.0` | 2026-07-05 | Settlement Life & Combat Polish (Phase A-F) — IN PROGRESS |
| `0.8.0` | 2026-07-05 | Settlement interiors, NPC sprites, furniture, button assets, riftspire travel, save/load wiring |
| `0.2.0` | 2026-07-01 | Two-layer world (planet + local maps), FFT combat, missions, NPCs, rift loop, chunk renderer |
| `0.0.1` | 2026-06-30 | Core flow: Splash → Menu → Character Select → Hub stub; memory/handoff system |

## Save Format `0.2.0` Top-Level Keys

```
version, character, appearance, equipment, game_state,
world_data, player_position {q, r, local_x, local_y},
hex_states, discovered_hexes, overworld_mobs, rift_state,
world_npcs, faction_rep, recruited_npc_ids, missions
```

- `hex_states` terrain is **not** saved — regenerated from `local_seed` on load.
- Legacy saves without `local_x/local_y` default spawn to hex center `(256, 256)`.

## Phase Map (dev_plan alignment)

| Phase | Name | Status |
|-------|------|--------|
| 1–3 | Core engine, data, playable flow | ✅ Complete |
| 4 | World gen + two-layer maps | ✅ Complete |
| 5 | Rifts as tunnels + dungeons | ✅ Complete |
| 6 | Local perf + settlement + tile overlay | ✅ Complete |
| 7 | Settlement life + combat polish | 🔄 In progress (v0.9.0) |
| 8+ | Riftspire content, economy, party expansion | ⏳ Planned |

## Files That Must Match `0.2.0`

- `project.godot` → `config/version`
- `scripts/SaveManager.gd` → `const VERSION`
- `scripts/GameState.gd` → `data["version"]` in `save_game()`
- `CHANGELOG.md` → `[0.2.0]` section
- `docs/NEXT_TASKS.md` → phase status header

## Validation Command

```powershell
& "C:\Users\Administrator\FallenEarth\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Users\Administrator\FallenEarth" -s tools/validate_scripts.gd
```