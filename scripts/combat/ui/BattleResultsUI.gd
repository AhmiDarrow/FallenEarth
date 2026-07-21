class_name BattleResultsUI
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
## End-of-battle results panel. Shows XP, EC, and loot gained on
## victory, or a defeat message on loss. A "Continue" button dismisses
## the panel and triggers a callback.

var COLOR_BG := MT.OVERLAY_DARK
var COLOR_BORDER_WIN := MT.ACCENT_PRIMARY
var COLOR_BORDER_LOSS := MT.ACCENT_DANGER
var COLOR_TITLE := MT.TEXT_PRIMARY
var COLOR_LABEL := MT.TEXT_SECONDARY
var COLOR_VALUE := MT.TEXT_PRIMARY
var COLOR_LOOT := MT.TEXT_SUCCESS

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
	var bg_panel := UH.make_backdrop()
	bg_panel.position = Vector2.ZERO
	bg_panel.size = vp_size
	add_child(bg_panel)

	# Center results box
	var panel_w: float = min(440.0, vp_size.x * 0.4)
	var panel_h: float = min(340.0, vp_size.y * 0.5)
	var panel_x: float = (vp_size.x - panel_w) * 0.5
	var panel_y: float = (vp_size.y - panel_h) * 0.5

	var border_color: Color = COLOR_BORDER_WIN if victory else COLOR_BORDER_LOSS
	var panel := UH.make_panel(COLOR_BG, border_color, 8, 3)
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_w, panel_h)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(panel)

	# Inner margin
	var margin := UH.make_margin(24)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := UH.make_vbox(12)
	margin.add_child(vbox)

	# Title
	var title := UH.make_label("VICTORY" if victory else "DEFEAT", 28, COLOR_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	# Separator
	var sep := UH.make_separator()
	vbox.add_child(sep)

	if victory:
		# XP
		vbox.add_child(_make_row("Experience Gained:", str(xp)))
		# EC
		vbox.add_child(_make_row("EarthCoin Gained:", str(ec)))
		# Loot
		if loot.size() > 0:
			var loot_label := UH.make_label("Loot:", 14, COLOR_LABEL)
			loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			vbox.add_child(loot_label)
			for drop in loot:
				var item_id: String = str(drop.get("item_id", "?"))
				var qty: int = int(drop.get("count", 1))
				var display_name := _resolve_item_name(item_id)
				var loot_line := UH.make_label("  %s x%d" % [display_name, qty], 13, COLOR_LOOT)
				loot_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				loot_line.add_theme_color_override("font_outline_color", Color.BLACK)
				loot_line.add_theme_constant_override("outline_size", 2)
				vbox.add_child(loot_line)
		else:
			var no_loot := UH.make_muted_label("No loot dropped.")
			no_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			vbox.add_child(no_loot)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Continue button
	var btn_container := UH.make_center_hbox()
	vbox.add_child(btn_container)

	var btn := UH.make_button("Continue", "primary", 160, 40)
	btn.pressed.connect(_on_continue_pressed)
	btn_container.add_child(btn)

	UH.make_scrollable(vbox)


func _make_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := UH.make_hbox(8)
	var lbl := UH.make_label(label_text, 15, COLOR_LABEL)
	row.add_child(lbl)
	var val := UH.make_label(value_text, 15, COLOR_VALUE)
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.add_theme_constant_override("outline_size", 2)
	row.add_child(val)
	return row


func _resolve_item_name(item_id: String) -> String:
	var inv: Node = get_node_or_null("/root/InventoryHandler")
	if inv != null and inv.has_method("get_item_name"):
		return str(inv.call("get_item_name", item_id))
	return item_id.replace("_", " ").capitalize()


func _on_continue_pressed() -> void:
	if _on_continue.is_valid():
		_on_continue.call()
