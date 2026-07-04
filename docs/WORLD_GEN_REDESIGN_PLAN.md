# World Generation Screen Rework Plan

**Goal:** Transform the current text-based WorldGeneration screen into a visual hex-sphere preview where players click to choose their starting tile — RimWorld-style.

## Current State (Summary)

- **WorldGeneration.tscn**: Simple VBoxContainer with seed input, Generate/Continue buttons, status label, text candidate buttons
- **WorldGeneration.gd**: Generates world, shows candidate buttons as text labels, player clicks one, stores start tile
- **WorldGenerator.gd**:
  - `HEX_RADIUS = 12` (fixed size, 469 hexes)
  - `axial_to_pixel(q, r, hex_size) -> Vector2` — axial → screen coords
  - `hex_distance(q1, r1, q2, r2) -> int` — distance calc
  - `get_starting_candidates(count) -> Array` — picks good start tiles
  - `_biome_color()` color map (reusable)
- **WorldMapScreen.gd**: Already renders hex grid using Button nodes, color-coded by biome, clickable, with info panel

## Required Changes

### 1. Scene Layout (`WorldGeneration.tscn`)

New layout:

```
┌────────────────────────────────────────────┐
│           WORLD GENERATION                  │
├────────────────────────────────────────────┤
│  Seed: [UNDEREARTH_001] [Random]           │
│  Size: [Small] [Medium] [Large]            │
│  [Generate World]                          │
├──────────────────────┬─────────────────────┤
│                      │  WORLD INFO         │
│     HEX SPHERE       │  Seed: ...          │
│     PREVIEW          │  Tiles: 469         │
│     (clickable)      │  Biomes: ...        │
│                      ├─────────────────────┤
│                      │  SELECTED HEX INFO  │
│                      │  Ash Wastes (0,0)   │
│                      │  Temp: 50%          │
│                      │  Rain: 40%          │
│                      │  Rift: 25%          │
│                      │  Elev: 0.6          │
│                      ├─────────────────────┤
│                      │  [Continue to Char] │
└──────────────────────┴─────────────────────┘
```

- Left 65%: Hex sphere preview (Control with Camera2D for pan/zoom)
- Right 35%: Info panels stacked vertically

### 2. World Size Options

Add `HEX_RADIUS` options to `WorldGenerator`:

| Name | Radius | Approx Hexes | Description |
|---|---|---|---|
| Small | 6 | ~127 | Quick start, less exploration |
| Medium | 12 | ~469 | Current default, balanced |
| Large | 18 | ~1,027 | Maximum variety, longer play |

- Store size in `WorldGenerator.gd` as `_hex_radius` (replaces `const HEX_RADIUS = 12`)
- Pass size to `generate()` as parameter: `func generate(seed, size = 12)`
- The hex generation loop already limits by radius — just change the bound

### 3. Hex Sphere Preview (new scene component or inline)

Options:
- **A) Inline in WorldGeneration.tscn** — simplest, no extra scene
- **B) Separate HexPreviewWidget scene** — reusable, cleaner

Recommend: **A) Inline** with a dedicated `Control` node containing a `Node2D` + `Camera2D`.

Key nodes to add to the scene:
```
WorldGeneration.tscn:
  ContentHBox (HBoxContainer)
    PreviewPanel (Panel/Control, size_flags_horizontal=2)
      HexGrid (Node2D)
        Camera2D (allow zoom/pan)
    SidePanel (Panel/Control, size_flags_horizontal=1)
      WorldInfo (RichTextLabel, scrollable)
      SelectedInfo (RichTextLabel)
      ContinueBtn (Button)
```

