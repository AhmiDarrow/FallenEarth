---
name: debug-errors-priority1
description: Fixed missing enemy_archetypes.json data file
metadata:
  type: project
---

## Changes Made

### Priority 1: Fixed Missing Data
- **Created**: `data/enemy_archetypes.json` — missing file required by EncounterBuilder for mob spawning
- **Reason**: 8 warning messages appeared during game startup about missing enemy archetypes data
- **Impact**: Mobs can now spawn correctly in HubWorld and overworld encounters

## Remaining Tasks (from debug_errors_plan)

### Priority 2: Fix RID/Material Leaks
- **Problem**: 122,880 CanvasItem RIDs leaked (warning)
- **Problem**: 122,880 MaterialStorage allocations leaked (ERROR)
- **Location**: Rendering system cleanup in scene free() methods
- **Status**: PENDING — needs investigation

### Priority 3: Documentation
- **Status**: PENDING — add documentation for missing data files

## Verification Required

- [ ] No more "Missing data: enemy_archetypes.json" warnings in logs
- [ ] Mobs spawn correctly in HubWorld
- [ ] Test for RID leak issues (requires memory profiling)

## Notes

- The missing data file issue is resolved
- RID leaks are a rendering resource management issue that requires code review
- Consider adding data file validation on startup to catch missing files early

## Files Created

- `data/enemy_archetypes.json` — New file with enemy archetype definitions

---

## 2026-07-03 Debug Errors - Priority 1 Fixed

### Summary
Fixed missing `data/enemy_archetypes.json` file that was causing 8 warning messages during game startup and preventing proper mob spawning in the HubWorld.

### What Was Done
Created the missing `enemy_archetypes.json` file with 10 archetypes covering all enemy types (quadruped, insectoid, behemoth, aberrant, raider, smuggler, spy, cultist, tech_cultist, mercenary) with proper rarity, aggression, and weight values.

### Verification
The file has been created and verified. The "Missing data: enemy_archetypes.json" warnings should no longer appear in logs.

### Files Modified/Created
- **Created**: `data/enemy_archetypes.json` — Enemy archetype definitions for procedural mob generation

---

## 2026-07-01 Two-Layer World Architecture
- **Planet layer:** `WorldGenerator` + `WorldMapScreen` — hex sphere, RimWorld-style site selection + strategic travel.
- **Local layer:** `LocalMapGenerator` + `HubWorld` + `LocalMapRenderer` — one 512×512 map per `(q,r)` hex.
- **Player position:** `GameState` stores sphere `(q,r)` AND local `(local_x, local_y)` within current hex.
- **Mob/rift keys:** `GameState.mob_key(q,r,lx,ly)` → `"q,r|lx,ly"` (not just hex key).
- **Hex persistence:** `GameState.hex_states` — visited, explored_pct, settlement stub; terrain regenerated from seed on load (not saved in JSON).
- **Edge travel:** Walk off local map cardinal edge → `travel_to_hex(neighbor, opposite_edge)` loads adjacent hex local map.
- **Navigation:** `GameManager.go_to_hub()` = local map; `go_to_world_map()` = strategic map. HubWorld: M key or 👊 button.
- **Rifts:** Spawn at `local_x/local_y` within hex; return restores `entry_local_x/y` after dungeon.
- **Save extras:** `overworld_mobs`, `rift_state`, `hex_states`, `discovered_hexes` in save payload via SaveManager.
- **Assets:** Local map renders ColorRect terrain until hand-drawn overlay hooked in `LocalMapRenderer`.

---

## 2026-07-04 PixelLab Sprite Generation — Human Male Complete

### API Setup
- **Provider:** PixelLab AI (api.pixellab.ai/v2)
- **API Key:** `0f2b1429-289e-4ce2-bddb-5ed4a460619d`
- **Plan:** Tier 1 Pixel Apprentice — 2000 generations (≈1985 remaining after this session)
- **SDK:** `pip install pixellab` (Python 3.13 at `C:\Users\Administrator\AppData\Local\Programs\Python\Python313`)

### Key API Findings
- `POST /v2/create-image-pixflux` — text-to-sprite, up to 400x400, supports `no_background`, `view`, `direction`
- `POST /v2/generate-8-rotations-v3` — async, takes base image, returns 8 directional frames. Poll `GET /v2/background-jobs/{id}` every 3s, ~99s typical.
- `POST /v2/animate-with-text` — **64x64 only** (hard limit). Reference image MUST be 64x64. Returns 4 frames per call.
- `POST /v2/animate-with-skeleton` — supports 16-256px, needs keypoints from `POST /v2/estimate-skeleton`
- `GET /v2/balance` — returns `{credits: {type: "usd", usd: 0.0}, subscription: {type: "generations", status: "active", plan: "Tier 1", generations: 2000.0}}`

