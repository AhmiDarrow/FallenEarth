# Fallen Earth — Version & Phase Reference

Single source of truth for release version, save format, and development phase alignment.

## Current Release

| Field | Value |
|-------|-------|
| **Game version** | `0.2.0` |
| **Save format version** | `0.2.0` |
| **Godot** | 4.3 |
| **Last updated** | 2026-07-01 |
| **Development phase** | Phase 6 (settlement + visuals) |

## Version History (summary)

| Version | Date | Milestone |
|---------|------|-----------|
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
| 5 | Rifts as tunnels + dungeons | ✅ Complete (F5 verify pending) |
| 6 | Local perf + settlement + tile overlay | 🔄 In progress |
| 7+ | Settlement depth, factions UI, multiplayer stubs | ⏳ Planned |

## Files That Must Match `0.2.0`

- `project.godot` → `config/version`
- `scripts/SaveManager.gd` → `const VERSION`
- `scripts/GameState.gd` → `data["version"]` in `save_game()`
- `CHANGELOG.md` → `[0.2.0]` section
- `docs/NEXT_TASKS.md` → phase status header

## Validation Command

```powershell
& "C:\Users\Administrator\godot\Godot_v4.3-stable_win64.exe" --headless --path "C:\Users\Administrator\FallenEarth" -s validate_scripts.gd
```