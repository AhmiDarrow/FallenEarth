## BaseShopUI — Buy UI for a base shop (Phase 7).
##
## Opened from the Base interior via the "Visit shop" button next to
## an NPC resident who has opened a shop. Shows the shop's stock with
## buy prices. Clicking Buy deducts EC and adds the item to inventory.
## Phase 8 wires real stock updates and a sell panel.
class_name BaseShopUI
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const BASE_SHOP_PATH := "/root/BaseShopManager"
const INVENTORY_PATH := "/root/InventoryManager"
const PROGRESSION_PATH := "/root/ProgressionManager"

signal closed

var _shop_type: String = ""
var _npc_id: String = ""


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func setup(shop_type: String, npc_id: String) -> void:
	_shop_type = shop_type
	_npc_id = npc_id
	_refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 8)
	add_child(root_vbox)

	# Title
	var title := Label.new()
	title.name = "Title"
	title.text = "[ Base Shop ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 22)
	root_vbox.add_child(title)

	# Stock label
	var stock_label := Label.new()
	stock_label.name = "StockLabel"
	stock_label.text = "Stock for sale:"
	stock_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	stock_label.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(stock_label)

	# Scrollable stock list
	var scroll := ScrollContainer.new()
	scroll.name = "StockScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "StockList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Bottom bar: status + close
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 32)
	root_vbox.add_child(bottom)
	var status := Label.new()
	status.name = "StatusLabel"
	status.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	status.add_theme_font_size_override("font_size", 13)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(status)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(80, 32)
	close.pressed.connect(_on_close_pressed)
	bottom.add_child(close)
	ButtonStyleHelper.apply_secondary(close)


func _refresh() -> void:
	if has_node("Title"):
		$Title.text = "[ %s ]" % _shop_type.replace("_", " ").capitalize()
	var list: VBoxContainer = get_node_or_null("StockList")
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	var bsm: Node = get_node_or_null(BASE_SHOP_PATH)
	if bsm == null:
		_set_status("BaseShopManager unavailable")
		return
	var stock: Array = bsm.get_shop_stock(_shop_type)
	if stock.is_empty():
		var ph := Label.new()
		ph.text = "(no stock for this shop)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		list.add_child(ph)
		return
	for entry in stock:
		var item_id: String = str(entry.get("item", "?"))
		var qty: int = int(entry.get("qty", 1))
		var price: int = int(entry.get("buy_price", 1))
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 32)
		list.add_child(row)
		var info := Label.new()
		info.text = "%s x%d   %d EC each" % [item_id, qty, price]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var buy_btn := Button.new()
		buy_btn.text = "Buy 1"
		buy_btn.pressed.connect(_on_buy_pressed.bind(item_id, price))
		row.add_child(buy_btn)
		ButtonStyleHelper.apply_primary(buy_btn)


func _on_buy_pressed(item_id: String, price: int) -> void:
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if prog == null or inv == null:
		_set_status("Inventory/Progression unavailable")
		return
	if not prog.spend_ec(price):
		_set_status("Not enough EC (need %d)" % price)
		return
	inv.add_item(item_id, 1)
	_set_status("Bought 1 x %s for %d EC" % [item_id, price])


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _set_status(msg: String) -> void:
	if has_node("StatusLabel"):
		$StatusLabel.text = msg
	print("[BaseShop] %s" % msg)
