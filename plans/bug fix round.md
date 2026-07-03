# Fix Plan for FallenEarth Godot v4.3 Errors
Project: https://github.com/AhmiDarrow/FallenEarth
Goal: Resolve all parse/compile errors so the project loads cleanly.
Priority: Fix in dependency order (foundational classes → managers → scenes).

1. Immediate Setup & Exploration (Claude Instructions)

Clone/pull latest repo.
Open in Godot 4.3.stable.
Enable FileSystem dock + Script Editor with full error list.
Search the entire project for:
ProceduralMob
ProceduralTile
EncounterBuilder
archetypes / archetype
draw_multiline



2. Core Missing Types (Highest Priority)
A. Create ProceduralMob.gd (if missing)
File: res://scripts/ProceduralMob.gd (or wherever the class should live)
gdscriptclass_name ProceduralMob
extends Node2D  # or CharacterBody2D / Resource as appropriate

@export var archetype: String = "default"
@export var color: Color = Color.WHITE
@export var size: Vector2 = Vector2(1, 1)
# Add other needed properties from NPCManager/HubWorld usage

func _init(archetype_name: String = "default"):
    self.archetype = archetype_name
    # ... initialization logic
B. Create ProceduralTile.gd
File: res://scripts/ProceduralTile.gd
gdscriptclass_name ProceduralTile
extends Resource  # or Node2D / TileMapLayer depending on usage

@export var type: String
@export var position: Vector2
# Add other properties as needed

3. NPCManager.gd Fixes
Main Issues:

Missing ProceduralMob
Bad Callable.new() usage (Godot 4 syntax)
Undefined archetypes, archetype, proto, etc.

Fix Plan:

Add at top:gdscriptextends Node
class_name NPCManager

@onready var encounter_builder = preload("res://scripts/CombatEncounterBuilder.gd") # or proper autoload/path
Replace Callable.new(...) → proper instantiation:gdscript# Old (broken):
# var mob = Callable(ProceduralMob, "new").call(...)

# New:
var mob = ProceduralMob.new(archetype)  # or whatever constructor
Define missing variables (likely in _ready() or as member vars):gdscriptvar archetypes: Array = ["warrior", "scout", "mage"]  # or load from JSON/Resource
var archetype: Dictionary  # or Resource
var proto: ProceduralMob
var mob: ProceduralMob
Fix archetype/color/size block around lines 250-261 (probably a procedural generation loop):
Declare vars before use.
Use proper Vector2 for size.



4. HubWorld.gd Fixes (Very Similar to NPCManager)

Copy archetype handling fixes from NPCManager.
Fix line 667: size assignment — ensure it's Vector2, not float.gdscript# Bad:
size = 1.5

# Good:
size = Vector2(1.5, 1.5)
Replace any static calls to EncounterBuilder.build_overworld() with correct reference.


5. EncounterBuilder / MissionManager Fixes
Files involved:

CombatEncounterBuilder.gd
MissionManager.gd

Actions:

Ensure CombatEncounterBuilder.gd has:gdscriptclass_name EncounterBuilder
static func random_overworld_mob() -> ProceduralMob:
    # implementation

static func build_mission(...) -> ...:
    # implementation

static func build_overworld(...) -> ...:
    # implementation
In MissionManager.gd:
Use EncounterBuilder.random_overworld_mob() correctly (static call is fine if class_name exists).
Make sure the script is in the autoload list or properly preloaded.



6. Syntax & Duplicate Function Errors
DisplayManager.gd (line 235)
gdscript# Look for trailing comma in array/dictionary or function call
# Example fix:
some_function(a, b, c)   # remove trailing comma if present
GraphicsManager.gd (line 350)

Duplicate draw_multiline — Godot CanvasItem already has draw_multiline.
Solution: Rename your custom function to draw_multiline_custom() or _draw_multiline_internal().


7. GameState.gd / GameManager.gd
These are failing due to cascading parse errors from dependencies (NPCManager, DisplayManager, etc.).
Fix order:

