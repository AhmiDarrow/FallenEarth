class_name InventoryGrid
extends Control
## Custom grid inventory renderer. Replaces Wyvernbox InventoryView.
## Renders a W×H grid of ItemSlot nodes from InventoryManager.main_inventory.
## Supports click-to-select, hover tooltips, drag-and-drop.

const MT = preload("res://assets/ui/MasterTheme.gd")
const INVENTORY_PATH := "/root/InventoryManager"

var grid_width: int = 10
var grid_height: int = 3
var cell_size: int = 48:
	set(v):
		cell_size = v
		_rebuild()

var _slots: Array[ItemSlot] = []
var _selected_slot: int = -1
var _tooltip: ItemTooltip
var _grid_bg: ColorRect

signal slot_clicked(index: int, item_id: String)
signal slot_right_clicked(index: int, item_id: String)


func _init(w: int = 10, h: int = 3, csize: int = 48) -> void:
	grid_width = w
	grid_height = h
	cell_size = csize


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(grid_width * cell_size + grid_width * 2, grid_height * cell_size + grid_height * 2)

	_grid_bg = ColorRect.new()
	_grid_bg.name = "GridBackground"
	_grid_bg.color = MT.BG_DEEP
	_grid_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_bg)

	var container := Control.new()
	container.name = "SlotContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)

	_rebuild_slots(container)

	_tooltip = ItemTooltip.new()
	_tooltip.name = "ItemTooltip"
	add_child(_tooltip)

	var inv := get_node_or_null(INVENTORY_PATH) as InventoryManager
	if inv != null and inv.has_signal("inventory_changed"):
		inv.connect("inventory_changed", refresh)

	var dh := get_node_or_null("/root/DragHandler") as DragHandler
	if dh != null and dh.has_signal("drag_ended"):
		dh.connect("drag_ended", _on_drag_ended)


func _rebuild() -> void:
	custom_minimum_size = Vector2(grid_width * cell_size + grid_width * 2, grid_height * cell_size + grid_height * 2)
	var container := get_node_or_null("SlotContainer")
	if container:
		_rebuild_slots(container)


func _rebuild_slots(container: Node) -> void:
	for s in _slots:
		if is_instance_valid(s):
			s.queue_free()
	_slots.clear()
	for child in container.get_children():
		child.queue_free()

	for y in grid_height:
		for x in grid_width:
			var idx := y * grid_width + x
			var slot := ItemSlot.new(cell_size, "")
			slot.name = "Slot_%d" % idx
			slot.position = Vector2(x * (cell_size + 2) + 2, y * (cell_size + 2) + 2)
			slot.custom_minimum_size = Vector2(cell_size, cell_size)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.add_to_group("drop_target")
			slot.clicked.connect(_on_slot_clicked.bind(idx))
			slot.right_clicked.connect(_on_slot_right_clicked.bind(idx))
			slot.gui_input.connect(_on_slot_gui_input.bind(idx))
			slot.mouse_entered.connect(_on_slot_hover.bind(idx))
			slot.mouse_exited.connect(_on_slot_unhover)
			container.add_child(slot)
			_slots.append(slot)

	refresh()


func refresh() -> void:
	var inv := get_node_or_null(INVENTORY_PATH) as InventoryManager
	if inv == null:
		return

	var grid_inv = inv.get_main_grid() if inv.has_method("get_main_grid") else null

	for i in _slots.size():
		if i >= grid_width * grid_height:
			break
		if grid_inv != null:
			var x := i % grid_width
			var y := int(i / grid_width)
			var stack = grid_inv.get_item_at_position(x, y)
			if stack != null and stack.item_type != null:
				var item_id := _resolve_item_id(inv, stack)
				_slots[i].item_id = item_id
				_slots[i].count = stack.count
			else:
				_slots[i].item_id = ""
				_slots[i].count = 0
		else:
			# Fallback: old snapshot API
			var snap: Array = inv.get_inventory_snapshot() if inv.has_method("get_inventory_snapshot") else []
			if i < snap.size():
				var entry: Dictionary = snap[i]
				_slots[i].item_id = str(entry.get("item_id", ""))
				_slots[i].count = int(entry.get("qty", 0))
			else:
				_slots[i].item_id = ""
				_slots[i].count = 0

	if _slots.is_empty():
		return
	_slots[0].selected = false
	if _selected_slot >= 0 and _selected_slot < _slots.size():
		_slots[_selected_slot].selected = true


func _resolve_item_id(inv: Node, stack) -> String:
	if inv.has_method("_get_item_id"):
		return str(inv._get_item_id(stack))
	if stack.item_type != null and stack.item_type.has_meta("item_id"):
		return str(stack.item_type.get_meta("item_id"))
	return ""


func _on_slot_clicked(idx: int) -> void:
	if _selected_slot >= 0 and _selected_slot < _slots.size():
		_slots[_selected_slot].selected = false
	_selected_slot = idx
	_slots[idx].selected = true
	slot_clicked.emit(idx, _slots[idx].item_id)


func _on_slot_right_clicked(idx: int, _id: String) -> void:
	slot_right_clicked.emit(idx, _slots[idx].item_id)


func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			slot_double_clicked.emit(idx, _slots[idx].item_id)


func _on_drag_ended(target: Node, item_id: String, _count: int) -> void:
	if target == null or item_id == "":
		return
	var target_idx := _slots.find(target)
	if target_idx < 0:
		return
	var dh := get_node_or_null("/root/DragHandler") as DragHandler
	if dh == null or not dh.has_method("get_source_slot"):
		return
	var src_slot: ItemSlot = dh.get_source_slot()
	if src_slot == null or src_slot == target:
		return
	var src_idx := _slots.find(src_slot)
	if src_idx < 0:
		return
	var inv := get_node_or_null(INVENTORY_PATH) as InventoryManager
	if inv == null or not inv.has_method("get_main_grid"):
		return
	var grid = inv.get_main_grid()
	if grid == null:
		return
	var src_x := src_idx % grid_width
	var src_y := int(src_idx / grid_width)
	var tgt_x := target_idx % grid_width
	var tgt_y := int(target_idx / grid_width)
	var src_stack = grid.get_item_at_position(src_x, src_y)
	if src_stack == null:
		return
	var tgt_stack = grid.get_item_at_position(tgt_x, tgt_y)

	grid.remove_item(src_stack)
	if tgt_stack != null:
		grid.remove_item(tgt_stack)

	var hand = grid.try_place_stackv(src_stack, Vector2(tgt_x, tgt_y))
	if tgt_stack != null:
		grid.try_place_stackv(tgt_stack, Vector2(src_x, src_y))
	if hand != null:
		grid.try_add_item(hand)
	refresh()


func _on_slot_hover(idx: int) -> void:
	if idx < 0 or idx >= _slots.size():
		return
	var id := _slots[idx].item_id
	if id == "":
		_tooltip.hide_tooltip()
		return
	var pos := get_global_mouse_position() + Vector2(16, 16)
	_tooltip.show_for_item(id, pos)


func _on_slot_unhover() -> void:
	_tooltip.hide_tooltip()


func get_slot(index: int) -> ItemSlot:
	if index >= 0 and index < _slots.size():
		return _slots[index]
	return null


func get_selected_index() -> int:
	return _selected_slot


func get_selected_item_id() -> String:
	if _selected_slot >= 0 and _selected_slot < _slots.size():
		return _slots[_selected_slot].item_id
	return ""


signal slot_double_clicked(index: int, item_id: String)
