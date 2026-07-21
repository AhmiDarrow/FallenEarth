## UIHelper — Central factory for all themed UI elements.
## Every UI screen should use UIHelper methods instead of creating
## raw Control nodes, ensuring all UI pulls from MasterTheme.
## Use: `UIHelper.make_button(...)` — no instantiation needed.
class_name UIHelper
extends RefCounted

const MT = preload("res://assets/ui/MasterTheme.gd")

# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

static func make_button(text: String, style_variant: String = "primary",
		min_w: int = 0, min_h: int = 36, is_toggle: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, min_h)
	btn.toggle_mode = is_toggle
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL if min_w == 0 else Control.SIZE_SHRINK_BEGIN
	MT.apply_button_style(btn, style_variant)
	return btn


static func make_icon_button(icon_text: String, style_variant: String = "ghost",
		min_w: int = 36, min_h: int = 28) -> Button:
	var btn := Button.new()
	btn.text = icon_text
	btn.custom_minimum_size = Vector2(min_w, min_h)
	MT.apply_button_style(btn, style_variant)
	return btn


# ---------------------------------------------------------------------------
# Labels
# ---------------------------------------------------------------------------

static func make_label(text: String, font_size: int = MT.FS_BODY,
		color: Color = MT.TEXT_PRIMARY) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


static func make_small_label(text: String, color: Color = MT.TEXT_SECONDARY) -> Label:
	return make_label(text, MT.FS_SMALL, color)


static func make_muted_label(text: String) -> Label:
	return make_label(text, MT.FS_SMALL, MT.TEXT_MUTED)


static func make_accent_label(text: String, font_size: int = MT.FS_BODY) -> Label:
	return make_label(text, font_size, MT.TEXT_ACCENT)

static func make_success_label(text: String, font_size: int = MT.FS_BODY) -> Label:
	return make_label(text, font_size, MT.TEXT_SUCCESS)

static func make_danger_label(text: String, font_size: int = MT.FS_BODY) -> Label:
	return make_label(text, font_size, MT.TEXT_DANGER)


# ---------------------------------------------------------------------------
# Rich text labels
# ---------------------------------------------------------------------------

static func make_rich_header(text: String, min_height: int = 28) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.custom_minimum_size = Vector2(0, min_height)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rtl.bbcode_enabled = true
	rtl.text = text
	rtl.add_theme_color_override("font_color", MT.TEXT_PRIMARY)
	rtl.add_theme_font_size_override("font_size", MT.FS_H3)
	return rtl


static func make_rich_section(text: String, min_height: int = 28, color: Color = MT.TEXT_ACCENT) -> RichTextLabel:
	var rtl := make_rich_header(text, min_height)
	rtl.add_theme_color_override("font_color", color)
	return rtl


# ---------------------------------------------------------------------------
# Text inputs
# ---------------------------------------------------------------------------

static func make_line_edit(placeholder: String = "", min_w: int = 200, min_h: int = 30) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(min_w, min_h)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.add_theme_color_override("font_color", MT.TEXT_PRIMARY)
	le.add_theme_color_override("placeholder_color", MT.TEXT_MUTED)
	return le


# ---------------------------------------------------------------------------
# Selection controls
# ---------------------------------------------------------------------------

