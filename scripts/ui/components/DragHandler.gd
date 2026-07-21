## DragHandler — Autoload singleton for item drag-and-drop.
## Coordinates between InventoryGrid, EquipmentDoll, and ItemSlot nodes.
extends Node

signal drag_started(item_id: String, count: int, source: Node)
signal drag_ended(dropped_on: Node, item_id: String, count: int)
signal drag_cancelled

var is_dragging: bool = false
var drag_item_id: String = ""
var drag_count: int = 0
var source_slot: Node = null
var source_grid: Node = null
var _preview: Control = null
var _offset: Vector2 = Vector2.ZERO


func begin_drag(slot_node: Node, grid_node: Node, item_id: String, qty: int) -> void:
	if item_id == "" or is_dragging:
		return
	is_dragging = true
	drag_item_id = item_id
	drag_count = qty
	source_slot = slot_node
	source_grid = grid_node

	_preview = Control.new()
	_preview.name = "DragPreview"
	_preview.z_index = 200
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ItemIcon.new(item_id, qty, 40)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(icon)
	_preview.custom_minimum_size = Vector2(40, 40)
	_offset = Vector2(20, 20)
	get_tree().root.add_child(_preview)
	_preview.global_position = get_viewport().get_mouse_position() - _offset
	drag_started.emit(item_id, qty, source_grid)


func _process(_delta: float) -> void:
	if not is_dragging or _preview == null:
		return
	_preview.global_position = get_viewport().get_mouse_position() - _offset
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drop_at_mouse()


func _drop_at_mouse() -> void:
	if not is_dragging:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var dropped_on: Node = _find_drop_target(mouse_pos)
	_preview.queue_free()
	_preview = null
	if dropped_on != null:
		drag_ended.emit(dropped_on, drag_item_id, drag_count)
	else:
		drag_cancelled.emit()
	is_dragging = false
	drag_item_id = ""
	drag_count = 0
	source_slot = null
	source_grid = null


func _find_drop_target(mouse_pos: Vector2) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.root
	if root == null:
		return null
	# Search all nodes under mouse for InventoryGrid or ItemSlot
	var nodes := root.get_children(true)
	for node in nodes:
		var targets: Array = _find_drop_targets(node)
		for target in targets:
			if target.visible and target.get_global_rect().has_point(mouse_pos):
				return target
	return null


func _find_drop_targets(node: Node) -> Array:
	var result: Array = []
	if node is InventoryGrid and node.visible:
		result.append(node)
	if node is ItemSlot and node.visible:
		# Equipment slots (with slot_key) are always valid drop targets
		# Inventory slots need to have an item (for swap)
		if node.slot_key != "" or node.item_id != "":
			result.append(node)
	for child in node.get_children():
		result.append_array(_find_drop_targets(child))
	return result
