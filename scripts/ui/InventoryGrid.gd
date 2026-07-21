class_name InventoryGrid
extends Control
## Renders a W×H grid of ItemSlot nodes bound to an inventory data array.
## Supports click-to-select, hover tooltips, drag-and-drop via DragHandler.

const MT = preload("res://assets/ui/MasterTheme.gd")
const IH_PATH := "/root/InventoryHandler"

var grid_w: int = 10
var grid_h: int = 3
var cell_size: int = 48

var _slots: Array[ItemSlot] = []
var _selected_idx: int = -1
var _tooltip: ItemTooltip

signal slot_clicked(x: int, y: int, item_id: String, right_click: bool)


func _init(w: int = 10, h: int = 3, csize: int = 48) -> void:
	grid_w = w
	grid_h = h
	cell_size = csize


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(grid_w * cell_size + grid_w * 2, grid_h * cell_size + grid_h * 2)

	var bg := ColorRect.new()
	bg.color = MT.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var container := Control.new()
	container.name = "GridCells"
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)
	_build_slots(container)

	_tooltip = ItemTooltip.new()
	_tooltip.name = "GridTooltip"
	add_child(_tooltip)

	var ih := get_node_or_null(IH_PATH) as InventoryHandler
	if ih != null and ih.has_signal("inventory_changed") and not ih.inventory_changed.is_connected(refresh):
		ih.connect("inventory_changed", refresh)

	# Initial refresh to display any items already in inventory
	refresh()


func _build_slots(container: Control) -> void:
	var gap := 2
	for i in grid_w * grid_h:
		var x := i % grid_w
		var y := i / grid_w
		var slot := ItemSlot.new(cell_size)
		slot.grid_x = x
		slot.grid_y = y
		slot.position = Vector2(x * (cell_size + gap), y * (cell_size + gap))
		slot.clicked.connect(_on_slot_clicked)
		slot.hovered.connect(_on_slot_hovered.bind(slot))
		slot.unhovered.connect(_on_slot_unhovered)
		container.add_child(slot)
		_slots.append(slot)


func refresh() -> void:
	var ih := get_node_or_null(IH_PATH) as InventoryHandler
	if ih == null:
		return
	for slot in _slots:
		var data := ih.get_slot(slot.grid_x, slot.grid_y)
		slot.refresh(data)


func _on_slot_clicked(x: int, y: int, item_id: String, right_click: bool) -> void:
	var idx := y * grid_w + x
	if _selected_idx == idx and right_click:
		_deselect()
		return
	if _selected_idx >= 0 and _selected_idx < _slots.size():
		_slots[_selected_idx].set_selected(false)
	_selected_idx = idx if item_id != "" else -1
	if _selected_idx >= 0:
		_slots[_selected_idx].set_selected(true)
	slot_clicked.emit(x, y, item_id, right_click)


func _deselect() -> void:
	if _selected_idx >= 0 and _selected_idx < _slots.size():
		_slots[_selected_idx].set_selected(false)
	_selected_idx = -1


func _on_slot_hovered(slot: ItemSlot) -> void:
	if slot.item_id == "":
		_tooltip.hide_tooltip()
		return
	var pos: Vector2 = slot.get_global_mouse_position()
	_tooltip.show_for_item(slot.item_id, pos + Vector2(20, 0))


func _on_slot_unhovered() -> void:
	_tooltip.hide_tooltip()


func get_slot_at_global_pos(global_pos: Vector2) -> ItemSlot:
	for slot in _slots:
		var rect := Rect2(slot.global_position, Vector2(cell_size, cell_size))
		if rect.has_point(global_pos):
			return slot
	return null
