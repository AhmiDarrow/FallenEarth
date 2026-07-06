## BaseShopUI — Buy UI for a base shop (Phase 7).
##
## Opened from the Base interior via the "Visit shop" button next to
## an NPC resident who has opened a shop. Shows the shop's stock with
## buy prices. Clicking Buy deducts EC and adds the item to inventory.
## Phase 8 wires real stock updates and a sell panel.
class_name BaseShopUI
extends Control

const BASE_SHOP_PATH := "/root/BaseShopManager"
const INVENTORY_PATH := "/root/InventoryManager"
const PROGRESSION_PATH := "/root/ProgressionManager"

signal closed

var _shop_type: String = ""
var _npc_id: String = ""


func _ready() -> void:
	# Use the property-syntax `anchors_preset` (not `anchor_right = 1.0`)
	# to avoid Godot's "size overridden after _ready" warning. The
	# property setter resets all offsets to 0 atomically; the individual
	# `anchor_* = 1.0` setters leave stale offsets that trigger the
	# warning when `_sync_size_to_parent` then sets `size`.
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Sync our size to the parent BEFORE building children — otherwise
	# `_build_ui()` reads `size = (0, 0)` and places status/close
	# buttons off-screen. `set_anchors_*` alone doesn't propagate size
	# when the parent is a non-Container Control.
	_sync_size_to_parent()
	_build_ui()
	# Stay in lockstep with the parent if it ever resizes.
	var parent := get_parent()
	if parent is Control and not (parent as Control).resized.is_connected(_on_parent_resized):
		(parent as Control).resized.connect(_on_parent_resized)


## Snap our `size` to the parent Control's rect. Required because we
## are added as a child of a non-Container Control (the HUD or
## Settlement interior) and the engine doesn't auto-size us from
## anchors alone. See `scripts/ui/CharacterMenu.gd` for the full writeup.
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
	# Re-place any children that depend on `size`.
	if has_node("StatusLabel"):
		$StatusLabel.position = Vector2(20, size.y - 70)
	if has_node("CloseButton") or has_node("Close"):
		var close_btn: Node = get_node_or_null("CloseButton")
		if close_btn == null:
			close_btn = get_node_or_null("Close")
		if close_btn != null:
			close_btn.position = Vector2(size.x - 100, size.y - 50)


func setup(shop_type: String, npc_id: String) -> void:
	_shop_type = shop_type
	_npc_id = npc_id
	_refresh()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.95)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Title
	var title := Label.new()
	title.name = "Title"
	title.text = "[ Base Shop ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 26)
	title.position = Vector2(20, 16)
	add_child(title)
	# Stock list
	var stock_label := Label.new()
	stock_label.name = "StockLabel"
	stock_label.text = "Stock for sale:"
	stock_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	stock_label.add_theme_font_size_override("font_size", 16)
	stock_label.position = Vector2(20, 60)
	add_child(stock_label)
	var scroll := ScrollContainer.new()
	scroll.name = "StockScroll"
	scroll.position = Vector2(20, 90)
	scroll.size = Vector2(640, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "StockList"
	scroll.add_child(list)
	# Status
	var status := Label.new()
	status.name = "StatusLabel"
	status.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	status.add_theme_font_size_override("font_size", 14)
	status.position = Vector2(20, size.y - 70)
	status.custom_minimum_size = Vector2(640, 30)
	add_child(status)
	# Close
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(size.x - 100, size.y - 50)
	close.custom_minimum_size = Vector2(80, 40)
	close.pressed.connect(_on_close_pressed)
	add_child(close)


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
	emit_signal("closed")
	queue_free()


func _set_status(msg: String) -> void:
	if has_node("StatusLabel"):
		$StatusLabel.text = msg
	print("[BaseShop] %s" % msg)
