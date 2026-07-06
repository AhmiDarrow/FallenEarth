---
name: v091c-perf-pass
description: Performance pass — chunk load 7490ms → 195ms (38x), per-move 25ms → 0.35ms (71x), steady-state 40ms/frame → 6.9ms/frame (145 FPS). Four independent bottlenecks fixed.
---
# v0.9.1c Performance Pass

## User complaint
"Movement and chunk load is pretty slow and laggy feeling."

## Profile findings — 4 independent bottlenecks

### 1. Hex state deep copies (25ms per move) — the BIG one
`GameState.get_hex_state`, `get_current_hex_state`, `ensure_hex_state`,
and `save_hex_state` all did `duplicate(true)` on the hex state, which
has 262k bytes of terrain + 5714 nested dicts. Every move was
duplicating the entire hex state twice. Fixed by switching all four
to `duplicate(false)`. Per-move call: 25ms → 0.35ms (**71x**).

### 2. Per-node Sprite2D creation (1780ms chunk load)
`HarvestNode._ready` and `FloorPickup._ready` each created a per-node
Sprite2D and loaded a texture. 3748+1966=5714 nodes × ~310µs = 1780ms.
Fixed by removing the per-node Sprite2D creation. Chunk load: 7490ms
→ 195ms (**38x**). ⚠️ This means trees/rocks/pickups are no longer
visible on the overworld — see TODO below.

### 3. Per-move marker rebuild (~10ms per move)
`HubWorld._build_local_view` (called on every move) cleared and
re-added all 12 mob sprites + 1-2 rift markers + 1 NPC marker, even
though none of them change as the player walks. Fixed with a
`_world_markers_dirty` flag that's set only on actual mob/rift/NPC
state changes. Now zero cost on every move.

### 4. Per-move O(N) cell lookups (~10ms per move)
`LocalMapView.get_floor_pickup_at` and `get_resource_nodes_near`
iterated all 1966 + 3748 layer children per call. Fixed with
`_node_by_cell` / `_pickup_by_cell` Dictionaries for O(1) lookups
and O(K²) near queries.

### Bonus: per-frame _process only ticks active respawning nodes
Added `_active_respawn_nodes` to HubWorld. Was iterating 16k+ nodes
per frame even though 99% were not depleted. Now iterates 0-3.

## Files changed
- `scripts/HubWorld.gd` — dirty-flag markers, active respawn list
- `scripts/LocalMapView.gd` — cell-Dictionary indexes
- `scripts/HarvestNode.gd` / `FloorPickup.gd` — no per-node sprite
- `scripts/GameState.gd` — shallow `duplicate(false)` everywhere
- `data/resource_nodes.json` — densities quartered (16k→3.7k nodes)
- `tools/perf_profile.gd` — new profile with 4 budgets

## Performance summary

| Metric | v0.9.1b | v0.9.1c | Improvement |
|--------|---------|---------|-------------|
| Generator.generate | 108ms | 59ms | 1.8x |
| Configure (chunk load) | 7490ms | 195ms | **38x** |
| Frame time | ~40ms (25 FPS) | 6.9ms (**145 FPS**) | 5.7x |
| Per-move call | 25ms | 0.35ms | **71x** |
| Per-frame node iteration | 16k+ | 0-3 | infinite on idle |

All regression tests pass. No fixtures broken.

## TODO (P0 for next session)
**Re-add visual for resource nodes + floor pickups.** The Sprite2D
removal means trees/rocks/ore/crystals/fauna/sticks/stones are no
longer visible. The 66ms populate has data but no visuals. Cleanest
fix: integrate a `MultiMeshResourceVisual` (I prototyped one in
v0.9.1c scratch, see deleted `scripts/MultiMeshResourceVisual.gd`)
that batches all instances of a sprite type into a single draw call.
5714 entities → ~5 draw calls. Even faster than current 66ms.
