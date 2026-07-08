## LootWindow — Opens when the player loots a container or mob corpse.
##
## Shows the loot container's GridInventory alongside the player's main
## grid. Supports drag & drop between the two via wyvernbox InventoryView.
class_name LootWindow
extends Control

const INVENTORY_PATH := "/root/InventoryManager"
const CELL_SIZE := 40

signal closed

var _loot_view: InventoryView
var _player_view: InventoryView
var _loot_grid: GridInventory


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 460)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350
	panel.offset_top = -230
	panel.offset_right = 350
	panel.offset_bottom = 230
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Top bar
	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 32)
	var title := Label.new()
	title.text = "LOOT"
	title.add_theme_color_override("font_color", Color(0.95, 0.6, 0.1))
	title.add_theme_font_size_override("font_size", 20)
	top.add_child(title)
	top.add_spacer(true)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(_on_close)
	top.add_child(close_btn)
	vbox.add_child(top)

	# Body: loot grid | player grid
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	_loot_view = _make_inventory_view()
	body.add_child(_loot_view)

	var vs := VSeparator.new()
	body.add_child(vs)

	_player_view = _make_inventory_view()
	body.add_child(_player_view)

	# Bottom bar
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 32)
	var take_all := Button.new()
	take_all.text = "Take All"
	take_all.pressed.connect(_on_take_all)
	bottom.add_child(take_all)
	bottom.add_spacer(true)
	var close_btn2 := Button.new()
	close_btn2.text = "Close"
	close_btn2.pressed.connect(_on_close)
	bottom.add_child(close_btn2)
	vbox.add_child(bottom)


func _make_inventory_view() -> InventoryView:
	var view := InventoryView.new()
	view.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	view.item_scene = preload("res://addons/wyvernbox_prefabs/item_stack_view.tscn")
	view.selected_item_style = preload("res://addons/wyvernbox_prefabs/graphics/selected_cell.tres")
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.show_backgrounds = true
	return view


## Populate the loot window from the given GridInventory.
func set_loot_inventory(grid: GridInventory) -> void:
	_loot_grid = grid
	_loot_view.inventory = grid

	# Show the player's main grid on the right
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv != null and inv.has_method("get_main_grid"):
		_player_view.inventory = inv.get_main_grid()


func _on_take_all() -> void:
	if _loot_grid == null:
		return
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null or not inv.has_method("transfer_loot_to_main"):
		# Fallback: manually move
		var main_grid = inv.get_main_grid() if inv and inv.has_method("get_main_grid") else null
		if main_grid == null:
			return
		for stack in _loot_grid.items.duplicate():
			main_grid.try_add_item(stack)
			_loot_grid.remove_item(stack)
		return
	inv.transfer_loot_to_main()


func _on_close() -> void:
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv != null and inv.has_method("close_loot_inventory"):
		inv.close_loot_inventory()
	closed.emit()
	queue_free()

