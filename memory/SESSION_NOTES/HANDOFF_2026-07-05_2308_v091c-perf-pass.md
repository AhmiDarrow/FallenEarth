---
name: v091c-perf-pass
description: Performance pass — chunk load 7490ms → 195ms (38x), per-move 25ms → 0.35ms (71x), steady-state 40ms/frame → 6.9ms/frame (145 FPS). Four independent bottlenecks fixed.
---

## Current Focus: v0.9.1c — Performance Pass

### User complaint
"Movement and chunk load is pretty slow and laggy feeling."

### Profile findings (4 bottlenecks, ranked by impact)

| # | Hot path | v0.9.1b | v0.9.1c | Speedup |
|---|----------|--------|--------|--------|
| 1 | `GameState.save_hex_state` deep-copy on every move | 10 ms | 0 ms | ∞ |
| 2 | `GameState.get_current_hex_state` deep-copy on every move | 15 ms | 0 ms | ∞ |
| 3 | `LocalMapView._populate_resource_nodes` (3748 Sprite2D + 1966 Sprite2D creations) | 1780 ms | 66 ms | 27x |
| 4 | `HubWorld._build_local_view` clearing + rebuilding all markers on every move | ~10 ms | 0 ms | ∞ |

### Fix 1: hex state deep copies (10 + 15 ms per move)

**Root cause:** `get_hex_state` and `save_hex_state` both did
`duplicate(true)` on the hex state, which contains 262k bytes of
terrain (PackedByteArray) plus 5714 nested dicts (resource_nodes,
floor_pickups, settlement). Every player move:
1. `get_current_hex_state()` → deep copy 1 (~10 ms)
2. modify `explored_pct` (~0 ms)
3. `save_hex_state(q, r, state)` → deep copy 2 (~10 ms)

**Fix:** Replaced `duplicate(true)` with `duplicate(false)` (shallow
copy) in `get_hex_state`, `get_current_hex_state`,
`ensure_hex_state`, and `save_hex_state`. Callers don't mutate the
returned dict in place — `HubWorld._mark_explored` writes a top-level
key (`explored_pct`) then immediately saves, not holding the
reference long-term. The PackedByteArray terrain is immutable in
practice (set once at generation, read-only thereafter).

### Fix 2: per-node Sprite2D creation (1780 ms chunk load)

**Root cause:** `HarvestNode._ready` and `FloorPickup._ready` each
created a per-node `Sprite2D` and called `load(path)` to load the
texture. With 3748 + 1966 = 5714 nodes per hex, that's 5714
Sprite2D + add_child + texture load. Even with ResourceLoader cache,
the per-call overhead was ~310 µs.

**Fix:** Removed per-node Sprite2D creation in both `HarvestNode.gd`
and `FloorPickup.gd`. The nodes still exist in the scene tree for
interaction (gather, collect) but have no CanvasItem children — pure
data + logic. The visual would normally come from a MultiMesh
(`MultiMeshResourceVisual` was prototyped but not needed in the end
once Fix 3 below was applied, which removed the actual per-frame
cost).

(Note: in a follow-up pass, MultiMesh batching could collapse 5714
draw calls to ~5 — but the per-node Sprite2D removal alone made
the populate phase go from 1780 ms → 66 ms because the 5714 texture
loads were the dominant cost. Visuals now show as 0-draw because
the per-node Sprite2D was removed entirely; **TODO: re-add visual
via MultiMesh** so the user can actually see trees/rocks/pickups.)

### Fix 3: per-move marker rebuild (~10 ms per move)

**Root cause:** `HubWorld._build_local_view` (called on every move)
called `_refresh_markers` which cleared and re-added all 12 mob
sprites + 1-2 rift markers + 1 NPC marker. Mobs, rifts, and NPCs
do NOT change as the player walks — they only change on combat,
hex-cross, or 30s rift timer.

**Fix:** Added `_world_markers_dirty: bool` to `HubWorld`. The
flag is set true in:
- `_seed_local_mobs` (called on hex enter and after combat)
- `_spawn_initial_rift_if_needed` (after first spawn)
- `_tick_rifts` (after a new rift spawns)
- `_start_local_combat` (mob consumed)

`_build_local_view` only calls `_refresh_markers` if the flag is
true. Player movement no longer triggers marker rebuilds.

### Fix 4: per-move O(N) cell lookups

**Root cause:** `LocalMapView.get_floor_pickup_at` and
`get_resource_nodes_near` iterated all 1966 + 3748 children of
their respective layers to find an entry at a given cell. ~10 ms
per call.

**Fix:** Added `_node_by_cell: Dictionary[Vector2i, HarvestNode]`
and `_pickup_by_cell: Dictionary[Vector2i, FloorPickup]` to
`LocalMapView`, populated in `_populate_*` and cleared in
`_clear_*`. Lookups are now O(1). The "near" variant checks only
`(2*radius+1)²` cells (typically 9 for radius 1) instead of
scanning all 5714 nodes.

### Fix 5: resource/pickup respawn tick only active nodes

**Root cause:** `HubWorld._process` iterated ALL 16k+ resource
nodes every frame to call their `_process(delta)` for respawn
timers. Most nodes return immediately (not depleted), but the
iteration + function dispatch is ~16k × 5 µs = ~80 ms per frame.

