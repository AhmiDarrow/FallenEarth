# Fix Plan for FallenEarth Godot 4.3 Parse/Compile Errors
Project Context: https://github.com/AhmiDarrow/FallenEarth
Style: Coder + Designer — clean, modular, performant GDScript with strong typing, clear separation of concerns, and maintainable procedural systems.

1. Overall Strategy (Prioritized)

Fix root class definitions first (ProceduralMob, ProceduralTile, EncounterBuilder).
Resolve missing types/constants/references.
Fix scoping and variable declaration issues.
Update static calls and autoload dependencies.
Clean up syntax & duplicate declarations.
Test incrementally (single script → autoloads → scene loads).

Goal: Make the project compile cleanly, then restore/strengthen procedural NPC/mission/world generation.

2. Critical Missing Classes
ProceduralMob

Issue: Referenced in NPCManager.gd, HubWorld.gd, WorldGenerator.gd but not found.
Action:
Create res://scripts/ProceduralMob.gd (or move if it exists elsewhere).
Make it a @global_class or properly registered.
Suggested skeleton:


gdscript@global_class
class_name ProceduralMob
extends Node2D  # or Resource if data-only

@export var archetype: String = "default"
@export var color: Color = Color.WHITE
@export var size: Vector2 = Vector2.ONE

# Procedural generation logic...
func generate_from_archetype(archetype_data: Dictionary) -> void:
    pass
ProceduralTile

Issue: WorldGenerator.gd can't parse it.
Action: Ensure res://scripts/ProceduralTile.gd exists and is clean (no parse errors).

EncounterBuilder

Issue: Missing static methods random_overworld_mob(), build_mission(), build_overworld().
Action: Create/fix res://scripts/CombatEncounterBuilder.gd (noted as failing to compile).


3. NPCManager.gd Fixes (High Priority)
Errors Summary:

Missing ProceduralMob
Callable.new() misuse
Undeclared archetypes, archetype, color, size, proto, mob

Fix Steps:

Add proper class references at top:

gdscriptextends Node

@export var ProceduralMobScene: PackedScene  # or preload
var archetypes: Dictionary = {}  # or load from JSON/Resource

Fix line 65 (likely instantiation):

gdscript# Bad: Callable.new()
# Good:
var mob = ProceduralMob.new()  # or ProceduralMobScene.instantiate()

Scope the archetype loop properly (lines 250-261):

gdscriptfor archetype_name in archetypes.keys():
    var archetype: Dictionary = archetypes[archetype_name]
    var color: Color = archetype.get("color", Color.WHITE)
    var size: Vector2 = archetype.get("size", Vector2.ONE)
    # ...

Fix prototype/mob creation (lines 270+):

gdscriptvar proto: Dictionary = archetype  # or specific proto
var mob: ProceduralMob = ProceduralMob.new()
# configure mob...
add_child(mob)
Design Note: Use @export var mob_archetypes: Array[Resource] for editor-friendliness.

4. MissionManager.gd & HubWorld.gd
MissionManager:

Replace static calls:

gdscript# Instead of EncounterBuilder.random_overworld_mob()
var builder = EncounterBuilder.new()  # or make singleton/autoload
var mob = builder.random_overworld_mob()
HubWorld.gd:

Same archetype scoping fix as NPCManager.
Line 667: Vector2 assignment error → ensure correct type (likely scale = Vector2(...)).


5. Other Scripts
DisplayManager.gd

Line 235: Trailing comma in expression → remove it.

GraphicsManager.gd

Duplicate draw_multiline → rename one (e.g. draw_multiline_custom) or use Godot's built-in properly.

GameState.gd / GameManager.gd

Fix dependencies (will resolve once children compile).

WorldGenerator.gd

Fix ProceduralTile reference.
Type inference: var pt: ProceduralTile = ProceduralTile.new()


6. General GDScript Best Practices (Apply Across Project)

Add class_name + @global_class where appropriate.
Use strong typing everywhere (: Dictionary, : Color, etc.).
Prefer Resources over Dictionaries for archetypes.
Autoload order: Fix load failures by resolving dependencies.
Use preload() for scenes/scripts.
Run Project > Reload Current Project after each major fix.


7. Validation & Testing Plan

Fix ProceduralMob.gd + ProceduralTile.gd.
Fix NPCManager.gd → test autoload.
Fix EncounterBuilder + MissionManager.
Fix HubWorld + WorldGenerator.
Clear Godot cache (Project > Project Settings > reload).
Run scene with NPC spawning / world gen.
Add unit tests or simple debug prints for procedural output.