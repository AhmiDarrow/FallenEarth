## KeybindsScreen — UI for viewing and rebinding all keybindings.
##
## Shows a scrollable list organized by category. Click a binding
## to enter rebind mode — the next key press becomes the new binding.
## Press Escape to cancel a rebind. "Reset All" restores defaults.
class_name KeybindsScreen
extends Control

const KM_PATH := "/root/KeybindManager"
const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

var _list_vbox: VBoxContainer
var _status_label: Label
var _rebinding_label: Label
var _active_rows: Dictionary = {}  # action_name → HBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_populate_bindings()


func _build_ui() -> void:
	var outer := UH.make_vbox(8)
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	# Title
	var title := UH.make_rich_header("[center][b]KEYBINDS[/b][/center]")
	title.fit_content = true
	title.custom_minimum_size = Vector2(0, 36)
	outer.add_child(title)

	# Rebinding prompt (hidden by default)
	_rebinding_label = UH.make_label("Press a key to bind...", 16, MT.ACCENT_PRIMARY)
	_rebinding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rebinding_label.visible = false
	outer.add_child(_rebinding_label)

	# Scroll container
	var scroll := UH.make_scroll_container()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_list_vbox = UH.make_vbox(2, true, false)
	scroll.add_child(_list_vbox)

	# Bottom row: status + buttons
	var bottom := UH.make_hbox(12)
	outer.add_child(bottom)

	_status_label = UH.make_label("", MT.FS_BODY, MT.TEXT_MUTED)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_status_label)

	var reset_btn := UH.make_button("Reset All", "primary", 120, 32)
	reset_btn.pressed.connect(_on_reset_all)
	bottom.add_child(reset_btn)


func _populate_bindings() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()
	_active_rows.clear()

	var km: Node = get_node_or_null(KM_PATH)
	if km == null:
		return

	var groups: Array = km.get_display_groups() as Array
	for group in groups:
		var group_label: String = group[0]
		var actions: Array = group[1] as Array

		# Section header
		var header := UH.make_label("  %s" % group_label, 13, MT.ACCENT_NEON)
		header.custom_minimum_size = Vector2(0, 24)
		_list_vbox.add_child(header)

		for action in actions:
			var row := _make_row(action, km)
			_list_vbox.add_child(row)
			_active_rows[action] = row


func _make_row(action: String, km: Node) -> HBoxContainer:
	var row := UH.make_hbox(8)
	row.custom_minimum_size = Vector2(0, 30)

	# Action label
	var lbl := UH.make_label("    %s" % km.get_label(action))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", MT.TEXT_SECONDARY)
	row.add_child(lbl)

	# Key binding button
	var keycode: int = km.get_keycode(action)
	var btn := UH.make_button(km.get_key_name(keycode), "primary", 140, 28)
	btn.name = "Btn_%s" % action
	btn.pressed.connect(_on_bind_pressed.bind(action))
	row.add_child(btn)

	# Reset button
	var reset_btn := UH.make_button("x", "ghost", 28, 28)
	reset_btn.tooltip_text = "Reset to default"
	reset_btn.pressed.connect(_on_reset_action.bind(action))
	row.add_child(reset_btn)

	return row


func _on_bind_pressed(action: String) -> void:
	var km: Node = get_node_or_null(KM_PATH)
	if km == null:
		return

	# Show rebinding prompt
	_rebinding_label.visible = true
	_status_label.text = "Press a key for: %s (Escape to cancel)" % km.get_label(action)
	# Highlight the button
	var btn: Button = _active_rows[action].get_node_or_null("Btn_%s" % action) if _active_rows.has(action) else null
	if btn != null:
		btn.text = "..."

	km.start_rebind(action, _on_rebind_complete.bind(action))


func _on_rebind_complete(keycode: int, action: String) -> void:
	_rebinding_label.visible = false
	var km: Node = get_node_or_null(KM_PATH)
	if km == null:
		return

	var btn: Button = _active_rows[action].get_node_or_null("Btn_%s" % action) if _active_rows.has(action) else null
	if keycode == 0:
		_status_label.text = "Rebind cancelled."
		if btn != null:
			btn.text = km.get_key_name(km.get_keycode(action))
		return

	var result = km.apply_rebind(action, keycode)
	if result == OK:
		_status_label.text = "%s bound to %s" % [km.get_label(action), km.get_key_name(keycode)]
		if btn != null:
			btn.text = km.get_key_name(keycode)
	else:
		_status_label.text = str(result)
		if btn != null:
			btn.text = km.get_key_name(km.get_keycode(action))


func _on_reset_action(action: String) -> void:
	var km: Node = get_node_or_null(KM_PATH)
	if km == null:
		return
	km.reset_action(action)
	var btn: Button = _active_rows[action].get_node_or_null("Btn_%s" % action) if _active_rows.has(action) else null
	if btn != null:
		btn.text = km.get_key_name(km.get_keycode(action))
	_status_label.text = "%s reset to default." % km.get_label(action)


func _on_reset_all() -> void:
	var km: Node = get_node_or_null(KM_PATH)
	if km == null:
		return
	km.reset_all()
	_populate_bindings()
	_status_label.text = "All keybindings reset to defaults."
