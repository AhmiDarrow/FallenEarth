class_name BattleResultsUI
extends Control
## End-of-battle results panel. Shows XP, EC, and loot gained on
## victory, or a defeat message on loss. A "Continue" button dismisses
## the panel and triggers a callback.

const UIBackgrounds = preload("res://scripts/UIBackgrounds.gd")
const COLOR_BG := Color(0.04, 0.04, 0.08, 0.94)
const COLOR_BORDER_WIN := Color(0.85, 0.75, 0.30, 1.0)
const COLOR_BORDER_LOSS := Color(0.75, 0.25, 0.25, 1.0)
const COLOR_TITLE := Color(1.0, 0.95, 0.80)
const COLOR_LABEL := Color(0.85, 0.85, 0.95)
const COLOR_VALUE := Color(1.0, 0.97, 0.92)
const COLOR_LOOT := Color(0.60, 0.90, 0.65)
const COLOR_BUTTON := Color(0.95, 0.85, 0.55)
const COLOR_BUTTON_BORDER := Color(0.45, 0.45, 0.55, 1.0)

var _on_continue: Callable = Callable()


func setup(victory: bool, xp: int, ec: int, loot: Array, cont: Callable) -> void:
	_on_continue = cont
	# Wait one frame so the CanvasLayer has proper viewport info
	await get_tree().process_frame
	_build_ui(victory, xp, ec, loot)


func _build_ui(victory: bool, xp: int, ec: int, loot: Array) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	# Full-screen dark backdrop
	position = Vector2.ZERO
	size = vp_size
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Force size in case anchors don't propagate in CanvasLayer
	size = vp_size

	# Dark background panel covering full screen
	var bg_panel := PanelContainer.new()
	bg_panel.position = Vector2.ZERO
	bg_panel.size = vp_size
	bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_panel)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg_panel.add_theme_stylebox_override("panel", bg_sb)
	# Add modal texture behind the dark panel
	var bg_rect := ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = Color(0, 0, 0, 0.001)
	add_child(bg_rect)
	move_child(bg_rect, 0)
	UIBackgrounds.apply_modal_bg(bg_rect)

	# Center results box
	var panel_w: float = min(440.0, vp_size.x * 0.4)
	var panel_h: float = min(340.0, vp_size.y * 0.5)
	var panel_x: float = (vp_size.x - panel_w) * 0.5
	var panel_y: float = (vp_size.y - panel_h) * 0.5

	var panel := PanelContainer.new()
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_w, panel_h)
	add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	var border_color: Color = COLOR_BORDER_WIN if victory else COLOR_BORDER_LOSS
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

	# Inner margin
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

	# Title
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.text = "VICTORY" if victory else "DEFEAT"
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	if victory:
		# XP
		vbox.add_child(_make_row("Experience Gained:", str(xp)))
		# EC
		vbox.add_child(_make_row("EarthCoin Gained:", str(ec)))
		# Loot
		if loot.size() > 0:
			var loot_label := Label.new()
			loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			loot_label.add_theme_font_size_override("font_size", 14)
			loot_label.add_theme_color_override("font_color", COLOR_LABEL)
			loot_label.text = "Loot:"
			vbox.add_child(loot_label)
			for drop in loot:
				var item_id: String = str(drop.get("item_id", "?"))
				var qty: int = int(drop.get("qty", 1))
				var display_name := _resolve_item_name(item_id)
				var loot_line := Label.new()
				loot_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				loot_line.add_theme_font_size_override("font_size", 13)
				loot_line.add_theme_color_override("font_color", COLOR_LOOT)
				loot_line.add_theme_color_override("font_outline_color", Color.BLACK)
				loot_line.add_theme_constant_override("outline_size", 2)
				loot_line.text = "  %s x%d" % [display_name, qty]
				vbox.add_child(loot_line)
		else:
			var no_loot := Label.new()
			no_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			no_loot.add_theme_font_size_override("font_size", 13)
			no_loot.add_theme_color_override("font_color", COLOR_LABEL)
			no_loot.text = "No loot dropped."
			vbox.add_child(no_loot)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Continue button
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(160, 40)
	btn.pressed.connect(_on_continue_pressed)
	btn_container.add_child(btn)
	ButtonStyleHelper.apply_primary(btn)
	btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))


func _make_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COLOR_LABEL)
	lbl.text = label_text
	row.add_child(lbl)
	var val := Label.new()
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", COLOR_VALUE)
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.add_theme_constant_override("outline_size", 2)
	val.text = value_text
	row.add_child(val)
	return row


func _resolve_item_name(item_id: String) -> String:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv != null and inv.has_method("get_item_name"):
		return str(inv.call("get_item_name", item_id))
	return item_id.replace("_", " ").capitalize()


func _on_continue_pressed() -> void:
	if _on_continue.is_valid():
		_on_continue.call()
