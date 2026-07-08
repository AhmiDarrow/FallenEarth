## UIBackgrounds — Applies pixel-art background textures to UI panels.
##
## Replace plain ColorRect backgrounds with styled StyleBoxTexture
## from the generated pixel art asset set.
class_name UIBackgrounds
extends RefCounted

const UI := preload("res://assets/ui/UI_Colors.gd")

# Texture paths (loaded lazily via _tex helper)
const TEX_PATHS := {
	"bg_modal": "res://assets/ui/bg_modal.png",
	"bg_panel": "res://assets/ui/bg_panel.png",
	"bg_tooltip": "res://assets/ui/bg_tooltip.png",
	"bg_hud_bar": "res://assets/ui/bg_hud_bar.png",
	"bg_inventory_cell": "res://assets/ui/bg_inventory_cell.png",
	"bg_side_panel": "res://assets/ui/bg_side_panel.png",
}


static func _tex(key: String) -> Texture2D:
	var path := str(TEX_PATHS.get(key, ""))
	if path.is_empty():
		push_error("[UIBackgrounds] Unknown texture key: %s" % key)
		return null
	if not ResourceLoader.exists(path):
		push_warning("[UIBackgrounds] Texture not found: %s" % path)
		return null
	return load(path) as Texture2D


## Create a styled TextureRect from a background texture.
## Attach it to `parent` as a full-screen overlay.
static func add_texture_overlay(parent: Node, texture_key: String,
		modulate: Color = Color(0.6, 0.6, 0.65, 0.5), index: int = -1) -> TextureRect:
	var tex := _tex(texture_key)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.modulate = modulate
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	if index >= 0:
		parent.move_child(tr, index)
	return tr


## Create a StyleBoxTexture from a background texture key.
static func make_stylebox(texture_key: String, margin: int = 16,
		modulate: Color = Color(0.6, 0.6, 0.65, 0.5)) -> StyleBoxTexture:
	var tex := _tex(texture_key)
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.modulate_color = modulate
	return sb


## Apply modal background behind a ColorRect.
## Makes the ColorRect semi-transparent so the texture shows through.
static func apply_modal_bg(rect: ColorRect) -> void:
	var parent := rect.get_parent()
	if parent == null:
		return
	# Add tiled texture overlay behind the ColorRect — very subtle
	var tr := add_texture_overlay(parent, "bg_modal", Color(0.5, 0.5, 0.55, 0.15))
	if tr != null:
		parent.move_child(tr, rect.get_index())
		# Keep ColorRect mostly opaque so the dark overlay dominates
		rect.color.a = min(rect.color.a, 0.55)


## Apply HUD bar texture. If `rect` is a TextureRect, sets its texture directly.
## If `rect` is a ColorRect, creates a TextureRect sibling with matching layout.
static func apply_hud_bar(rect: Control) -> void:
	var tex := _tex("bg_hud_bar")
	if tex == null:
		return
	if rect is TextureRect:
		(rect as TextureRect).texture = tex
		return
	if not (rect is ColorRect):
		return
	var cr := rect as ColorRect
	var parent := cr.get_parent()
	if parent == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.anchor_left = cr.anchor_left
	tr.anchor_top = cr.anchor_top
	tr.anchor_right = cr.anchor_right
	tr.anchor_bottom = cr.anchor_bottom
	tr.offset_left = cr.offset_left
	tr.offset_top = cr.offset_top
	tr.offset_right = cr.offset_right
	tr.offset_bottom = cr.offset_bottom
	tr.grow_horizontal = cr.grow_horizontal
	tr.grow_vertical = cr.grow_vertical
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	parent.move_child(tr, cr.get_index())
	# Hide the ColorRect — TextureRect provides the visual
	cr.color = Color.TRANSPARENT


## Apply side panel background to a Control.
static func apply_side_panel(control: Control) -> void:
	var sb := make_stylebox("bg_side_panel", 12, Color(0.7, 0.7, 0.75, 0.7))
	if sb == null:
		push_warning("[UIBackgrounds] apply_side_panel failed — no texture")
		return
	if control is PanelContainer:
		control.add_theme_stylebox_override("panel", sb)
	else:
		control.add_theme_stylebox_override("panel", sb)


## Apply tooltip style to a Control.
static func apply_tooltip(control: Control) -> void:
	var sb := make_stylebox("bg_tooltip", 8, Color(0.8, 0.8, 0.85, 0.9))
	if sb == null:
		return
	if control is PanelContainer:
		control.add_theme_stylebox_override("panel", sb)
	else:
		control.add_theme_stylebox_override("panel", sb)


## Apply panel style to a Control.
static func apply_panel(control: Control) -> void:
	var sb := make_stylebox("bg_panel", 16, Color(0.6, 0.6, 0.65, 0.5))
	if sb == null:
		return
	if control is PanelContainer:
		control.add_theme_stylebox_override("panel", sb)
	else:
		control.add_theme_stylebox_override("panel", sb)
