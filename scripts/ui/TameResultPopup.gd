class_name TameResultPopup
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

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

	var bg_panel := UH.make_panel(MT.OVERLAY_DARK, Color.TRANSPARENT, 0, 0)
	bg_panel.position = Vector2.ZERO
	bg_panel.size = vp_size
	bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_panel)

	var success: bool = bool(result.get("success", false))
	var mob_name: String = str(result.get("mob_name", "Mob"))
	var mob_type: String = str(result.get("tamable_type", "companion"))
	var chance_pct: int = int(round(float(result.get("chance", 0.0)) * 100.0))

	var panel_w: float = min(380.0, vp_size.x * 0.35)
	var panel_h: float = min(260.0, vp_size.y * 0.4)
	var panel_x: float = (vp_size.x - panel_w) * 0.5
	var panel_y: float = (vp_size.y - panel_h) * 0.5

	var border_color: Color = Color(0.439, 0.608, 0.478) if success else Color(0.769, 0.251, 0.251)
	var panel := UH.make_panel(Color(0.04, 0.04, 0.08, 0.94), border_color, 8, 3)
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_w, panel_h)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(panel)

	var margin := UH.make_margin(24)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := UH.make_vbox(12)
	margin.add_child(vbox)

	var title := UH.make_label("Tame Successful!" if success else "Tame Failed", 24, Color(1.0, 0.95, 0.80))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	var mob_label := UH.make_label(mob_name, 16, Color(0.85, 0.85, 0.95))
	mob_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mob_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mob_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(mob_label)

	var info_label := UH.make_label("", 13, Color(0.65, 0.62, 0.58))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

	var btn_container := UH.make_center_hbox()
	vbox.add_child(btn_container)

	var btn := UH.make_button("OK", "primary", 120, 36)
	btn.pressed.connect(_on_dismiss_pressed)
	btn_container.add_child(btn)

	UH.make_scrollable(vbox)


func _on_dismiss_pressed() -> void:
	if _on_dismiss.is_valid():
		_on_dismiss.call()
	queue_free()
