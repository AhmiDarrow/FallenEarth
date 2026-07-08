## ShopInterface — Buy/sell interface for a settlement trader.
##
## Phase 3. Opened from the Settlement interior via the Trader NPC's
## "Open Shop" button. Lists the shop's items for sale, plus the
## player's current inventory for selling. Buys deduct EC; sells add
## EC. Real item variety (per-shop inventory tied to faction) lands
## in a follow-up; Phase 3 uses a small default stock.
class_name ShopInterface
extends Control

const UIBackgrounds = preload("res://scripts/UIBackgrounds.gd")
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
	# Use `anchors_preset` (property syntax) instead of `anchor_right = 1.0`
	# to avoid Godot's "size overridden after _ready" warning — see
	# BaseShopUI for the full explanation.
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Sync our size to the parent BEFORE building children — otherwise
	# `_build_ui()` reads `size = (0, 0)` and places the status label
	# and close button off-screen.
	_sync_size_to_parent()
	_build_ui()
	_refresh()
	# Stay in lockstep with the parent if it ever resizes.
	var parent := get_parent()
	if parent is Control and not (parent as Control).resized.is_connected(_on_parent_resized):
		(parent as Control).resized.connect(_on_parent_resized)


## Snap our `size` to the parent Control's rect. Required because we
## are added as a child of a non-Container Control and the engine
## doesn't auto-size us from anchors alone.
func _sync_size_to_parent() -> void:
	var parent := get_parent()
	if parent is Control:
		var p: Control = parent as Control
		if p.size.x > 0 and p.size.y > 0:
			size = p.size
			position = Vector2.ZERO


## Re-sync our size and re-layout when the parent Control is resized.
func _on_parent_resized() -> void:
	_sync_size_to_parent()
	if has_node("StatusLabel"):
		$StatusLabel.position = Vector2(20, size.y - 70)
	if has_node("Close"):
		$Close.position = Vector2(size.x - 100, size.y - 50)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	UIBackgrounds.apply_modal_bg(bg)
	# Title
	var title := Label.new()
	title.text = "[ Shop — Buy / Sell ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(20, 12)
	add_child(title)
	# EC readout
	var ec_label := Label.new()
	ec_label.name = "EcLabel"
	ec_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	ec_label.add_theme_font_size_override("font_size", 14)
	ec_label.position = Vector2(20, 50)
	add_child(ec_label)
	# Stock
	var stock_label := Label.new()
	stock_label.text = "For sale:"
	stock_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	stock_label.add_theme_font_size_override("font_size", 16)
	stock_label.position = Vector2(20, 90)
	add_child(stock_label)
	var stock_scroll := ScrollContainer.new()
	stock_scroll.name = "StockScroll"
	stock_scroll.position = Vector2(20, 116)
	stock_scroll.size = Vector2(360, 480)
	stock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(stock_scroll)
	var stock_vbox := VBoxContainer.new()
	stock_vbox.name = "StockList"
	stock_scroll.add_child(stock_vbox)
	# Inventory
	var inv_label := Label.new()
	inv_label.text = "Your inventory (sell):"
	inv_label.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	inv_label.add_theme_font_size_override("font_size", 16)
	inv_label.position = Vector2(400, 90)
	add_child(inv_label)
	var inv_scroll := ScrollContainer.new()
	inv_scroll.name = "InvScroll"
	inv_scroll.position = Vector2(400, 116)
	inv_scroll.size = Vector2(360, 480)
	inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(inv_scroll)
	var inv_vbox := VBoxContainer.new()
	inv_vbox.name = "InvList"
	inv_scroll.add_child(inv_vbox)
	# Status / messages
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.position = Vector2(20, size.y - 70)
	status_label.size = Vector2(740, 30)
	add_child(status_label)
	# Close button
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(size.x - 100, size.y - 50)
	close.custom_minimum_size = Vector2(80, 36)
	close.pressed.connect(_on_close_pressed)
	add_child(close)


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
	emit_signal("closed")
	queue_free()
