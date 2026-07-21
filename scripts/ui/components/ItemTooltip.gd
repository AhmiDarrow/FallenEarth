class_name ItemTooltip
extends PanelContainer

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

var _name_label: Label
var _desc_label: Label
var _stats_vbox: VBoxContainer
var _rarity_label: Label

var _item_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 100
	add_theme_stylebox_override("panel", MT.panel(MT.OVERLAY_DARK, MT.BORDER_STRONG, MT.RADIUS_MD, 1))

	var vbox := UH.make_vbox(4)
	add_child(vbox)

	_rarity_label = UH.make_label("", 9)
	_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_rarity_label)

	_name_label = UH.make_label("", 14, MT.TEXT_ACCENT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

	_desc_label = UH.make_label("", 11, MT.TEXT_SECONDARY)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(200, 0)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_desc_label)

	_stats_vbox = UH.make_vbox(1)
	_stats_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_stats_vbox)


func show_for_item(item_id: String, at_position: Vector2) -> void:
	if item_id == _item_id and visible:
		return
	_item_id = item_id
	if item_id == "":
		hide_tooltip()
		return

	var name_str := _get_name(item_id)
	var desc_str := _get_description(item_id)
	var category_str := _get_category(item_id)

	_rarity_label.text = category_str.capitalize() if not category_str.is_empty() else ""
	_name_label.text = name_str
	_desc_label.text = desc_str

	for c in _stats_vbox.get_children():
		_stats_vbox.remove_child(c)
		c.queue_free()

	var stats := _get_item_stats(item_id)
	for stat in stats:
		var lbl := UH.make_label(stat, 10, MT.TEXT_MUTED)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_vbox.add_child(lbl)

	global_position = at_position
	visible = true


func hide_tooltip() -> void:
	_item_id = ""
	visible = false


func _get_name(item_id: String) -> String:
	var ih := get_node_or_null("/root/InventoryHandler") as InventoryHandler
	if ih != null:
		if ih.has_item_meta(item_id):
			return ih.get_item_name(item_id)
	# Fallback to equipment lookup
	var em := get_node_or_null("/root/EquipmentManager")
	if em != null and em.has_method("_resolve_item"):
		var entry: Dictionary = em._resolve_item(item_id)
		if not entry.is_empty():
			return str(entry.get("name", ""))
	return item_id.replace("_", " ").capitalize()


func _get_description(item_id: String) -> String:
	var ih := get_node_or_null("/root/InventoryHandler") as InventoryHandler
	if ih != null and ih.has_item_meta(item_id):
		return str(ih.get_item_data(item_id).get("description", ""))
	return ""


func _get_category(item_id: String) -> String:
	var ih := get_node_or_null("/root/InventoryHandler") as InventoryHandler
	if ih != null and ih.has_item_meta(item_id):
		return str(ih.get_item_data(item_id).get("category", ""))
	return ""


func _get_item_stats(item_id: String) -> PackedStringArray:
	var arr: PackedStringArray = []
	var em := get_node_or_null("/root/EquipmentManager")
	if em == null or not em.has_method("_resolve_item"):
		return arr
	var entry: Dictionary = em._resolve_item(item_id)
	if entry.is_empty():
		return arr
	for key in ["attack", "armor", "strength", "intelligence", "constitution", "dexterity", "mp_max"]:
		var val = entry.get(key, 0)
		if val is int and int(val) != 0:
			arr.append("%s: +%d" % [key.capitalize(), int(val)])
		elif val is float and float(val) != 0.0:
			arr.append("%s: +%.1f" % [key.capitalize(), float(val)])
	return arr
