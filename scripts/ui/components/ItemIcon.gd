class_name ItemIcon
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

var _texture_rect: TextureRect
var _count_label: Label
var _bg: PanelContainer

var item_id: String = ""
var count: int = 0
var icon_size: int = 48


func _init(item_id_str: String = "", qty: int = 0, size: int = 48) -> void:
	item_id = item_id_str
	count = qty
	icon_size = size


func _ready() -> void:
	size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(icon_size, icon_size)

	_bg = PanelContainer.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_texture_rect = TextureRect.new()
	_texture_rect.anchor_left = 0.5
	_texture_rect.anchor_top = 0.5
	_texture_rect.anchor_right = 0.5
	_texture_rect.anchor_bottom = 0.5
	var half := icon_size / 2.0 - 2.0
	_texture_rect.offset_left = -half
	_texture_rect.offset_top = -half
	_texture_rect.offset_right = half
	_texture_rect.offset_bottom = half
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_count_label = UH.make_label("", 11, Color.WHITE)
	_count_label.anchor_left = 1.0
	_count_label.anchor_top = 1.0
	_count_label.anchor_right = 1.0
	_count_label.anchor_bottom = 1.0
	_count_label.offset_left = -icon_size + 2
	_count_label.offset_top = -14
	_count_label.offset_right = -2
	_count_label.offset_bottom = 2
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_count_label.add_theme_constant_override("outline_size", 2)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)

	refresh(item_id, count)


func refresh(new_id: String = "", new_count: int = -1) -> void:
	if new_id != "":
		item_id = new_id
	if new_count >= 0:
		count = new_count

	if item_id == "":
		_texture_rect.texture = null
		_count_label.text = ""
		_bg.add_theme_stylebox_override("panel", MT.panel(MT.BG_DEEP, MT.BORDER_SUBTLE, MT.RADIUS_SM, 1))
		return

	var tex := _resolve_texture(item_id)
	_texture_rect.texture = tex
	_count_label.text = str(count) if count > 1 else ""
	_count_label.visible = count > 1
	_bg.add_theme_stylebox_override("panel", MT.panel(MT.BG_SURFACE, MT.BORDER_SUBTLE, MT.RADIUS_SM, 1))


func _resolve_texture(item_id_str: String) -> Texture2D:
	# 1. Try direct PNG paths via Godot resource loader
	var png_paths := [
		"res://assets/sprites/items/%s.png" % item_id_str,
		"res://assets/sprites/tools/%s.png" % item_id_str,
		"res://assets/sprites/equipment/%s.png" % item_id_str,
	]
	for p in png_paths:
		if ResourceLoader.exists(p):
			var tex := load(p) as Texture2D
			if tex != null:
				return tex
	# 2. EquipmentManager resolves weapon/armor IDs to sprite names
	var em := get_node_or_null("/root/EquipmentManager")
	if em != null and em.has_method("_resolve_item"):
		var entry: Dictionary = em._resolve_item(item_id_str)
		if not entry.is_empty():
			var sprite_name: String = str(entry.get("sprite", ""))
			if not sprite_name.is_empty():
				# Try _icon variant first (cleaner crop for UI), then base sprite
				var icon_path := "res://assets/sprites/equipment/%s_icon.png" % sprite_name
				var base_path := "res://assets/sprites/equipment/%s.png" % sprite_name
				for eq_path in [icon_path, base_path]:
					if ResourceLoader.exists(eq_path):
						var tex2 := load(eq_path) as Texture2D
						if tex2 != null:
							return tex2
	# 3. Direct filesystem load — bypasses Godot import cache entirely
	for p in png_paths:
		var global_path := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(global_path):
			var img := Image.new()
			if img.load(global_path) == OK:
				return ImageTexture.create_from_image(img)
	# 4. EquipmentManager sprite via direct filesystem load
	if em != null and em.has_method("_resolve_item"):
		var entry2: Dictionary = em._resolve_item(item_id_str)
		if not entry2.is_empty():
			var sn: String = str(entry2.get("sprite", ""))
			if not sn.is_empty():
				for suffix in ["_icon", ""]:
					var eq_path2 := "res://assets/sprites/equipment/%s%s.png" % [sn, suffix]
					var global_path2 := ProjectSettings.globalize_path(eq_path2)
					if FileAccess.file_exists(global_path2):
						var img2 := Image.new()
						if img2.load(global_path2) == OK:
							return ImageTexture.create_from_image(img2)
	# 5. Colored placeholder
	return _make_placeholder_texture(item_id_str)


func _make_placeholder_texture(id: String) -> ImageTexture:
	var img := Image.create(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	var col: Color
	if id.begins_with("weapon_"):
		col = Color(0.8, 0.3, 0.3)
	elif id.begins_with("armor_"):
		col = Color(0.3, 0.5, 0.8)
	elif id.begins_with("acc"):
		col = Color(0.8, 0.7, 0.2)
	else:
		col = Color(0.4, 0.6, 0.4)
	img.fill(col)
	# Draw a small border
	for x in icon_size:
		img.set_pixel(x, 0, col.darkened(0.3))
		img.set_pixel(x, icon_size - 1, col.darkened(0.3))
	for y in icon_size:
		img.set_pixel(0, y, col.darkened(0.3))
		img.set_pixel(icon_size - 1, y, col.darkened(0.3))
	return ImageTexture.create_from_image(img)


func set_selected(sel: bool) -> void:
	if sel:
		_bg.add_theme_stylebox_override("panel", MT.panel(MT.SELECTED_BG, MT.SELECTED_TINT, MT.RADIUS_SM, 2))
	else:
		refresh(item_id, count)
