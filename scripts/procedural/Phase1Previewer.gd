## Phase1Previewer — Validates the Phase 1 procedural foundation.
##
## Loads appearance.json visual_presets, creates one EntityVisualComponent per
## preset laid out on a grid, and adds a single shared Entity3DWorld so every
## entity is drawn by the 3D SubViewport. Buttons let you cycle animation states
## and toggle hover/faction tint to confirm the material variants work.
extends Control

const EntityVisualComponent := preload("res://scripts/procedural/EntityVisualComponent.gd")

var _components: Array = []
var _state: int = 0
var _presets: Dictionary = {}

@onready var grid := $ScrollContainer/GridContainer
@onready var info := $InfoLabel


func _ready() -> void:
	var file := FileAccess.open("res://data/appearance.json", FileAccess.READ)
	if file == null:
		info.text = "Could not open appearance.json"
		return
	var parsed: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
	if typeof(parsed) != TYPE_DICTIONARY:
		info.text = "appearance.json parse error"
		return
	_presets = parsed.get("visual_presets", {})

	var idx := 0
	for preset_name in _presets.keys():
		var data: Dictionary = _presets[preset_name]
		data["variation_seed"] = 1000 + idx
		var comp := EntityVisualComponent.new()
		comp.configure(data, "preview", 96.0)
		var cell := Node2D.new()
		cell.position = Vector2(40 + (idx % 6) * 90, 40 + (idx / 6) * 110)
		cell.add_child(comp)
		grid.add_child(cell)
		_components.append(comp)
		idx += 1
	info.text = "Loaded %d visual presets. Use buttons to drive states." % _components.size()


func _on_idle_pressed() -> void:
	_state = 0
	for c in _components:
		c.set_state(0)


func _on_walk_pressed() -> void:
	_state = 1
	for c in _components:
		c.set_state(1)


func _on_combat_pressed() -> void:
	_state = 2
	for c in _components:
		c.set_state(2)


func _on_dead_pressed() -> void:
	_state = 3
	for c in _components:
		c.set_state(3)


func _on_hover_toggled(toggled_on: bool) -> void:
	for c in _components:
		c.set_hover(toggled_on)


func _on_faction_toggled(toggled_on: bool) -> void:
	for c in _components:
		if toggled_on:
			c.set_faction_tint(Color(1.0, 0.3, 0.3), 0.4)
		else:
			c.set_faction_tint(Color.WHITE, 0.0)
