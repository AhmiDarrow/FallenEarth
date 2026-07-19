class_name DragHandler
extends Node
## Singleton autoload for item drag-and-drop across the UI.
## Add to project.godot autoloads as "DragHandler".

signal drag_started(item_id: String, count: int)
signal drag_ended(dropped_on: Node, item_id: String, count: int)
signal drag_cancelled

var _is_dragging: bool = false
var _drag_item_id: String = ""
var _drag_count: int = 0
var _source_slot: ItemSlot = null
var _drag_preview: Control = null
var _drag_offset: Vector2 = Vector2.ZERO


func begin_drag(slot: ItemSlot, id: String, qty: int) -> void:
	if id == "" or _is_dragging:
		return
	_is_dragging = true
	_drag_item_id = id
	_drag_count = qty
	_source_slot = slot

	_drag_preview = Control.new()
	_drag_preview.name = "DragPreview"
	_drag_preview.z_index = 200
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ItemIcon.new(id, qty, 40)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.add_child(icon)
	_drag_preview.custom_minimum_size = Vector2(40, 40)
	_drag_offset = Vector2(20, 20)
	get_tree().root.add_child(_drag_preview)
	_drag_preview.global_position = get_viewport().get_mouse_position() - _drag_offset

	drag_started.emit(id, qty)


func _process(_delta: float) -> void:
	if not _is_dragging or _drag_preview == null:
		return
	_drag_preview.global_position = get_viewport().get_mouse_position() - _drag_offset

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_drop_at_mouse()


func _drop_at_mouse() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var target := _find_drop_target(mouse_pos)
	drag_ended.emit(target, _drag_item_id, _drag_count)
	end_drag()


func _find_drop_target(pos: Vector2) -> Node:
	for c in get_tree().get_nodes_in_group("drop_target"):
		if c is Control and is_instance_valid(c) and c.get_global_rect().has_point(pos):
			return c
	return null


func cancel_drag() -> void:
	drag_cancelled.emit()
	end_drag()


func end_drag() -> void:
	_is_dragging = false
	_drag_item_id = ""
	_drag_count = 0
	_source_slot = null
	if _drag_preview:
		_drag_preview.queue_free()
		_drag_preview = null


func is_dragging() -> bool:
	return _is_dragging


func get_drag_item() -> String:
	return _drag_item_id


func get_drag_count() -> int:
	return _drag_count


func get_source_slot() -> ItemSlot:
	return _source_slot
