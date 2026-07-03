## ProceduralRenderer — Base class for all procedurally drawn entities.
## Extend this for Characters, Mobs, Tiles, Equipment, UI elements.
## Autoload singleton pattern: instance in scene graph, call .draw() / .hide().

class_name ProceduralRenderer
extends Node2D

const COLORS = preload("res://scripts/procedural/Palette.gd").COLORS

# Metadata passed in by caller
var entity_type: String = ""
var size: Vector2 = Vector2(32, 32)
var variant: int = 0
var pose_frame: int = 0

# Runtime state
var _visible: bool = true
var _drawn: bool = false

# Hook for subclasses to prepare their specific draw data
func _setup() -> void:
	pass

# Process hook — animation, state updates
func _process(delta: float) -> void:
	pass

# Cleanup hook
func _exit() -> void:
	pass

# Main draw entry — called from ProceduralRendererContainer
func draw() -> void:
	if not _visible:
		return
	_setup()
	_draw()
	_drawn = true

@warning_ignore("native_method_override")
func hide() -> void:
	_visible = false
	_drawn = false

@warning_ignore("native_method_override")
func show() -> void:
	_visible = true
	if _drawn:
		_draw()

# -------------------------------------------------------------------------
# Abstract draw implementation — subclasses override this.
# -------------------------------------------------------------------------
func _draw() -> void:
	pass
