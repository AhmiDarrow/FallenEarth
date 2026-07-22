## ContextMenu — Themed bordered popup for world interactions (harvest, etc.).
## Click resource → Chop/Mine button + info. X (top-right) or Escape closes.
class_name ContextMenu extends Control

signal action_selected(action: String, target_cell: Vector2i)

const UIHelper = preload("res://scripts/ui/UIHelper.gd")
const MT = preload("res://assets/ui/MasterTheme.gd")

const PANEL_MIN_W := 220.0

var _panel: PanelContainer
var _target_cell: Vector2i


func show_at(screen_pos: Vector2, title: String, options: Array, target_cell: Vector2i, info_lines: Array = []) -> void:
	_target_cell = target_cell
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dimmed full-screen catcher — click outside closes.
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.35)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(
		"panel",
		MT.panel(MT.BG_SURFACE, MT.BORDER_STRONG, MT.RADIUS_MD, 2)
	)
	_panel.custom_minimum_size = Vector2(PANEL_MIN_W, 0)
	add_child(_panel)

	var root := UIHelper.make_vbox(6, true, true)
	root.add_theme_constant_override("separation", 6)
	_panel.add_child(root)

	# Title row: name + X close
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title_lbl := UIHelper.make_accent_label(title if not title.is_empty() else "Interact", 15)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_lbl)

	var close_btn := UIHelper.make_icon_button("✕", "ghost", 28, 28)
	close_btn.tooltip_text = "Close (Esc)"
	close_btn.pressed.connect(_dismiss)
	header.add_child(close_btn)

	# Info lines
	for line in info_lines:
		var info := UIHelper.make_label(str(line), 11, MT.TEXT_SECONDARY)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(PANEL_MIN_W - 24, 0)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(info)

	var sep := ColorRect.new()
	sep.color = MT.BORDER_SUBTLE
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sep)

	var has_action := false
	for opt in options:
		if not (opt is Dictionary):
			continue
		var action: String = str(opt.get("action", ""))
		var label: String = str(opt.get("label", ""))
		var disabled: bool = bool(opt.get("disabled", false)) or action.is_empty()
		if disabled:
			var tip := UIHelper.make_button(label, "ghost", int(PANEL_MIN_W - 24), 34)
			tip.disabled = true
			tip.modulate = Color(1, 1, 1, 0.55)
			root.add_child(tip)
			continue
		has_action = true
		var style := "primary"
		if action == "gather":
			style = "primary"
		var btn := UIHelper.make_button(label, style, int(PANEL_MIN_W - 24), 36)
		btn.pressed.connect(_on_action.bind(action))
		root.add_child(btn)

	if not has_action and options.is_empty():
		var none := UIHelper.make_label("No actions", 11, MT.TEXT_MUTED)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(none)

	var hint := UIHelper.make_label("Esc to close", 10, MT.TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	_panel.position = screen_pos + Vector2(8, 8)
	_panel.size = Vector2.ZERO
	call_deferred("_finish_layout")
	grab_focus()


func _finish_layout() -> void:
	if not is_instance_valid(_panel):
		return
	# Let container compute size from children.
	_panel.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(_panel):
		return
	_fit_on_screen()


func _fit_on_screen() -> void:
	if not is_instance_valid(_panel):
		return
	var vs := get_viewport_rect().size
	var sz: Vector2 = _panel.get_combined_minimum_size()
	if _panel.size.x < sz.x or _panel.size.y < sz.y:
		_panel.size = sz
	if _panel.position.x + _panel.size.x > vs.x - 8:
		_panel.position.x = vs.x - _panel.size.x - 8
	if _panel.position.y + _panel.size.y > vs.y - 8:
		_panel.position.y = vs.y - _panel.size.y - 8
	if _panel.position.x < 8:
		_panel.position.x = 8
	if _panel.position.y < 8:
		_panel.position.y = 8


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_dismiss()
			get_viewport().set_input_as_handled()


func _on_action(action: String) -> void:
	if action.is_empty():
		return
	action_selected.emit(action, _target_cell)
	_dismiss()


func _dismiss() -> void:
	queue_free()
