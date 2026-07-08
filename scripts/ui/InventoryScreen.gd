## InventoryScreen — Wyvernbox-powered grid inventory with equipment panel,
## hotbar row, drag & drop, and tooltip.
class_name InventoryScreen
extends Control

const UIBackgrounds = preload("res://scripts/UIBackgrounds.gd")
const INVENTORY_PATH := "/root/InventoryManager"
const CELL_SIZE := 48

signal closed

var _main_view: InventoryView
var _tooltip: PanelContainer


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	UIBackgrounds.apply_modal_bg(bg)

	# Main window panel — fills parent with margins
	var panel := PanelContainer.new()
	panel.name = "WindowPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Top bar
	var top_bar := _make_top_bar()
	vbox.add_child(top_bar)

	# Main body: equipment | grid+hotbar
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	var equip_panel := _make_equipment_panel()
	body.add_child(equip_panel)

	var grid_vbox := VBoxContainer.new()
	grid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid_vbox)

	_main_view = _make_grid_view()
	grid_vbox.add_child(_main_view)

	# Bottom info
	var info := HBoxContainer.new()
	info.custom_minimum_size = Vector2(0, 30)
	var wgt := _make_weight_label()
	info.add_child(wgt)
	grid_vbox.add_child(info)

	# Stats panel on right
	var stats := _make_stats_panel()
	body.add_child(stats)

	# Tooltip (mouse follower)
	_tooltip = _make_tooltip()
	_tooltip.hide()
	add_child(_tooltip)

	# Connect inventory signals
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv != null:
		if inv.has_signal("inventory_changed"):
			inv.connect("inventory_changed", _refresh_weight)
		_refresh_weight()

	# Connect grid signals for tooltip
	_main_view.item_stack_selected.connect(_on_item_selected)
	_main_view.item_stack_deselected.connect(_on_item_deselected)


func _make_top_bar() -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, 36)
	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_color_override("font_color", Color(0.95, 0.6, 0.1))
	title.add_theme_font_size_override("font_size", 22)
	hb.add_child(title)
	hb.add_spacer(true)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func(): closed.emit(); queue_free())
	hb.add_child(close_btn)
	return hb


func _make_equipment_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(140, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var title := Label.new()
	title.text = "EQUIPMENT"
	title.add_theme_color_override("font_color", Color(0.95, 0.6, 0.1))
	panel.add_child(title)

	var equip_slots := ["Main Hand", "Off Hand", "Head", "Chest", "Belt", "Hands", "Feet", "Ring", "Neck"]
	for slot_name in equip_slots:
		var slot := _make_equip_slot(slot_name)
		panel.add_child(slot)
	return panel


func _make_equip_slot(_slot_name: String) -> Control:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(CELL_SIZE + 8, CELL_SIZE + 8)
	c.color = Color(0.15, 0.15, 0.2, 0.8)
	return c


func _make_grid_view() -> InventoryView:
	var inv_mgr: Node = get_node_or_null(INVENTORY_PATH)
	if inv_mgr == null or not inv_mgr.has_method("get_main_grid"):
		return InventoryView.new()

	var grid_inv = inv_mgr.get_main_grid()
	var view := InventoryView.new()
	view.name = "MainGrid"
	view.inventory = grid_inv
	view.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	view.item_scene = preload("res://addons/wyvernbox_prefabs/item_stack_view.tscn")
	view.selected_item_style = preload("res://addons/wyvernbox_prefabs/graphics/selected_cell.tres")
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(CELL_SIZE * 10, CELL_SIZE * 3)
	view.show_backgrounds = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	return view


func _make_weight_label() -> Label:
	var lbl := Label.new()
	lbl.name = "WeightLabel"
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	return lbl


func _make_stats_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(140, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var title := Label.new()
	title.text = "STATS"
	title.add_theme_color_override("font_color", Color(0.95, 0.6, 0.1))
	panel.add_child(title)

	var stats := ["Encumbrance", "Defense", "Damage"]
	for s in stats:
		var lbl := Label.new()
		lbl.text = s + ": --"
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		panel.add_child(lbl)
	return panel


func _make_tooltip() -> PanelContainer:
	var tip := preload("res://addons/wyvernbox_prefabs/tooltip.tscn").instantiate() as PanelContainer
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tip


func _on_item_selected(item_view: Node) -> void:
	var inv_mgr: Node = get_node_or_null(INVENTORY_PATH)
	if inv_mgr == null:
		return
	var grid: GridInventory = inv_mgr.get_main_grid() if inv_mgr.has_method("get_main_grid") else null
	if grid == null:
		return
	var cell_pos: Vector2 = _main_view.selected_cell
	if cell_pos.x < 0 or cell_pos.y < 0:
		return
	var stack: ItemStack = grid.get_item_at_position(cell_pos.x, cell_pos.y)
	if stack == null:
		return
	_tooltip.display_item(stack, item_view)
	_tooltip.global_position = get_global_mouse_position() + Vector2(16, 16)
	_tooltip.show()


func _on_item_deselected(_item_view: Node) -> void:
	_tooltip.hide()


func _refresh_weight() -> void:
	var inv_mgr: Node = get_node_or_null(INVENTORY_PATH)
	if inv_mgr == null:
		return
	var lbl: Label = find_child("WeightLabel", true, false) as Label
	if lbl == null:
		return
	var cur: float = inv_mgr.get("current_weight") if inv_mgr != null else 0.0
	var max_w: float = inv_mgr.get("max_weight") if inv_mgr != null else 50.0
	lbl.text = "Weight: %.1f / %.1f kg" % [cur, max_w]

