## RiftPalette — Color settings per rift type.
extends RefCounted

signal current_type_changed(type: int)

@export var rift_void: Dictionary = {
	"bg": Color(0.12, 0.10, 0.14),
	"glow": Color(0.30, 0.25, 0.45),
	"rim": Color(0.0, 0.0, 0.0),
}

@export var rift_life: Dictionary = {
	"bg": Color(0.08, 0.18, 0.10),
	"glow": Color(0.20, 0.55, 0.35),
	"rim": Color(0.15, 0.25, 0.12),
}

@export var rift_energy: Dictionary = {
	"bg": Color(0.10, 0.12, 0.30),
	"glow": Color(0.45, 0.35, 0.90),
	"rim": Color(0.18, 0.22, 0.45),
}

var _palettes: Array[Dictionary] = []
var _current: Dictionary = {}

func _init() -> void:
	_palettes = [rift_void, rift_life, rift_energy]

func set_current_type(type: int) -> void:
	if type >= 0 and type < _palettes.size():
		_current = _palettes[type]
	current_type_changed.emit(type)

func get_current() -> Dictionary:
	return _current

func get_bg() -> Color:
	return _current.get("bg", Color.BLACK)

func get_glow() -> Color:
	return _current.get("glow", Color.WHITE)

func get_rim() -> Color:
	return _current.get("rim", Color.GRAY)
