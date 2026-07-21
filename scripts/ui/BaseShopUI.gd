## BaseShopUI — Buy UI for a base shop (Phase 7).
##
## Opened from the Base interior via the "Visit shop" button next to
## an NPC resident who has opened a shop. Shows the shop's stock with
## buy prices. Clicking Buy deducts EC and adds the item to inventory.
## Phase 8 wires real stock updates and a sell panel.
class_name BaseShopUI
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const BASE_SHOP_PATH := "/root/BaseShopManager"
const INVENTORY_PATH := "/root/InventoryHandler"
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
	var bg := UH.make_backdrop()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root_vbox := UH.make_vbox(8)
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# Title
	var title := UH.make_accent_label("[ Base Shop ]", 22)
	title.name = "Title"
	root_vbox.add_child(title)

	# Stock label
	var stock_label := UH.make_label("Stock for sale:", 14, MT.TEXT_LINK)
	stock_label.name = "StockLabel"
	root_vbox.add_child(stock_label)

	# Scrollable stock list
	var scroll := UH.make_scroll_container()
	scroll.name = "StockScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)
	var list := UH.make_vbox(0, true, false)
	list.name = "StockList"
	scroll.add_child(list)

	# Bottom bar: status + close
	var bottom := UH.make_hbox(0)
	bottom.custom_minimum_size = Vector2(0, 32)
	root_vbox.add_child(bottom)
	var status := UH.make_label("", 13, MT.TEXT_SUCCESS)
	status.name = "StatusLabel"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(status)
	var close := UH.make_button("Close", "secondary", 80, 32)
	close.pressed.connect(_on_close_pressed)
	bottom.add_child(close)


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
		var ph := UH.make_muted_label("(no stock for this shop)")
		list.add_child(ph)
		return
	for entry in stock:
		var item_id: String = str(entry.get("item_id", "?"))
		var qty: int = int(entry.get("count", 1))
		var price: int = int(entry.get("buy_price", 1))
		var row := UH.make_hbox(0)
		row.custom_minimum_size = Vector2(0, 32)
		list.add_child(row)
		var info := UH.make_label("%s x%d   %d EC each" % [item_id, qty, price])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var buy_btn := UH.make_button("Buy 1", "primary")
		buy_btn.pressed.connect(_on_buy_pressed.bind(item_id, price))
		row.add_child(buy_btn)


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
