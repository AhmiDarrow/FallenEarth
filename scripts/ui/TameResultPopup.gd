class_name TameResultPopup
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")

var _on_dismiss: Callable = Callable()


func setup(result: Dictionary, dismiss: Callable) -> void:
	_on_dismiss = dismiss
	await get_tree().process_frame
	_build_ui(result)


func _build_ui(result: Dictionary) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg_panel := PanelContainer.new()
	bg_panel.position = Vector2.ZERO
	bg_panel.size = vp_size
	bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_panel)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg_panel.add_theme_stylebox_override("panel", bg_sb)

	var success: bool = bool(result.get("success", false))
	var mob_name: String = str(result.get("mob_name", "Mob"))
	var mob_type: String = str(result.get("tamable_type", "companion"))
	var chance_pct: int = int(round(float(result.get("chance", 0.0)) * 100.0))

	var panel_w: float = min(380.0, vp_size.x * 0.35)
	var panel_h: float = min(260.0, vp_size.y * 0.4)
	var panel_x: float = (vp_size.x - panel_w) * 0.5
	var panel_y: float = (vp_size.y - panel_h) * 0.5

	var panel := PanelContainer.new()
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_w, panel_h)
	add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.08, 0.94)
	var border_color: Color = Color(0.439, 0.608, 0.478) if success else Color(0.769, 0.251, 0.251)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = border_color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.text = "Tame Successful!" if success else "Tame Failed"
	vbox.add_child(title)

	var mob_label := Label.new()
	mob_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mob_label.add_theme_font_size_override("font_size", 16)
	mob_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	mob_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mob_label.add_theme_constant_override("outline_size", 2)
	mob_label.text = mob_name
	vbox.add_child(mob_label)

	var info_label := Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 1)
	if success:
		info_label.text = "Joined as %s" % mob_type
	else:
		info_label.text = "Chance was %d%%" % chance_pct
	vbox.add_child(info_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	var btn := Button.new()
	btn.text = "OK"
	btn.custom_minimum_size = Vector2(120, 36)
	btn.pressed.connect(_on_dismiss_pressed)
	btn_container.add_child(btn)
	MT.apply_primary(btn)


func _on_dismiss_pressed() -> void:
	if _on_dismiss.is_valid():
		_on_dismiss.call()
	queue_free()
