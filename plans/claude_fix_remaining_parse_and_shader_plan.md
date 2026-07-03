# Claude Code Fix Plan: Godot Parse/Runtime Errors (from debug console + godot.log)

**Date:** 2026-07-03
**Context:** User provided Godot editor debug console screenshot + path to godot.log showing persistent errors during project load / scene init.
**Main Error (from image):**
```
Invalid assignment of property or key 'shader_code' with value of type 'String' on a base object of type 'ShaderMaterial'.
```
**Stack:**
0. res://scripts/procedural/ProceduralTile.gd:28 - _init()
1-5. LocalMapRenderer -> HubWorld _build_local_view / _ready

**Other errors visible in console (147 total, many parse):**
- Dupe members in ProceduralMob.gd (size, pose_frame, _drawn already in ProceduralRenderer)
- Bad draw calls in ProceduralMob, ProceduralTile, CharacterVisual (wrong types for draw_rect, draw_circle, draw_polygon, PackedVector2Array ctor)
- GraphicsManager not declared / non-static calls in CharacterVisual.gd
- "Unexpected extends" or other syntax in legacy scripts/Procedural*.gd
- Inference warnings treated as errors (Variant types)
- Possible hide/show overrides in ProceduralRenderer
- General cascading parse failures preventing clean load of HubWorld / procedural rendering.

**Note from user:** "your out of credit already" — implement only if simple; otherwise provide this plan. Focus on making editor load clean + no crash on new game -> HubWorld.

## Step-by-Step Plan for Implementation

### Phase 1: Diagnose (Read files + reproduce)
1. Read the full current godot.log (use tail or grep for ERROR / shader_code / Parse).
2. Read these files:
   - scripts/procedural/ProceduralTile.gd (focus _init, any shader use)
   - scripts/procedural/ProceduralMob.gd and scripts/ProceduralMob.gd
   - scripts/procedural/ProceduralRenderer.gd
   - scripts/CharacterVisual.gd
   - scripts/ProceduralTile.gd (legacy top-level)
   - scripts/procedural/ProceduralCharacter.gd (for similar draw issues)
