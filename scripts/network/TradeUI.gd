## TradeUI — Trade window overlay for player-to-player trading
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

signal trade_closed()

var _trade_manager: Node = null
var _partner_id: int = -1
var _partner_name: String = ""

var _my_slot_container: VBoxContainer
var _partner_slot_container: VBoxContainer
var _confirm_btn: Button
var _cancel_btn: Button
var _status_label: Label


func _init(partner_id: int, partner_name: String) -> void:
	_partner_id = partner_id
	_partner_name = partner_name
	mouse_filter = MOUSE_FILTER_STOP
	size = Vector2(500, 360)
	position = Vector2(390, 200)
	name = "TradeUI"
	_build_ui()


func _build_ui() -> void:
	var panel := UH.make_surface_panel()
	panel.size = Vector2(500, 360)
	panel.position = Vector2.ZERO
	add_child(panel)

	var vbox := UH.make_vbox(6)
	vbox.size = Vector2(480, 340)
	vbox.position = Vector2(10, 10)
	panel.add_child(vbox)

	var title := UH.make_accent_label("Trading with %s" % _partner_name, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hbox := UH.make_hbox(12, true)
	vbox.add_child(hbox)

	# My side
	var my_side := UH.make_vbox(0, true)
	hbox.add_child(my_side)
	var my_label := UH.make_label("Your items:")
	my_side.add_child(my_label)
	_my_slot_container = UH.make_vbox(2)
	my_side.add_child(_my_slot_container)
	var add_btn := UH.make_button("+ Add Item")
	add_btn.pressed.connect(_show_add_item_dialog)
	my_side.add_child(add_btn)

	# Partner side
	var partner_side := UH.make_vbox(0, true)
	hbox.add_child(partner_side)
	var partner_label := UH.make_label("%s's items:" % _partner_name)
	partner_side.add_child(partner_label)
	_partner_slot_container = UH.make_vbox(2)
	partner_side.add_child(_partner_slot_container)

	# Status
	_status_label = UH.make_label("", MT.FS_BODY, Color(0.7, 0.7, 0.8))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	# Buttons
	var btn_hbox := UH.make_hbox(8)
	vbox.add_child(btn_hbox)
	_confirm_btn = UH.make_button("Confirm Trade")
	_confirm_btn.pressed.connect(_on_confirm)
	_confirm_btn.disabled = true
	btn_hbox.add_child(_confirm_btn)
	_cancel_btn = UH.make_button("Cancel")
	_cancel_btn.pressed.connect(_on_cancel)
	btn_hbox.add_child(_cancel_btn)

	UH.make_scrollable(vbox)


func _show_add_item_dialog() -> void:
	var im: Node = get_node_or_null("/root/InventoryHandler")
	if im == null:
		return
	var items: Array = []
	for y in range(InventoryHandler.GRID_H):
		for x in range(InventoryHandler.GRID_W):
			var slot: Dictionary = im.get_slot(x, y)
			if not slot.is_empty():
				items.append({"item_id": slot.get("id", ""), "qty": slot.get("count", 0)})
	var popup := Window.new()
	popup.title = "Select Item to Offer"
	popup.size = Vector2i(300, 300)
	popup.transient = true
	popup.exclusive = true
	add_child(popup)
	popup.close_requested.connect(popup.queue_free)
	var vbox := UH.make_vbox(0, true, true)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(vbox)
	var scroll := UH.make_scroll_container()
	vbox.add_child(scroll)
	var list := UH.make_vbox(2, true)
	scroll.add_child(list)
	for item in items:
		var btn := UH.make_button("", "primary", 260, 28)
		var item_id: String = str(item.get("item_id", item.get("id", "")))
		var qty: int = int(item.get("qty", item.get("quantity", 1)))
		btn.text = "%s x%d" % [item_id, qty]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void:
			if _trade_manager != null and _trade_manager.has_method("add_item"):
				_trade_manager.add_item(item_id, 1)
			popup.queue_free()
		)
		list.add_child(btn)
	var close_btn := UH.make_button("Close")
	close_btn.pressed.connect(func() -> void: popup.queue_free())
	vbox.add_child(close_btn)
	popup.popup_centered()


func refresh(my_items: Array, partner_items: Array) -> void:
	# Clear and rebuild my slots
	for c in _my_slot_container.get_children():
		c.queue_free()
	for i in my_items.size():
		var item: Dictionary = my_items[i] as Dictionary
		var row := UH.make_hbox(0)
		var label := UH.make_label("%s x%d" % [item.get("item_id", "?"), item.get("qty", 1)])
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)
		var remove_btn := UH.make_button("X", "ghost", 24, 24)
		var idx := i
		remove_btn.pressed.connect(func() -> void:
			if _trade_manager != null and _trade_manager.has_method("remove_offer_item"):
				_trade_manager.remove_offer_item(idx)
		)
		row.add_child(remove_btn)
		_my_slot_container.add_child(row)

	# Partner slots
	for c in _partner_slot_container.get_children():
		c.queue_free()
	for item in partner_items:
		var label := UH.make_label("%s x%d" % [item.get("item_id", "?"), item.get("qty", 1)])
		_partner_slot_container.add_child(label)

	# Update confirm button
	var can_confirm := not my_items.is_empty() and not partner_items.is_empty()
	_confirm_btn.disabled = not can_confirm


func set_my_ready(ready: bool) -> void:
	_status_label.text = "You: %s | Partner: %s" % [
		"READY" if ready else "pending",
		"READY" if _partner_ready else "pending",
	]


func set_partner_ready(ready: bool) -> void:
	_status_label.text = "You: %s | Partner: %s" % [
		"READY" if _my_ready else "pending",
		"READY" if ready else "pending",
	]


var _my_ready: bool = false
var _partner_ready: bool = false


func _on_confirm() -> void:
	if _trade_manager != null and _trade_manager.has_method("confirm_trade"):
		_trade_manager.confirm_trade()
	_my_ready = true
	set_my_ready(true)


func _on_cancel() -> void:
	if _trade_manager != null and _trade_manager.has_method("cancel_trade"):
		_trade_manager.cancel_trade()
	trade_closed.emit()
	queue_free()


func set_trade_manager(manager: Node) -> void:
	_trade_manager = manager