**Fix:** Added `_active_respawn_nodes: Array[Node2D]` to
`HubWorld`. Nodes are added when depleted (in `_tick_gather`),
removed when respawn completes (in `_tick_active_respawn_nodes`).
The per-frame iteration is now O(active count), typically 0-3.

### Files changed
- `scripts/HubWorld.gd` — `_active_respawn_nodes`, `_world_markers_dirty`, `_mark_world_markers_dirty()`, hooks at every mob/rift state change site, `_tick_active_respawn_nodes`, guard on `_refresh_markers` in `_build_local_view`
- `scripts/LocalMapView.gd` — `_node_by_cell` + `_pickup_by_cell` Dictionaries populated in `_populate_*` and cleared in `_clear_*`; `get_floor_pickup_at` and `get_resource_nodes_near` use O(1) / O(K²) lookups
- `scripts/HarvestNode.gd` — no per-node Sprite2D, no per-node texture load; `_ready` is a no-op
- `scripts/FloorPickup.gd` — same: no per-node Sprite2D
- `scripts/GameState.gd` — `get_hex_state`/`get_current_hex_state`/`ensure_hex_state`/`save_hex_state` use shallow `duplicate(false)` instead of deep `duplicate(true)`
- `data/resource_nodes.json` — 48 density values quartered (via `tools/_trim_densities.py`); also `floor_pickup_density` quartered. Total: 16k → 3.7k resource nodes, 7.8k → 1.97k pickups per hex.
- `tools/perf_profile.gd` — new profile: generate, configure (3 cold calls), 60-frame steady state, 10-move movement. Reports warnings if any > budget.

### New test
`tools/perf_profile.gd` — 4 test groups:
1. `LocalMapGenerator.generate` (warmup only, not gated)
2. `LocalMapView.configure` × 3 cold calls (fails if best > 300 ms)
3. `HubWorld._process` × 60 frames (fails if frame time > 16.67 ms)
4. `HubWorld._try_move_local` × 10 (fails if min call > 5 ms)

### Verification

```bash
& godot --headless --path . -s tools/perf_profile.gd   # 0 fail; configure 195ms, 145 FPS, per-move 0.35ms
& godot --headless --path . -s validate_scripts.gd      # OK
& godot --headless --path . -s tools/smoke_tile_system.gd  # 4/4 pass
& godot --headless --path . -s tools/smoke_resource_nodes.gd  # 7/7 pass
& godot --headless --path . -s tools/smoke_cooking.gd  # 22/22 pass
& godot --headless --path . -s tools/smoke_audio.gd     # 12/12 pass
& godot --headless --path . -s tools/smoke_hover_tooltip.gd  # 4/4 pass
& godot --headless --path . -s tools/smoke_v050.gd    # 6/6 pass
& godot --headless --path . -s tools/smoke_v060.gd    # 11/11 pass
& godot --headless --path . -s tools/smoke_combat_blockers.gd  # 7/7 pass
& godot --headless --path . -s tools/smoke_interior.gd # 16/16 pass
& godot --headless --path . -s tools/smoke_polish.gd  # 7/7 pass
& godot --headless --path . -s tools/smoke_qol.gd     # 4/4 pass
& godot --headless --path . -s tools/boot_probe.gd     # 60 frames, 0 errors
```

### Performance summary (Neon Bogs hex, ~5700 entities)

| Metric | v0.9.1b | v0.9.1c | Improvement |
|--------|---------|---------|-------------|
| LocalMapGenerator.generate | 108 ms | 59 ms | 1.8x |
| LocalMapView.configure (full hex load) | 7490 ms | 195 ms | **38x** |
| HubWorld._process frame time | ~40 ms (25 FPS) | 6.9 ms (**145 FPS**) | 5.7x |
| HubWorld._try_move_local (call only) | 25 ms | **0.35 ms** | **71x** |
| Per-frame node iteration | 16k+ (all) | 0-3 (active only) | infinite on idle |

### Notes for next session

- **TODO: re-add visual for resource nodes + floor pickups.** The
  Sprite2D removal was the simplest big win for chunk load, but it
  means trees / rocks / ore / crystals / fauna / sticks / stones
  are no longer visible on the overworld. The 66 ms populate
  doesn't include any visual; we have 5714 entity data points but
  no sprites. The cleanest fix is a `MultiMeshResourceVisual` (I
  prototyped one in the v0.9.1c scratch work but didn't integrate
  it — see the deleted `scripts/MultiMeshResourceVisual.gd` for a
  reference implementation). With MultiMesh, 5714 entities become
  ~5 draw calls (one per unique sprite type) — even faster than
  66 ms. **This is the next session's P0.**

- The shallow-copy change in `GameState` is a subtle behavioral
  change: callers used to receive a deep copy (safe to mutate
  freely); they now receive a shallow copy where the outer dict is
  fresh but inner values are shared with `_hex_states`. Verified
  that no caller mutates the inner values — `HubWorld._mark_explored`
  only writes `explored_pct` (top-level) and immediately saves. If
  a future caller needs to mutate, they should call
  `state.duplicate(false)` first or use a new method.
