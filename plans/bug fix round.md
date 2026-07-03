# Godot 4.3 Compile & Parse Error Fix Plan (for Claude / Multi-Agent Remedy)
Project Context: FallenEarth — procedural grimdark RPG with hex world gen, hand-drawn assets, and heavy procedural graphics. Style: Coder + Designer (clean, performant, thematic consistency).
Goal: Make the project compile cleanly in Godot 4.3.stable. Prioritize root causes (ProceduralTile + GraphicsManager) to unblock dependents (WorldGenerator, LocalMapRenderer, autoloads, etc.). Then fix cascading issues.
C:\Users\Administrator\FallenEarth


1. Root Cause Analysis (Prioritized)
Critical Blocking Issues

ProceduralTile.gd (class_name parse failure)
extends CanvasTexture + complex shader/draw logic.
Godot parser fails to register class_name ProceduralTile → breaks WorldGenerator.gd:238-239 (var pt := ProceduralTile.new()) and LocalMapRenderer.gd.
Likely syntax/shader issues or missing class_name visibility.

GraphicsManager.gd (autoload)
Massive parse errors: NoiseTexture, Noise.TYPE_SIMPLE, drawing funcs (draw_* only on CanvasItem), const init, hash_string(), type inference.
Breaks autoload loading → many managers fail.

DisplayManager.gd:234 — Syntax: extra comma after expression.
Cascading Compile Errors — NPC*/Mission*/GameState*/HubWorld*/GameManager* fail due to dependency chain.


2. Step-by-Step Fix Plan
Phase 1: Fix ProceduralTile.gd (Highest Priority)

Open res://scripts/ProceduralTile.gd.
Ensure top:gdscriptclass_name ProceduralTile
extends CanvasTexture  # Confirm this is correct; CanvasTexture may need specific handling
Shader & Draw Fixes:
Move complex shader creation to _ready() or a dedicated generate() method. Avoid heavy work in class definition.
Replace invalid draw_* calls if not in a CanvasItem context (many are called from non-drawing nodes). Use Image/ImageTexture for procedural tiles or ensure called in _draw().
Fix draw_polygon / line calls — ensure proper args.
Add explicit tool mode if editor preview needed.

Test: Reload script, check for "global class" registration in editor Output.

Claude Prompt Snippet:
Fix ProceduralTile.gd so class_name parses cleanly. Resolve all shader param sets and draw calls. Ensure ProceduralTile.new() works in WorldGenerator.
Phase 2: Fix GraphicsManager.gd

Constants & Seed:
Replace const UNDEREARTH_GRIM_HAND_2026_v1 := randf() (not constant) → move to _ready().
hash_string() → use str(...).hash() or hash() builtin.

NoiseTexture Fixes (Godot 4.x):
NoiseTexture is under NoiseTexture2D in newer Godot? Confirm with class_name or preload.
noise.noise_type = Noise.TYPE_SIMPLE → noise.noise = FastNoiseLite.new() or correct enum (check docs: often Noise resource).
Declare vars with types: var noise_tex: NoiseTexture2D.

Drawing Functions:
draw_multiline*, draw_circle, draw_rect, draw_line, draw_texture only available in CanvasItem (_draw() override).
Refactor helpers to take a CanvasItem target or return Image for texture baking.
Example refactor:gdscriptfunc draw_character_base(ci: CanvasItem, x: float, y: float, ...) -> void:
    ci.draw_multiline(...)

Type Safety:
Add explicit types everywhere (: Color, : Dictionary, etc.).
Suppress Variant warnings by typing.


Claude Prompt Snippet:
Refactor GraphicsManager.gd as autoload. Fix all NoiseTexture/Noise issues, move non-const to runtime, make draw helpers CanvasItem-aware. Preserve grim hand-drawn aesthetic.
Phase 3: Quick Syntax Fixes

DisplayManager.gd:234: Remove stray comma. Likely in a function call or array.
Scan other files for trailing commas, missing : in typed vars, etc.

Phase 4: Dependency & Autoload Cleanup

Fix WorldGenerator.gd:
After ProceduralTile fixed: var pt: ProceduralTile = ProceduralTile.new()
Ensure class_name in dependents.

Update autoloads in project.godot if needed (re-add after compile success).
Run validate_scripts.gd or project check.


3. Verification Steps (Post-Fix)

Editor: Project → Reload Current Project.
Run: F6 (Main scene) or specific tests (test_asset_loads.gd, validate_scripts.gd).
Check Output for remaining parse/compile errors.
Test procedural tile rendering in LocalMapRenderer / HubWorld.
Git: Commit per phase with clear messages.


4. Design/Coder Principles to Follow

Performance: Bake textures where possible; avoid per-frame heavy shaders.
Thematic Consistency: Keep "UNDEREARTH_GRIM_HAND_2026" grimdark ink/cross-hatch style.
Modularity: Separate drawing logic from data gen.
Godot 4.3 Best Practices: Use typed GDScript, proper Resource inheritance, avoid circular deps.
Error Resilience: Add push_error + fallbacks.


5. Potential Gotchas & Tools

Circular Dependencies: Check imports between WorldGenerator, GraphicsManager, ProceduralTile.
Editor Cache: Delete .godot/ folder if parser stuck.
Noise API: May need FastNoiseLite + NoiseTexture2D in 4.3.
CanvasTexture: Verify usage — often for custom materials.

Next Action for Claude: Start with ProceduralTile.gd full rewrite/fix, then GraphicsManager. Ping with diff or updated files.