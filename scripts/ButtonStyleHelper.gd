## ButtonStyleHelper — Applies pixel art button textures to UI buttons.
##
## Provides static methods to style Godot Button nodes with the
## post-apocalyptic button asset set.
class_name ButtonStyleHelper
extends RefCounted

# Button texture paths
const TEXTURES := {
	"primary":   "res://assets/sprites/ui/buttons/button_primary.png",
	"secondary": "res://assets/sprites/ui/buttons/button_secondary.png",
	"danger":    "res://assets/sprites/ui/buttons/button_danger.png",
	"success":   "res://assets/sprites/ui/buttons/button_success.png",
}

# StyleBoxFlat for each button type (fallback if textures fail)
const STYLES := {
	"primary": {
		"bg_color": Color(0.2, 0.15, 0.3, 1),
		"border_color": Color(0.8, 0.5, 0.2, 1),
	},
	"secondary": {
		"bg_color": Color(0.15, 0.15, 0.18, 1),
		"border_color": Color(0.3, 0.5, 0.7, 1),
	},
	"danger": {
		"bg_color": Color(0.4, 0.1, 0.1, 1),
		"border_color": Color(0.6, 0.2, 0.2, 1),
	},
	"success": {
		"bg_color": Color(0.1, 0.3, 0.15, 1),
		"border_color": Color(0.2, 0.6, 0.3, 1),
	},
}


## Apply a button style to a Button node.
## style_key: "primary", "secondary", "danger", or "success"
static func apply_style(btn: Button, style_key: String = "primary") -> void:
	if btn == null:
		return

	var tex_path: String = TEXTURES.get(style_key, TEXTURES["primary"])
	var tex: Texture2D = null

	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)

	if tex != null:
		# Create StyleBoxTexture with the button texture
		var style_normal := StyleBoxTexture.new()
		style_normal.texture = tex
		style_normal.texture_margin_left = 8
		style_normal.texture_margin_top = 8
		style_normal.texture_margin_right = 8
		style_normal.texture_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", style_normal)

		# Create pressed style (slightly darker)
		var style_pressed := StyleBoxTexture.new()
		style_pressed.texture = tex
		style_pressed.texture_margin_left = 8
		style_pressed.texture_margin_top = 8
		style_pressed.texture_margin_right = 8
		style_pressed.texture_margin_bottom = 8
		btn.add_theme_stylebox_override("pressed", style_pressed)

		# Create hover style
		var style_hover := StyleBoxTexture.new()
		style_hover.texture = tex
		style_hover.texture_margin_left = 8
		style_hover.texture_margin_top = 8
		style_hover.texture_margin_right = 8
		style_hover.texture_margin_bottom = 8
		btn.add_theme_stylebox_override("hover", style_hover)
	else:
		# Fallback to StyleBoxFlat
		var style_data: Dictionary = STYLES.get(style_key, STYLES["primary"])
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = style_data.get("bg_color", Color(0.2, 0.15, 0.3, 1))
		style_normal.border_color = style_data.get("border_color", Color(0.6, 0.5, 0.8, 1))
		style_normal.set_border_width_all(2)
		style_normal.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style_normal)

	# Set font color based on style
	match style_key:
		"primary":
			btn.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		"secondary":
			btn.add_theme_color_override("font_color", Color(0.8, 0.85, 1))
		"danger":
			btn.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
		"success":
			btn.add_theme_color_override("font_color", Color(0.9, 1, 0.9))


## Apply primary style (default)
static func apply_primary(btn: Button) -> void:
	apply_style(btn, "primary")


## Apply secondary style
static func apply_secondary(btn: Button) -> void:
	apply_style(btn, "secondary")


## Apply danger style
static func apply_danger(btn: Button) -> void:
	apply_style(btn, "danger")


## Apply success style
static func apply_success(btn: Button) -> void:
	apply_style(btn, "success")


## Check if button textures exist
static func textures_exist() -> bool:
	for path in TEXTURES.values():
		if not ResourceLoader.exists(path):
			return false
	return true


## Get list of available button styles
static func get_available_styles() -> Array[String]:
	return ["primary", "secondary", "danger", "success"]
