## InventoryControl — Custom Control that draws inventory grid via DisplayManager.
extends Control

@onready var _container: ScrollContainer = $ScrollContainer
@onready var _grid: GridContainer = $ScrollContainer/ScrollContainer/CenterContainer/Panel/InventoryGrid

func _ready() -> void:
	_configure_grid()

func _configure_grid() -> void:
	_grid.columns = 5
	_grid.row_headers_visible = false
	_grid.column_headers_visible = false
	_grid.mouse_filter = Control.MOUSE_FILTER_STOP

func set_items(items: Array[Dictionary]) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_grid.clear()

	for i in range(items.size()):
		var item: Dictionary = items[i]
		var slot := InventorySlot.new()
		slot.size_override = Vector2(46, 46)
		slot.setup_for(item, i)
		_grid.add_child(slot)

func get_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in _grid.get_children():
		result.append(slot.get_item())
	return result
