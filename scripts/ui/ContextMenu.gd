class_name ContextMenu extends Control

signal action_selected(action: String, target_cell: Vector2i)

const UIHelper = preload("res://scripts/ui/UIHelper.gd")
const MT = preload("res://assets/ui/MasterTheme.gd")

var _panel: Panel
var _target_cell: Vector2i

func show_at(screen_pos: Vector2, title: String, options: Array, target_cell: Vector2i) -> void:
	_target_cell = target_cell
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", MT.panel(MT.BG_SURFACE, MT.BORDER_STRONG, MT.RADIUS_MD, 1))
	add_child(_panel)

	var vbox := UIHelper.make_vbox(2, true, true)
	_panel.add_child(vbox)

	var title_lbl := UIHelper.make_accent_label(title, 13)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.custom_minimum_size = Vector2(130, 0)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var sep := ColorRect.new()
	sep.color = MT.BORDER_SUBTLE
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	for opt in options:
		var btn := UIHelper.make_button(str(opt.get("label", "")), "ghost", 130, 28)
		var action: String = str(opt.get("action", ""))
		btn.pressed.connect(_on_action.bind(action))
		vbox.add_child(btn)

	_panel.position = screen_pos
	_panel.size = Vector2.ZERO
	await get_tree().process_frame
	_fit_on_screen()


func _fit_on_screen() -> void:
	var vs := get_viewport_rect().size
	if _panel.position.x + _panel.size.x > vs.x:
		_panel.position.x = vs.x - _panel.size.x
	if _panel.position.y + _panel.size.y > vs.y:
		_panel.position.y = vs.y - _panel.size.y
	if _panel.position.x < 0:
		_panel.position.x = 0
	if _panel.position.y < 0:
		_panel.position.y = 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var global_click := get_global_mouse_position()
		if is_instance_valid(_panel) and not _panel.get_global_rect().has_point(global_click):
			_dismiss()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_dismiss()


func _on_action(action: String) -> void:
	action_selected.emit(action, _target_cell)
	_dismiss()


func _dismiss() -> void:
	queue_free()
