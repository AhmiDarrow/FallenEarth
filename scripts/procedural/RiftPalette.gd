## RiftPalette — Color settings per rift type.
extends RefCounted

signal current_type_changed(type: int)

@export var void: Dictionary = {
	"bg": Color(0.12, 0.10, 0.14),
	"glow": Color(0.30, 0.25, 0.45),
	"rim": Color(0.0, 0.0, 0.0),
}

@export var life: Dictionary = {
	"bg": Color(0.08, 0.18, 0.10),
	"glow": Color(0.20, 0.55, 0.35),
	"rim": Color(0.15, 0.25, 0.12),
}

@export var energy: Dictionary = {
	"bg": Color(0.10, 0.12, 0.30),
	"glow": Color(0.45, 0.35, 0.90),
	"rim": Color(0.18, 0.22, 0.45),
}

var _current: Dictionary = {}

func set_current_type(type: int) -> void:
	_current = {
		"void": void,
		"life": life,
		"energy": energy,
	}.get(str(type), {})
	current_type_changed.emit(type)
