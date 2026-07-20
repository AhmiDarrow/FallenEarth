## InventoryScreen — Custom grid inventory with drag & drop,
## weight display, and tooltip. Pure InventoryHandler, no Wyvernbox.
class_name InventoryScreen
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const CELL_SIZE := 48

signal closed


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := UH.make_backdrop()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var panel := UH.make_panel()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	add_child(panel)

	var vbox := UH.make_vbox()
	panel.add_child(vbox)

	var top_bar := _make_top_bar()
	vbox.add_child(top_bar)

	var body := UH.make_hbox(0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	var grid_vbox := UH.make_vbox(0)
	grid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid_vbox)

	# v0.4.0 polish: label the top row as the hotbar so the player knows
	# what the slots below this row are for.
	var hotbar_label := UH.make_small_label("HOTBAR  (press 1-9 or click to quick-use)", MT.TEXT_ACCENT)
	hotbar_label.name = "HotbarLabel"
	grid_vbox.add_child(hotbar_label)

	var grid := InventoryGrid.new(InventoryHandler.GRID_W, InventoryHandler.GRID_H, CELL_SIZE)
	grid.name = "MainGrid"
	grid_vbox.add_child(grid)

	var info := UH.make_hbox(0)
	info.custom_minimum_size = Vector2(0, 30)
	var wgt := _make_weight_label()
	info.add_child(wgt)
	vbox.add_child(info)
	UH.make_scrollable(vbox)


func _make_top_bar() -> Control:
	var hbox := UH.make_hbox()
	hbox.custom_minimum_size = Vector2(0, 36)

	var title := UH.make_accent_label("Inventory", MT.FS_H2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	var close_btn := UH.make_button("X", "danger", 32, 28)
	close_btn.pressed.connect(_on_close)
	hbox.add_child(close_btn)
	return hbox


func _make_weight_label() -> Label:
	var lbl := UH.make_small_label("", MT.TEXT_SECONDARY)
	lbl.name = "WeightLabel"
	var ih := get_node_or_null("/root/InventoryHandler") as InventoryHandler
	if ih != null and ih.has_signal("inventory_changed"):
		if not ih.inventory_changed.is_connected(_refresh_weight.bind(lbl)):
			ih.inventory_changed.connect(_refresh_weight.bind(lbl))
	_refresh_weight(lbl)
	return lbl


func _refresh_weight(lbl: Label) -> void:
	var ih := get_node_or_null("/root/InventoryHandler") as InventoryHandler
	if ih != null:
		lbl.text = "Weight: %.1f / %.1f" % [ih.current_weight, ih.max_weight]


func _on_close() -> void:
	closed.emit()
	queue_free()
