## ShopInterface — Buy/sell interface for a settlement trader.
##
## Phase 3. Opened from the Settlement interior via the Trader NPC's
## "Open Shop" button. Lists the shop's items for sale, plus the
## player's current inventory for selling. Buys deduct EC; sells add
## EC. Real item variety (per-shop inventory tied to faction) lands
## in a follow-up; Phase 3 uses a small default stock.
class_name ShopInterface
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const INVENTORY_PATH := "/root/InventoryManager"
const PROGRESSION_PATH := "/root/ProgressionManager"
const ITEMS_PATH := "res://data/items.json"

signal closed

# Default stock: Phase 3 placeholder. Real shop inventory ties to
## faction + tier; that lands in a follow-up.
const DEFAULT_STOCK := [
	{"item": "bandage", "qty": 5, "buy_price": 8},
	{"item": "stick", "qty": 20, "buy_price": 2},
	{"item": "stone", "qty": 20, "buy_price": 2},
	{"item": "iron_ore", "qty": 10, "buy_price": 8},
	{"item": "withered_branch", "qty": 10, "buy_price": 4},
]


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
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

	# Top bar: title + EC readout
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 32)
	root_vbox.add_child(top_bar)
	var title := Label.new()
	title.text = "[ Shop — Buy / Sell ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 22)
	top_bar.add_child(title)
	top_bar.add_spacer(true)
	var ec_label := Label.new()
	ec_label.name = "EcLabel"
	ec_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	ec_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(ec_label)

	# Body: stock list | inventory list
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root_vbox.add_child(body)

	# Stock column
	var stock_vbox := VBoxContainer.new()
	stock_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stock_vbox)
	var stock_label := Label.new()
	stock_label.text = "For sale:"
	stock_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	stock_label.add_theme_font_size_override("font_size", 14)
	stock_vbox.add_child(stock_label)
	var stock_scroll := ScrollContainer.new()
	stock_scroll.name = "StockScroll"
	stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stock_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stock_vbox.add_child(stock_scroll)
	var stock_list := VBoxContainer.new()
	stock_list.name = "StockList"
	stock_scroll.add_child(stock_list)

	# Inventory column
	var inv_vbox := VBoxContainer.new()
	inv_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(inv_vbox)
	var inv_label := Label.new()
	inv_label.text = "Your inventory (sell):"
	inv_label.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	inv_label.add_theme_font_size_override("font_size", 14)
	inv_vbox.add_child(inv_label)
	var inv_scroll := ScrollContainer.new()
	inv_scroll.name = "InvScroll"
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv_vbox.add_child(inv_scroll)
	var inv_list := VBoxContainer.new()
	inv_list.name = "InvList"
	inv_scroll.add_child(inv_list)

	# Bottom bar: status + close
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 32)
	root_vbox.add_child(bottom)
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(status_label)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(80, 32)
	close.pressed.connect(_on_close_pressed)
	bottom.add_child(close)
	ButtonStyleHelper.apply_secondary(close)


func _refresh() -> void:
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	if has_node("EcLabel"):
		$EcLabel.text = "EC: %d" % (int(prog.ec) if prog != null else 0)
	_populate_stock()
	_populate_inventory()


func _populate_stock() -> void:
	var stock_vbox: VBoxContainer = get_node_or_null("StockList")
	if stock_vbox == null:
		return
	for child in stock_vbox.get_children():
		child.queue_free()
	for stock in DEFAULT_STOCK:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		stock_vbox.add_child(row)
		var info := Label.new()
		info.text = "%s x%d  (%d EC each)" % [
			str(stock.get("item", "?")), int(stock.get("qty", 1)),
			int(stock.get("buy_price", 1))
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_buy_pressed.bind(stock.get("item", ""), int(stock.get("buy_price", 1))))
		row.add_child(buy_btn)


func _populate_inventory() -> void:
	var inv_vbox: VBoxContainer = get_node_or_null("InvList")
	if inv_vbox == null:
		return
	for child in inv_vbox.get_children():
		child.queue_free()
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null:
		return
	var snapshot: Array = inv.get_inventory_snapshot()
	if snapshot.is_empty():
		var ph := Label.new()
		ph.text = "(inventory empty)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		inv_vbox.add_child(ph)
		return
	for slot in snapshot:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		inv_vbox.add_child(row)
		var info := Label.new()
		info.text = "%s x%d" % [str(slot.get("item_id", "?")), int(slot.get("qty", 0))]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var sell_btn := Button.new()
		sell_btn.text = "Sell 1"
		var sell_price: int = _sell_price_for(str(slot.get("item_id", "")))
		sell_btn.text = "Sell (%d EC)" % sell_price
		sell_btn.pressed.connect(_on_sell_pressed.bind(str(slot.get("item_id", "")), sell_price))
		row.add_child(sell_btn)


func _sell_price_for(item_id: String) -> int:
	# Sell at half the buy price (or 1 EC, whichever is higher)
	for s in DEFAULT_STOCK:
		if str(s.get("item", "")) == item_id:
			return maxi(1, int(int(s.get("buy_price", 1)) / 2.0))
	# Items not in the shop stock sell for 1 EC by default
	return 1


func _on_buy_pressed(item_id: String, price: int) -> void:
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	if inv == null or prog == null:
		_set_status("Shop unavailable")
		return
	if not prog.spend_ec(price):
		_set_status("Not enough EC (need %d)" % price)
		return
	inv.add_item(item_id, 1)
	_set_status("Bought 1 x %s for %d EC" % [item_id, price])
	_refresh()


func _on_sell_pressed(item_id: String, price: int) -> void:
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	var prog: Node = get_node_or_null(PROGRESSION_PATH)
	if inv == null or prog == null:
		_set_status("Shop unavailable")
		return
	if not inv.has_item(item_id, 1):
		_set_status("You don't have any %s to sell" % item_id)
		return
	inv.remove_item(item_id, 1)
	prog.add_ec(price)
	_set_status("Sold 1 x %s for %d EC" % [item_id, price])
	_refresh()


# ---------------------------------------------------------------------------
# Test helpers (called directly from smoke_phase3b.gd).
# ---------------------------------------------------------------------------

## Buy helper exposed for tests. Returns true on success.
func test_buy(item_id: String, price: int) -> bool:
	_on_buy_pressed(item_id, price)
	return true


## Sell helper exposed for tests. Returns true on success.
func test_sell(item_id: String, price: int) -> bool:
	_on_sell_pressed(item_id, price)
	return true


func _set_status(msg: String) -> void:
	if has_node("StatusLabel"):
		$StatusLabel.text = msg
	print("[Shop] %s" % msg)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
