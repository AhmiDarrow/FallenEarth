---
name: procedural-drawn-conversion-milestone
description: Full procedural drawing system integrated — characters, mobs, tiles
metadata:
  type: project
---

## Procedural Drawing Conversion Milestone

**Date:** 2026-07-02  
**Status:** ✅ Phase 2 Integration Complete — Core files created and integrated

### What Was Done

Created a full procedural drawing system for **Characters**, **Mobs**, and **Tiles** that runs as fallback when external ComfyUI assets are missing. No toggle needed — procedural is default, real assets preserved when available.

**Files Created:**
- `scripts/procedural/Palette.gd` — core color constants autoload
- `scripts/procedural/ProceduralRenderer.gd` — base class for all procedurally drawn entities
- `scripts/procedural/ProceduralCharacter.gd` — full procedurally drawn humanoids (race/gender/anim/equipment)
- `scripts/procedural/ProceduralMob.gd` — creature archetypes (quadruped, insectoid, behemoth, aberrant)
- `scripts/procedural/ProceduralTile.gd` — ground tiles with biome patterns, rifts, rocks, vegetation

**Files Updated:**
- `scripts/CharacterVisual.gd` — integrated procedural fallback when assets missing
- `scripts/GameState.gd` — added `use_procedural_graphics = true` flag (default enabled)
- `scripts/LocalMapRenderer.gd` — now uses `ProceduralTile` instances for all terrain
- `scripts/WorldGenerator.gd` — added `get_procedural_tile()` helper method
- `.hermes/plans/PROCEDURAL_DRAWN_CONVERSION_PLAN.md` — updated to reflect completed phases

### Design Decisions

- **No toggle:** procedural drawing is default, real assets preserved when available
- **Data-driven:** all parameters (race, gender, biome, terrain_type) come from GameState/NPC data
- **Lightweight:** pure GDScript drawing calls, no external textures or shaders
- **Readable:** simplified hand-drawn style — earthy rusty tones, readable silhouettes, top-down 2.5D feel

### Next Steps

Remaining work:
1. Integrate `ProceduralMob` into `NPCManager` for NPC spawning
2. Wire procedural fallback in `EncounterBuilder` for enemy spawns
3. Modify test scenes (`test_asset_loads.gd`, `test_npc_generation.gd`)
4. Add runtime toggle (hotkey F8) — optional polish
5. Phase 3: Animation system polish (walk cycle, direction handling, equipment layering)

### Verification

To verify the system works, run a headless test in Godot:
```
# Build project → Run → Characters/Mobs/Tiles should all render procedurally
# Check no pink squares (missing assets) appear in HubWorld
```

---

[[latter-handoff]] — this handoff now contains the procedural drawing milestone.
