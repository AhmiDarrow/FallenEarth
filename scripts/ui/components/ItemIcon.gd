class_name ItemIcon
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")

var _texture_rect: TextureRect
var _count_label: Label
var _bg: PanelContainer

var item_id: String = ""
var count: int = 0
var icon_size: int = 48:
	set(v):
		icon_size = v
		custom_minimum_size = Vector2(v, v)
		if _texture_rect:
			_texture_rect.custom_minimum_size = Vector2(v - 8, v - 8)


func _init(item_id_str: String = "", qty: int = 0, size: int = 48) -> void:
	item_id = item_id_str
	count = qty
	icon_size = size


func _ready() -> void:
	size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(icon_size, icon_size)

	_bg = PanelContainer.new()
	_bg.name = "IconBG"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "IconTexture"
	_texture_rect.anchor_left = 0.5
	_texture_rect.anchor_top = 0.5
	_texture_rect.anchor_right = 0.5
	_texture_rect.anchor_bottom = 0.5
	_texture_rect.offset_left = -(icon_size - 8) / 2.0
	_texture_rect.offset_top = -(icon_size - 8) / 2.0
	_texture_rect.offset_right = (icon_size - 8) / 2.0
	_texture_rect.offset_bottom = (icon_size - 8) / 2.0
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_count_label = Label.new()
	_count_label.name = "CountLabel"
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
	_count_label.add_theme_font_size_override("font_size", 11)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
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

	var rarity_color := _rarity_color(item_id)
	_bg.add_theme_stylebox_override("panel", MT.panel(MT.BG_SURFACE, rarity_color, MT.RADIUS_SM, 1))


func _resolve_texture(id_str: String) -> Texture2D:
	var im := _inventory_manager()
	# Try InventoryManager.get_item_type().texture first (all item types)
	if im != null and im.has_method("get_item_type"):
		var typ = im.get_item_type(id_str)
		if typ != null and typ.texture != null:
			return typ.texture
	# Try EquipmentManager.resolve_item().sprite
	var em := get_node_or_null("/root/EquipmentManager") as EquipmentManager
	if em != null and em.has_method("resolve_item"):
		var entry: Dictionary = em.resolve_item(id_str)
		var sprite_name: String = str(entry.get("sprite", ""))
		if not sprite_name.is_empty():
			var tex := SpriteLoader.load_texture("res://assets/sprites/equipment/%s.png" % sprite_name)
			if tex != null:
				return tex
	# Fallback: try known sprite directories by item_id
	for p in [
		"res://assets/sprites/items/%s.png" % id_str,
		"res://assets/sprites/tools/%s.png" % id_str,
		"res://assets/sprites/equipment/%s.png" % id_str,
	]:
		var tex := SpriteLoader.load_texture(p)
		if tex != null:
			return tex
	return null


func _rarity_color(_id: String) -> Color:
	return MT.BORDER_SUBTLE


func _inventory_manager() -> Node:
	return get_node_or_null("/root/InventoryManager") as InventoryManager


func set_selected(sel: bool) -> void:
	if sel:
		_bg.add_theme_stylebox_override("panel", MT.panel(MT.SELECTED_BG, MT.SELECTED_TINT, MT.RADIUS_SM, 2))
	else:
		refresh(item_id, count)
