class_name ButtonStyleHelper
extends RefCounted

const MT := preload("res://assets/ui/MasterTheme.gd")

static func apply_style(btn: Button, style_key: String = "primary") -> void:
	MT.apply_button_style(btn, style_key)

static func apply_primary(btn: Button) -> void:
	MT.apply_primary(btn)

static func apply_secondary(btn: Button) -> void:
	MT.apply_secondary(btn)

static func apply_danger(btn: Button) -> void:
	MT.apply_danger(btn)

static func apply_success(btn: Button) -> void:
	MT.apply_success(btn)

static func apply_ghost(btn: Button) -> void:
	MT.apply_ghost(btn)

static func apply_focus(control: Control) -> void:
	MT.apply_focus(control)

static func get_available_styles() -> Array[String]:
	return MT.get_button_styles()

static func apply_all_states(btn: Button, variant: String) -> void:
	MT.apply_button_style(btn, variant)
