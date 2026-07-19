## UI_Theme — Delegates to MasterTheme. Kept for backward compatibility.
class_name UI_Theme
extends RefCounted

const MT := preload("res://assets/ui/MasterTheme.gd")

static func apply_to(window: Window) -> void:
	MT.apply_to(window)

static func apply_to_control(control: Control) -> void:
	MT.apply_theme_to_control(control)