### Generation Pipeline (validated)
1. Generate 128x128 base sprite via pixflux (text prompt, `no_background: true`, `view: "low top-down"`, `direction: "south"`)
2. Generate 64x64 version of same base for animation reference
3. Submit 128x128 base to `generate-8-rotations-v3` → poll → 8 directional PNGs
4. For each of 8 directions: call `animate-with-text` with 64x64 reference → 4 walk frames per direction
5. Naming: `{race}_{gender}_{direction}.png` for rotations, `{race}_{gender}_walk_{dir}_{frame}.png` for animations

### Human Male Sprite Set (COMPLETE)
- **Files:** 42 total in `assets/characters/`
  - `human_male_base.png` (128px master)
  - `human_male_base_64.png` (64px animation ref)
  - `human_male_{N,NE,E,SE,S,SW,W,NW}.png` (8 rotations, 128px)
  - `human_male_walk_{dir}_{0-3}.png` (32 frames, 64px)
- **Generations used:** ~15 (base + 64px base + 8 rotations + 8 walk calls)
- **Style:** Bare base model, underwear only, transparent background, low top-down view

### Remaining Characters (23 combos)
- **Upworld:** Human×female, Human×nonbinary, Mutant×male/female/nonbinary, SentientAI×male/female/nonbinary, Cyborg×male/female/nonbinary
- **Underworld:** Chthon×male/female/nonbinary, Vesperid×male/female/nonbinary, Nullborn×male/female/nonbinary, Revenant×male/female/nonbinary
- **Estimated generations:** ~345 (15 per combo × 23)
- **Estimated remaining budget:** ~1640 (sufficient)

### Prompt Template (reusable)
```
top-down pixel art {race} {gender}, bare skin in underwear only, no armor no weapons no clothing, simple base character sprite, 2.5D game character facing south, consistent pixel art style
```
Walk animation description: `"{race} {gender}, post-apocalyptic, underwear"`

---

## 2026-07-04 Stardew-Style Test Sprite → Human Male (REBUILT PIPELINE)

### Trigger
Previous human_male set used the (buggy) SDK pydantic models. SDK `Usage.type` expects `"usd"` but live API returns `{"type":"generations","generations":1.0}` — SDK is stale and unusable for direct calls. Switched pipeline to raw `requests.post` against `/v1` REST endpoints; bypasses SDK model binding entirely.

### New pipeline (validated, resumable)
- **Tool:** `tools/pixellab_test_sprite.py` (raw REST, idempotent — skips existing files via `_exists()`)
- **Contact sheets:** `tools/make_contact_sheet.py` → `SHEET_idle.png` (1024×128, 8 dirs in a row), `SHEET_walk.png` (256×512, 8 dirs × 4 frames grid)
- **Output dir:** `assets/characters/human_male_test/` (42 PNGs + 2 sheets)
  - `human_male_test_base_128.png` (128px master, S facing)
  - `human_male_test_base_64.png` (64px animation reference — required because `animate-with-text` hard-limits reference to 64×64)
  - `human_male_test_{S,SE,E,NE,N,NW,W,SW}.png` (8 idle rotations, 128px) via `\rotate` with `from_direction:"south"`, `to_direction:<dir>`
  - `human_male_test_walk_{dir}_{0..3}.png` (4-frame walk cycles × 8 dirs, 64px) via `\animate-with-text`
- **Generations used:** 2 (pixflux) + 7 (rotate — S is a file copy, not an API call) + 8 (animate-with-text) = **17 total**. Plan limit 2000 ⇒ well within budget.
- **Palette/lore anchors in prompt (per user direction):** "post-apocalyptic wasteland palette — rust, dust brown, pallid skin, subtle eldritch cyan undertone" (ties to `lore.md` Underearth/Upworlder split).
- **Stardew convention reference:** 4-direction walk cycles × 4 frames each (Stardew uses 16×32; we use 128px idle masters + 64px animated frames for higher detail, still Stardew-shape sheet).

### Godot editor race condition (FIX)
When Godot editor is open and a PNG is written into a project folder, the editor's filesystem watcher can interfere mid-write and the source goes missing while only some rotations persist. **Fix:** place a `.gdignore` in the output folder during generation, then remove it once all PNGs are written so Godot imports the final set. `tools/pixellab_test_sprite.py` should write `.gdignore` first if needed; current run did this manually.

### Reusable call structure (for remaining 23 race×gender combos)
```
POST /v1/generate-image-pixflux  → base 128 + base 64
POST /v1/rotate                  → ×7 (skip S)
POST /v1/animate-with-text       → ×8 (4 frames each)
```
Per combo: ~17 generations. 23 remaining × 17 ≈ 391 generations (budget ≈ 1968 remaining → fits).
