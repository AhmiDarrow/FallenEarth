class_name ContextMenu extends Control

signal action_selected(action: String, target_cell: Vector2i)

const UIHelper = preload("res://scripts/ui/UIHelper.gd")
const MT = preload("res://assets/ui/MasterTheme.gd")

var _panel: Panel
var _target_cell: Vector2i

func show_at(screen_pos: Vector2, title: String, options: Array, target_cell: Vector2i, info_lines: Array = []) -> void:
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

	var vbox := UIHelper.make_vbox(4, true, true)
	_panel.add_child(vbox)

	var title_lbl := UIHelper.make_accent_label(title, 14)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.custom_minimum_size = Vector2(168, 0)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	for line in info_lines:
		var info := UIHelper.make_label(str(line), 11)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.modulate = MT.TEXT_SECONDARY
		info.custom_minimum_size = Vector2(168, 0)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(info)

	var sep := ColorRect.new()
	sep.color = MT.BORDER_SUBTLE
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var has_action := false
	for opt in options:
		var action: String = str(opt.get("action", ""))
		var label: String = str(opt.get("label", ""))
		if action.is_empty():
			var tip := UIHelper.make_label(label, 11)
			tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tip.modulate = Color(0.95, 0.7, 0.35)
			tip.custom_minimum_size = Vector2(168, 0)
			tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(tip)
			continue
		has_action = true
		var btn := UIHelper.make_button(label, "ghost", 168, 30)
		btn.pressed.connect(_on_action.bind(action))
		vbox.add_child(btn)

	if not has_action and options.is_empty():
		var none := UIHelper.make_label("No actions", 11)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(none)

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
