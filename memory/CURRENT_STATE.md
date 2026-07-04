# CURRENT STATE — Fallen Earth

**Version:** 0.2.0  
**Last Updated:** 2026-07-04  
**Active Agent:** — (session ended)  
**Current Phase:** Phase 6 in progress (chunk renderer ✅ · settlement ⏳ · tile overlay blocked on assets)

## Summary

Two-layer world architecture is implemented and validated at compile-time. The game now has a RimWorld-style strategic hex sphere (`WorldMapScreen`) and a 512×512 local playfield per hex (`HubWorld`). Rift close/return restores local entry position. Mobs, rifts, hex states, and discovered regions persist in save files.

**Not yet done:** Manual F5 playthrough, settlement building, hand-drawn tile overlay (asset agent in progress).

## Playable Flow (intended)

```
Splash → MainMenu → WorldGeneration (pick start hex)
  → CharacterSelection → HubWorld (local 512×512 map)
      → WASD + edge-cross between hex regions
      → M / 🗺 → WorldMapScreen (adjacent travel, faction/quest/rift markers)
      → ⚡ on local map → RiftInstance → close → back to entry local pos
      → ★ NPC settlement (walk near marker) → recruit / missions
```

## Key Systems

| System | Status | Key Files |
|--------|--------|-----------|
| Sphere world gen | ✅ | `WorldGenerator.gd`, `WorldGeneration.tscn` |
| Strategic world map | ✅ | `WorldMapScreen.gd`, `scenes/WorldMapScreen.tscn` |
| Local 512×512 maps | ✅ | `LocalMapGenerator.gd`, `HubWorld.gd` |
| Chunk streaming | ✅ | `LocalMapRenderer.gd` |
| Hex state + travel | ✅ | `GameState.gd` (`hex_states`, `travel_to_hex`) |
| Rifts (local coords) | ✅ | `RiftRunner.gd`, `RiftInstance.gd` |
| Tactical combat (FFT) | ✅ | `TacticalCombat.gd`, `CombatManager.gd` |
| Missions (local mobs) | ✅ | `MissionManager.gd` |
| Save/load (world layer) | ✅ | `GameState.gd`, `SaveManager.gd` |
| Display options | ✅ | `DisplayManager.gd`, `Options.gd`, `scenes/ui/Options.tscn` |
| Hand-drawn visuals | 🔄 | Asset agent — `assets/tilesets/`, ComfyUI workflows |
| Settlement building | ⏳ | Not started — `hex_state.settlement` stub in generator |

## Validation

```powershell
& "C:\Users\Administrator\godot\Godot_v4.3-stable_win64.exe" --headless --path "C:\Users\Administrator\FallenEarth" -s validate_scripts.gd
```

Last run: **All scripts and scenes OK.**

## Next Session Priorities

1. **F5 manual test** — full new-game loop; fix any runtime errors
2. **Settlement building** — build mode, structure placement, `hex_state.settlement` persistence
3. **Tile overlay** — integrate asset agent output into `LocalMapRenderer` when ready

## Parallel Work

- **Asset agent:** ComfyUI hand-drawn generation (characters, tiles, UI). Do not block code work; overlay hook is the integration point.

---

*See `memory/SESSION_NOTES/HANDOFF_2026-07-01_1700.md` for full 9-section handoff.*