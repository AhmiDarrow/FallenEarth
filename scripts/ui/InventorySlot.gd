## InventorySlot — Single inventory cell, drawn via DisplayManager.
extends Control



var _item: Dictionary = {}
var _idx: int = 0

func setup_for(item: Dictionary, index: int) -> void:
	_item = item.duplicate()
	_idx = index
	modulate = Color.WHITE
	if item.get("qty", 0) > 1:
		modulate = modulate.lerp(Color(0.85, 0.82, 0.80), 0.5)

func get_item() -> Dictionary:
	return _item

func _draw() -> void:
	if _item.is_empty():
		return
	if not is_instance_valid(DisplayManager):
		return
	var r := get_rect()
	var slot_rect := Rect2(r.position, r.size)
	DisplayManager.draw_inventory_slot(slot_rect, _item, _idx)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pass # handled by parent