3. Run in Godot: Project reload or run `res://validate_scripts.gd` + force load of the files above. Capture exact current parse errors.
4. Identify if the shader_code line is still present (it shouldn't be after prior edit, but confirm).

### Phase 2: Fix ProceduralTile.gd (the crashing one)
1. In `scripts/procedural/ProceduralTile.gd`:
   - Locate the _init() function.
   - Replace any remaining:
     ```gdscript
     shader = ShaderMaterial.new()
     shader.shader_code = """..."""
     shader.set_shader_param(...)
     ```
     With safe version (or removal):
     ```gdscript
     func _init() -> void:
         # No shader_code on ShaderMaterial in Godot 4.
         # This class uses direct _draw() on Node2D for procedural rendering.
         # If a real ShaderMaterial is ever needed later:
         # var sh := Shader.new()
         # sh.code = """shader_type canvas_item; ..."""
         # shader = ShaderMaterial.new()
         # shader.shader = sh
         shader = ShaderMaterial.new()
     ```
   - Remove any dead shader setup code that isn't used in _draw() or setup_for().
   - Ensure `var shader: ShaderMaterial = null` is kept only if `get_shader_params()` or other code references it.
2. Check if `extends` is correct (currently Node2D after prior changes — good for add_child).
3. Update any calls to set_shader_param -> set_shader_parameter (Godot 4+).

### Phase 3: Fix Duplicate Members + Inheritance Issues
1. In both `scripts/procedural/ProceduralMob.gd` and `scripts/ProceduralMob.gd`:
   - Remove any re-declared:
     ```gdscript
     var size: Vector2 = ...
     var pose_frame: int = ...
     var _drawn: bool = ...
     ```
   - Add comment: `# size, pose_frame, _drawn inherited from ProceduralRenderer`
2. In `scripts/procedural/ProceduralRenderer.gd`:
   - Keep the @warning_ignore for hide/show if still present, or rename internal methods to avoid override warning (e.g. `set_visible_procedural`).
   - Make sure base has:
     ```gdscript
     var size: Vector2 = Vector2(32, 32)
     var pose_frame: int = 0
     var _drawn: bool = false
     var _visible: bool = true
     ```

### Phase 4: Fix Draw API Calls (Godot 4 Signatures)
Search whole `scripts/` for old patterns and fix:

- `draw_rect(Vector2(x,y), w, h, color)` → `draw_rect(Rect2(Vector2(x,y), Vector2(w,h)), color)`
- `draw_circle(x, y, color)` or similar → `draw_circle(Vector2(x,y), radius, color)`
- `draw_polygon(points, color)` → `draw_colored_polygon(points, color)` (preferred) or `draw_polygon(points, PackedColorArray([color]))`
- `PackedVector2Array(v1, v2, ...)` → `PackedVector2Array([v1, v2, ...])`

Affected files (from history + grep):
- All _draw_* in ProceduralMob.gd (both)
- All draw in legacy + procedural ProceduralTile.gd
- ProceduralCharacter.gd (body, heads, lines)
- Any in RiftVisual, ParticleEmitters if still bad (use correct for their context)

Also fix in CharacterVisual.gd any remaining bare draw calls inside _draw().

### Phase 5: Fix GraphicsManager / CharacterVisual Integration
1. In `scripts/GraphicsManager.gd` (the stub):
   - Ensure all methods called from CharacterVisual are `static func`:
     - get_palette_for_biome
     - draw_character_base
     - draw_equipment_layer
     - draw_multiline_path_*
     - advance_frame
     - get_frame_progress
   - Add any missing palette keys used (player_eyes etc.).
2. In `scripts/CharacterVisual.gd`:
   - Keep `const GraphicsManager = preload("res://scripts/GraphicsManager.gd")`
   - Change all `:= ` inferences that cause "Variant" warning to explicit types:
     ```gdscript
     var palette: Dictionary = ...
     var pos: Vector2 = position
     var x: float = ...
     var frame_progress: float = ...
     ```
   - Replace any `get_local_transform().origin` with `position` (already should be).
   - Ensure draw_circle calls use Vector2 + radius.

3. Decide on autoload:
   - Option A (preferred for "bare GraphicsManager" usage): Add back to project.godot autoload if the stub is stable.
   - Option B: Keep preload const everywhere that uses it.
   - Update any other files using bare `GraphicsManager.` (search whole project).

### Phase 6: Clean Legacy Duplicate Files
- `scripts/ProceduralMob.gd` and `scripts/ProceduralTile.gd` (top level) are duplicates of the `procedural/` versions.
- Either:
  a. Delete them (if not referenced by .tscn or preload paths).
  b. Or make them minimal forwards or add `## LEGACY - see scripts/procedural/` and remove conflicting code (class_name if present, bad extends, dupe vars).
- Check references: grep for preload.*Procedural(Mob|Tile) and "extends Procedural".

### Phase 7: Other Parse / Warning Fixes
- Add `@warning_ignore("native_method_override")` or rename methods where needed.
- For any "inferred Variant" warnings treated as errors: add explicit types.
- In LocalMapRenderer.gd: update comments (it mentions "CanvasTexture" wrapper — update since it's now Node2D).
- Ensure all procedural files that extend ProceduralRenderer have `class_name` only on the canonical ones.
- Fix any remaining PackedVector2Array or draw_polygon in other procedural/ files.

### Phase 8: Verification Steps (Claude must do these)
1. In Godot editor: **Project → Reload Current Project**.
2. Check **Debugger** (Errors tab) and **Output** — should have 0 of the previous shader_code / dupe / draw signature errors.
3. Run `res://validate_scripts.gd` (via --script or in editor) — expect "All scripts and scenes OK".
4. Run the game:
   - New Game → World Gen → choose tile → HubWorld.
   - Confirm no crash in LocalMapRenderer / ProceduralTile.new().
   - Check for visual tiles rendering (even if stubbed).
5. If still errors, capture new screenshot of debug console + godot.log and iterate.

### Phase 9: Bonus / Polish (if time)
- Make draw calls consistent (perhaps add helper methods in ProceduralRenderer for draw_rect_vec etc. during transition).
- Remove or properly implement the shader in ProceduralTile if it's intended for future (e.g. for texture generation).
- Consider moving all procedural draw code to use a consistent helper.

## Files to Touch (priority order)
1. scripts/procedural/ProceduralTile.gd
2. scripts/procedural/ProceduralMob.gd + scripts/ProceduralMob.gd
3. scripts/procedural/ProceduralRenderer.gd
4. scripts/CharacterVisual.gd
5. scripts/GraphicsManager.gd (stub)
6. scripts/ProceduralTile.gd (legacy)
7. project.godot (autoload if needed)
8. scripts/LocalMapRenderer.gd (comments)
9. Other procedural/*.gd for draw consistency

## Expected Outcome
- Editor debug console shows far fewer (or 0) of the 147 errors related to these.
- Game starts cleanly into HubWorld without the stack trace.
- Procedural tiles/characters can be instantiated without crash.

Write the actual edits as small, targeted search_replace or direct writes. Test after each phase.

If a step is ambiguous (e.g. "should we keep the shader?"), default to removing dead code that crashes and leave a comment for future.

Start with Phase 1 diagnostics on the live files.