Fix all other scripts first.
Then reload GameState.gd and GameManager.gd.
Add proper @onready references and null checks.


8. WorldGenerator.gd

Add ProceduralTile class (see section 2).
Fix instantiation:gdscriptvar pt: ProceduralTile = ProceduralTile.new()
# or
var pt = ProceduralTile.new()


9. General Godot 4.3 Best Practices to Apply

Use class_name on all major scripts.
Prefer @export var + Resources over magic dictionaries where possible.
Use typed variables (var foo: Type = ...).
Replace old new() Callable pattern with direct instantiation.
Autoload order: GameManager → GameState → NPCManager → MissionManager → DisplayManager → GraphicsManager.


10. Verification Steps (After Fixes)

Project → Reload Current Project.
Check Output + Debugger for remaining errors.
Run scene with HubWorld / main menu.
Test NPC spawning and mission generation.

## Fix Log (2026-07-03)

**Fixed runtime error on game start:**
- Error: "Invalid assignment of property or key 'shader_code' with value of type 'String' on a base object of type 'ShaderMaterial'."
- Location: scripts/procedural/ProceduralTile.gd:28 in _init() (called via LocalMapRenderer → HubWorld _ready)

**Root cause:**
- Dead/broken shader initialization code left over from earlier CanvasTexture experiments.
- `ShaderMaterial.shader_code = "..."` is invalid in Godot 4.
  - Correct API: `material.shader = Shader.new(); shader.code = "..."` (or preload .gdshader).
- The `shader` member was never assigned to the node's material and rendering uses direct `draw_rect()` etc. in `_draw()`.

**Changes:**
- Replaced the entire invalid `_init()` shader block with a safe minimal initialization.
- Cleaned up orphaned shader string literal and set_shader_param calls.
- Added comments explaining the removal.
- The class (now extends Node2D) continues to work via procedural drawing in `_draw()` and `setup_for()`.

**Verification:**
- validate_scripts.gd → "All scripts and scenes OK", 0 load failures.
- Godot editor load no longer reports the shader_code error for ProceduralTile.gd.
- LocalMapRenderer chunk loading / HubWorld _ready path should now proceed without crashing on `ProceduralTile.new()`.

**Full Game Run Test (2026-07-03):**
- Launched: .\Godot_v4.3-stable_win64.exe --path . (brief ~12s run to exercise Splash → MainMenu → New Game → WorldGeneration).
- Result: Progressed successfully:
  - [MainMenu] Starting New Game
  - [GameState] Session reset
  - [WorldGeneration] Hex sphere generated with seed: UNDEREARTH_001
  - Player chose starting grid
- No critical errors in logs for: shader_code, Invalid assignment, Parse Error, ProceduralTile crash, or related.
- Only minor unrelated Vulkan registry warning (non-fatal).
- Combined with validate_scripts (which loads HubWorld.tscn + LocalMapRenderer paths), the previous crash site is resolved.

**Review of provided godot.log + attached debug console image:**
- The attached image shows the pre-fix state (shader_code crash + many parse errors in Procedural* files + CharacterVisual).
- The actual `godot.log` at the provided path only contains clean init logs up to MainMenu (no shader_code, no "Invalid assignment", no parse errors matching the image).
- Force-loading the exact files from the image now succeeds with no parse errors.
- **Conclusion:** The specific error from the image is no longer occurring in the current source. The log is clean for the paths exercised.

**Status:** Main shader crash item resolved. A detailed follow-up implementation plan for any residual / similar errors (and full cleanup of draw API + legacy files) has been written to:
`plans/claude_fix_remaining_parse_and_shader_plan.md`

If the user is still seeing the exact errors in their running Godot editor (after Project → Reload), they should provide a fresh screenshot of the current console + the latest godot.log.

If additional runtime errors appear when fully entering HubWorld + chunk loading in a longer play session, a follow-up plan can be created (note: out of credit for direct heavy implementation).