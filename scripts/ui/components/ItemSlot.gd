class_name ItemSlot
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")

var _icon: ItemIcon
var _slot_label: Label
var _button: Button
var _bg_panel: PanelContainer

var slot_name: String = ""
var item_id: String = "":
	set(v):
		item_id = v
		if _icon:
			_icon.refresh(v, count)
var count: int = 0:
	set(v):
		count = v
		if _icon:
			_icon.refresh(item_id, v)

var slot_size: int = 48:
	set(v):
		slot_size = v
		custom_minimum_size = Vector2(v, v)
		if _icon:
			_icon.icon_size = v

var selected: bool = false:
	set(v):
		selected = v
		if _icon:
			_icon.set_selected(v)
		_refresh_border()

signal clicked(slot_name: String, item_id: String)
signal right_clicked(slot_name: String, item_id: String)
signal dragged(slot_name: String, item_id: String)


func _init(size: int = 48, label_text: String = "") -> void:
	slot_size = size
	slot_name = label_text


func _ready() -> void:
	size = Vector2(slot_size, slot_size)
	custom_minimum_size = Vector2(slot_size, slot_size)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_bg_panel = PanelContainer.new()
	_bg_panel.name = "SlotBG"
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_panel)
	_refresh_border()

	_icon = ItemIcon.new("", 0, slot_size)
	_icon.name = "SlotIcon"
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	if not slot_name.is_empty():
		_slot_label = Label.new()
		_slot_label.name = "SlotLabel"
		_slot_label.text = slot_name
		_slot_label.anchor_left = 0.5
		_slot_label.anchor_top = 0.0
		_slot_label.anchor_right = 0.5
		_slot_label.offset_top = slot_size - 12
		_slot_label.add_theme_color_override("font_color", MT.TEXT_MUTED)
		_slot_label.add_theme_font_size_override("font_size", 9)
		_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_slot_label)

	_button = Button.new()
	_button.name = "ClickArea"
	_button.flat = true
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_button.add_theme_stylebox_override("focus", MT.focus_ring())
	_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_button.pressed.connect(_on_clicked)
	_button.gui_input.connect(_on_gui_input)
	add_child(_button)

	gui_input.connect(_on_gui_input)


func _refresh_border() -> void:
	_bg_panel.add_theme_stylebox_override("panel", MT.panel(MT.BG_DEEP, MT.SELECTED_TINT if selected else MT.BORDER_SUBTLE, MT.RADIUS_MD, 2 if selected else 1))


func _on_clicked() -> void:
	clicked.emit(slot_name, item_id)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_clicked.emit(slot_name, item_id)
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and item_id != "":
			var drag_handler := get_node_or_null("/root/DragHandler") as DragHandler
			if drag_handler != null and drag_handler.has_method("begin_drag"):
				drag_handler.begin_drag(self, item_id, count)


func set_empty() -> void:
	item_id = ""
	count = 0
	_icon.refresh("", 0)
