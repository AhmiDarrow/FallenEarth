---
name: v030-tilemap-layer-refactor
description: v0.3.0 — Godot 4.3 TileMapLayer + 50 fresh tiles. Smoke tests green. F5 visual verify next.
---

## Current Focus: v0.3.0 Godot 4.3 TileMapLayer Refactor

All old wang-tile code and the chunked sprite renderer are deleted. The new
`TileSetService` builds a native `TileSet` per biome; `LocalMapView` paints
the 512×512 map with `TileMapLayer`. 50 fresh terrain tiles (10 biomes × 5
terrain types) were generated via PixelLab and imported. Mobs render at
native 64×64 (no more scale-down hack). Compile + smoke + boot-probe all
pass with 0 errors.

### Immediate Next Step

F5 visual playthrough: New Game → World Gen → pick hex → Character →
HubWorld. Watch Godot Output for `[HubWorld] Mob seed:` and confirm mobs
are visible at full size with the new tile terrain. Then walk into each
biome and re-run `tools/generate_tiles.py --biome <dir> --force` for any
tile that doesn't read clearly.

### Relevant Handoffs

- [[v030-tilemap-layer-refactor]] — this handoff (current focus)
- [[hubworld-mob-combat-fix]] — Round 1/2 mob visibility fix (now superseded by v0.3.0)

### Context Files

- `docs/NEXT_TASKS.md` — v0.3.0 P0 is F5 visual playthrough
- `memory/PROJECT_MEMORY.md` — PixelLab pipeline notes (endpoints are now /v2)
- `memory/SESSION_NOTES/HANDOFF_2026-07-04_2156.md` — full 9-section details

---

Proceed with F5 verification, then per-biome tile QA, then `docs/NEXT_TASKS.md` P1 items.