static func make_checkbox(text: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.add_theme_color_override("font_color", MT.TEXT_PRIMARY)
	cb.add_theme_font_size_override("font_size", MT.FS_BODY)
	return cb


static func make_option_button(items: Array[String] = [], min_w: int = 200, min_h: int = 30) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(min_w, min_h)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		ob.add_item(item)
	return ob


# ---------------------------------------------------------------------------
# Sliders
# ---------------------------------------------------------------------------

static func make_slider(min_val: float = 0.0, max_val: float = 1.0,
		step_val: float = 0.05, default_val: float = 0.7, min_w: int = 120) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = min_val
	sl.max_value = max_val
	sl.step = step_val
	sl.value = default_val
	sl.custom_minimum_size = Vector2(min_w, 20)
	return sl


# ---------------------------------------------------------------------------
# Progress bars
# ---------------------------------------------------------------------------

static func make_progress_bar(min_w: int = 80, min_h: int = 16,
		fill_color: Color = MT.HP_FILL, bg_color: Color = MT.OVERLAY_DARK) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(min_w, min_h)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = true
	bar.add_theme_stylebox_override("background", MT.bar_background())
	var fill_style := MT.bar_fill(fill_color)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_color_override("font_color", MT.TEXT_PRIMARY)
	bar.add_theme_font_size_override("font_size", MT.FS_TINY)
	return bar


# ---------------------------------------------------------------------------
# Containers
# ---------------------------------------------------------------------------

static func make_vbox(separation: int = 8, expand_h: bool = false, expand_v: bool = false) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", separation)
	if expand_h: vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v: vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return vb


static func make_hbox(separation: int = 8, expand_h: bool = false) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", separation)
	if expand_h: hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return hb


static func make_margin(amount: int = 16) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", amount)
	m.add_theme_constant_override("margin_right", amount)
	m.add_theme_constant_override("margin_top", amount)
	m.add_theme_constant_override("margin_bottom", amount)
	return m


static func make_center_hbox() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	return hb


# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

static func make_panel(bg: Color = MT.BG_DEEP, border: Color = MT.BORDER_SUBTLE,
		radius: int = MT.RADIUS_LG, border_width: int = 1,
		min_size: Vector2 = Vector2()) -> PanelContainer:
	var panel := PanelContainer.new()
	if min_size != Vector2():
		panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", MT.panel(bg, border, radius, border_width))
	return panel


static func make_surface_panel(min_size: Vector2 = Vector2()) -> PanelContainer:
	return make_panel(MT.BG_SURFACE, MT.BORDER_SUBTLE, MT.RADIUS_MD, 1, min_size)


static func make_elevated_panel(min_size: Vector2 = Vector2()) -> PanelContainer:
	return make_panel(MT.BG_ELEVATED, MT.BORDER_STRONG, MT.RADIUS_LG, 1, min_size)


# ---------------------------------------------------------------------------
# Scrollable containers
# ---------------------------------------------------------------------------

static func make_scroll_container(expand_v: bool = true) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v:
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return sc


static func make_scrollable_vbox(parent: PanelContainer, separation: int = 3) -> VBoxContainer:
	var scroll := make_scroll_container()
	parent.add_child(scroll)
	var vbox := make_vbox(separation, true, true)
	scroll.add_child(vbox)
	return vbox


static func make_scrollable_section(parent: PanelContainer, header_text: String,
		separation: int = 4) -> VBoxContainer:
	var vbox := make_vbox(separation, true, true)
	parent.add_child(vbox)
	var header := make_rich_section(header_text)
	vbox.add_child(header)
	var scroll := make_scroll_container()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var inner := make_vbox(separation, true, true)
	scroll.add_child(inner)
	return inner


# ---------------------------------------------------------------------------
# Tabs
# ---------------------------------------------------------------------------

static func make_tab_container() -> TabContainer:
	var tc := TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return tc


# ---------------------------------------------------------------------------
# Separators
# ---------------------------------------------------------------------------

static func make_separator() -> HSeparator:
	return HSeparator.new()


# ---------------------------------------------------------------------------
# Backdrop
# ---------------------------------------------------------------------------

static func make_backdrop(color: Color = MT.OVERLAY_DARK) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = color
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_STOP
	return cr


static func apply_backdrop(parent: Node, color: Color = MT.OVERLAY_DARK) -> ColorRect:
	var cr := make_backdrop(color)
	parent.add_child(cr)
	return cr


# ---------------------------------------------------------------------------
# Input rows (label + control pairs)
# ---------------------------------------------------------------------------

static func make_option_row(parent: Control, label_text: String,
		label_w: int = 120, control_w: int = 280) -> OptionButton:
	var hbox := make_hbox(8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	var lbl := make_label(label_text, MT.FS_BODY, MT.TEXT_SECONDARY)
	lbl.custom_minimum_size = Vector2(label_w, 0)
	hbox.add_child(lbl)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(control_w, 30)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(ob)
	return ob


static func make_check_row(parent: Control, label_text: String,
		label_w: int = 120) -> CheckBox:
	var hbox := make_hbox(8)
	parent.add_child(hbox)
	var lbl := make_label(label_text, MT.FS_BODY, MT.TEXT_SECONDARY)
	lbl.custom_minimum_size = Vector2(label_w, 0)
	hbox.add_child(lbl)
	var cb := CheckBox.new()
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.add_theme_color_override("font_color", MT.TEXT_PRIMARY)
	hbox.add_child(cb)
	return cb


static func make_slider_row(parent: Control, label_text: String,
		label_w: int = 120, slider_w: int = 200,
		default_val: float = 0.7) -> HSlider:
	var hbox := make_hbox(8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	var lbl := make_label(label_text, MT.FS_BODY, MT.TEXT_SECONDARY)
	lbl.custom_minimum_size = Vector2(label_w, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = default_val
	sl.custom_minimum_size = Vector2(slider_w, 20)
	hbox.add_child(sl)
	return sl


# ---------------------------------------------------------------------------
# Modal screen builder
# ---------------------------------------------------------------------------

static func build_modal_screen(parent_size: Vector2,
		title: String, panel_w: int = 300, panel_h: int = 300) -> VBoxContainer:
	var panel := PanelContainer.new()
	if parent_size.x > 0:
		panel.offset_left = parent_size.x * 0.5 - panel_w * 0.5
		panel.offset_right = parent_size.x * 0.5 + panel_w * 0.5
		panel.offset_top = parent_size.y * 0.5 - panel_h * 0.5
		panel.offset_bottom = parent_size.y * 0.5 + panel_h * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", MT.panel(MT.BG_SURFACE, MT.BORDER_STRONG, MT.RADIUS_LG, 2))

	var margin := make_margin(16)
	panel.add_child(margin)

	var vbox := make_vbox(12)
	margin.add_child(vbox)

	var title_lbl := make_accent_label(title, MT.FS_H2)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	vbox.add_child(make_separator())

	return vbox


# ---------------------------------------------------------------------------
# Responsive screen helpers
# ---------------------------------------------------------------------------

## Make a scroll container that wraps an existing child VBoxContainer in place.
## Preserves child node paths (the VBox stays at the same tree depth).
## The scroll container fills available space; the VBox takes its min height.
static func make_scrollable(vbox: VBoxContainer) -> ScrollContainer:
	var parent := vbox.get_parent()
	var idx := vbox.get_index()
	var aL := vbox.anchor_left
	var aR := vbox.anchor_right
	var aT := vbox.anchor_top
	var aB := vbox.anchor_bottom
	var oL := vbox.offset_left
	var oR := vbox.offset_right
	var oT := vbox.offset_top
	var oB := vbox.offset_bottom
	parent.remove_child(vbox)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = aL
	scroll.anchor_right = aR
	scroll.anchor_top = aT
	scroll.anchor_bottom = aB
	scroll.offset_left = oL
	scroll.offset_right = oR
	scroll.offset_top = oT
	scroll.offset_bottom = oB
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	parent.move_child(scroll, idx)
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	return scroll


## Create a full-page responsive shell with backdrop and a scrollable area.
## Returns {"backdrop": ColorRect, "scroll": ScrollContainer, "content": VBoxContainer}.
static func make_page_shell(parent: Control, bg_color: Color = MT.BG_DEEP,
		margin_l: float = 0.1, margin_t: float = 0.05,
		margin_r: float = 0.1, margin_b: float = 0.08,
		separation: int = 8) -> Dictionary:
	var backdrop := ColorRect.new()
	backdrop.color = bg_color
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(backdrop)

	var scroll := ScrollContainer.new()
	scroll.set_anchor(SIDE_LEFT, margin_l)
	scroll.set_anchor(SIDE_TOP, margin_t)
	scroll.set_anchor(SIDE_RIGHT, margin_r)
	scroll.set_anchor(SIDE_BOTTOM, margin_b)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var content := make_vbox(separation, true, false)
	scroll.add_child(content)
	return {"backdrop": backdrop, "scroll": scroll, "content": content}