Hex rendering logic (in `WorldGeneration.gd`):
```gdscript
func _render_hex_preview() -> void:
    # Clear existing hex nodes
    for c in $ContentHBox/PreviewPanel/HexGrid.get_children():
        if c is Camera2D: continue
        c.queue_free()

    for key in _tile_map.keys():
        var parts = key.split(",")
        var q = int(parts[0])
        var r = int(parts[1])
        var tile = _tile_map[key]
        var pos = WorldGenerator.axial_to_pixel(q, r, HEX_RENDER_SIZE)

        # Create Polygon2D for hex shape
        var poly = Polygon2D.new()
        poly.polygon = _hex_shape(HEX_RENDER_SIZE)
        poly.position = pos
        poly.color = _biome_color(str(tile.get("name", "")))
        poly.modulate = Color(1, 1, 1, 0.9)

        # Highlight if start candidate
        if tile.get("is_start_candidate", false):
            poly.modulate = Color(1, 1, 1, 1)
            # Add subtle border or glow

        # Click detection via area or input
        poly.meta = {"q": q, "r": r, "key": key}
        $ContentHBox/PreviewPanel/HexGrid.add_child(poly)

    # Recenter camera
    var center = WorldGenerator.axial_to_pixel(0, 0, HEX_RENDER_SIZE)
    camera.position = center
```

### 4. Hex Selection via Click

Add input handling to detect which hex was clicked:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var local_pos = $ContentHBox/PreviewPanel/HexGrid.to_local(event.position)
        # Check each hex polygon for hit
        for child in $ContentHBox/PreviewPanel/HexGrid.get_children():
            if child is Polygon2D and child.meta.has("q"):
                var rel = local_pos - child.position
                if Geometry2D.is_point_in_polygon(rel, child.polygon):
                    _select_hex(child.meta.q, child.meta.r)
                    break
```

Or simpler: use `Area2D` + `CollisionPolygon2D` per hex and connect `input_event` signals (more code but cleaner).

### 5. Info Panels

**World Info panel:**
- Seed
- World size (Small/Medium/Large + radius)
- Total hex count
- Biome distribution: "Ash Wastes: 45 tiles, Rust Canyons: 32 tiles, ..."
- Start candidate count

**Selected Hex Info panel:**
- Biome name (color-coded)
- Coordinates (q, r)
- Temperature (0-100%)
- Rainfall (0-100%)
- Elevation (0-1.0)
- Rift chance (0-100%)
- Danger level
- Features list
- Survival risks list

### 6. Files to Create/Modify

| File | Action | Changes |
|---|---|---|
| `scripts/WorldGenerator.gd` | **Modify** | Add `_hex_radius` var, accept size param in `generate()`, expose `hex_shape()` static |
| `scripts/WorldGeneration.gd` | **Modify** | Replace text UI with visual hex preview, add click selection, info panels, size buttons |
| `scenes/WorldGeneration.tscn` | **Modify** | New layout with hex preview + side panel |
| `scripts/WorldGenerationScene.gd` | **Optional** | Could extract hex preview to separate helper |

### 7. Hex Shape Utility (`WorldGenerator.gd`)

```gdscript
static func hex_shape(size: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in 6:
        var angle = deg_to_rad(60.0 * i - 30.0)  # pointy-top
        points.append(Vector2(cos(angle) * size, sin(angle) * size))
    return points
```

### 8. Implementation Order

1. Add hex shape + size parameter to `WorldGenerator.gd`
2. Redesign `WorldGeneration.tscn` scene layout
3. Rewrite `WorldGeneration.gd` with hex rendering, click selection, info panels
4. Test generation with Small/Medium/Large sizes
5. Polish: camera pan/zoom, hex hover effects, selected hex highlight

### 9. Design Notes

- **HEX_RENDER_SIZE**: Use `20.0` for small, `14.0` for medium, `10.0` for large to fit preview
- **Colors**: Reuse `_biome_color()` from WorldMapScreen.gd
- **Start candidates**: Highlight with brighter tint, star icon, or border
- **Selected hex**: Distinct outline or overlay (golden glow)
- **Fog**: Unexplored hexes visible but player starts on chosen one

### 10. Camera Controls (Optional but nice)

- Mouse wheel to zoom in/out on hex preview
- Click-drag to pan
- Reset view button
