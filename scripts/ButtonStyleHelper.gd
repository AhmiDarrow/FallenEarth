## ButtonStyleHelper — Applies pixel art button textures to UI buttons.
##
## Provides static methods to style Godot Button nodes with the
## post-apocalyptic button asset set from the UI Design System.
## All four states (normal, hover, pressed, disabled, focus) are set.
class_name ButtonStyleHelper
extends RefCounted

const UI := preload("res://assets/ui/UI_Colors.gd")
const SB := preload("res://scripts/StyleBoxHelper.gd")

# Button texture paths
const TEXTURES := {
	"primary":   "res://assets/sprites/ui/buttons/button_primary.png",
	"secondary": "res://assets/sprites/ui/buttons/button_secondary.png",
	"danger":    "res://assets/sprites/ui/buttons/button_danger.png",
	"success":   "res://assets/sprites/ui/buttons/button_success.png",
}


## Apply a button style to a Button node.
## style_key: "primary", "secondary", "danger", "success", "ghost"
static func apply_style(btn: Button, style_key: String = "primary") -> void:
	if btn == null:
		return

	var tex_path: String = TEXTURES.get(style_key, TEXTURES["primary"])
	var tex: Texture2D = null

	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)

	var text_color := UI.TEXT_PRIMARY
	if tex != null:
		var margin := 8
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style_tex := StyleBoxTexture.new()
			style_tex.texture = tex
			style_tex.texture_margin_left = margin
			style_tex.texture_margin_top = margin
			style_tex.texture_margin_right = margin
			style_tex.texture_margin_bottom = margin
			if state_name == "disabled":
				style_tex.modulate_color = Color(0.4, 0.4, 0.4, 0.5)
			btn.add_theme_stylebox_override(state_name, style_tex)
		var style_data: Dictionary = UI.button_style(style_key)
		text_color = style_data.get("text", UI.TEXT_PRIMARY)
	else:
		var style_data: Dictionary = UI.button_style(style_key)
		text_color = style_data.get("text", UI.TEXT_PRIMARY)
		btn.add_theme_stylebox_override("normal", SB.button(style_key, "normal"))
		btn.add_theme_stylebox_override("hover", SB.button(style_key, "hover"))
		btn.add_theme_stylebox_override("pressed", SB.button(style_key, "pressed"))
		btn.add_theme_stylebox_override("disabled", SB.button(style_key, "disabled"))
		btn.add_theme_stylebox_override("focus", SB.button(style_key, "focus"))

	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", UI.TEXT_MUTED)
	btn.add_theme_font_size_override("font_size", UI.FS_BUTTON)


## Apply primary style (default).
static func apply_primary(btn: Button) -> void:
	apply_style(btn, "primary")


## Apply secondary style.
static func apply_secondary(btn: Button) -> void:
	apply_style(btn, "secondary")


## Apply danger style.
static func apply_danger(btn: Button) -> void:
	apply_style(btn, "danger")


## Apply success style.
static func apply_success(btn: Button) -> void:
	apply_style(btn, "success")


## Apply ghost style (no background, text only).
static func apply_ghost(btn: Button) -> void:
	apply_style(btn, "ghost")


## Check if button textures exist.
static func textures_exist() -> bool:
	for path in TEXTURES.values():
		if not ResourceLoader.exists(path):
			return false
	return true


## Get list of available button styles.
static func get_available_styles() -> Array[String]:
	return ["primary", "secondary", "danger", "success", "ghost"]


## Apply focus stylebox to any Control node.
static func apply_focus(control: Control) -> void:
	control.add_theme_stylebox_override("focus", SB.focus_ring())


## Convenience: set all five states on a Button using the same variant.
static func apply_all_states(btn: Button, variant: String) -> void:
	apply_style(btn, variant)
