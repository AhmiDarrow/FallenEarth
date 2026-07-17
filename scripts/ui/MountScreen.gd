## MountScreen — Tab showing all tamed mounts with Set Active / Release / Rename.
class_name MountScreen
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const TMM_PATH := "/root/TamedMobManager"

var _mount_list: VBoxContainer
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_species: Label
var _detail_speed: Label
var _detail_active: Label
var _selected_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)

	# Left: mount list
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(240, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_panel)
	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)

	var title := Label.new()
	title.text = "[ Mounts ]"
	title.add_theme_color_override("font_color", MT.TEXT_ACCENT)
	title.add_theme_font_size_override("font_size", MT.FS_H2)
	left_vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	_mount_list = VBoxContainer.new()
	_mount_list.add_theme_constant_override("separation", 4)
	_mount_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_mount_list)

	# Right: detail panel
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(280, 260)
	hbox.add_child(right_panel)
	var right_vbox := VBoxContainer.new()
	right_panel.add_child(right_vbox)

	var detail_title := Label.new()
	detail_title.text = "[ Mount Details ]"
	detail_title.add_theme_color_override("font_color", MT.TEXT_ACCENT)
	detail_title.add_theme_font_size_override("font_size", MT.FS_H2)
	right_vbox.add_child(detail_title)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", MT.FS_BODY)
	right_vbox.add_child(_detail_name)

	_detail_species = Label.new()
	_detail_species.add_theme_font_size_override("font_size", MT.FS_BODY)
	right_vbox.add_child(_detail_species)

	_detail_speed = Label.new()
	_detail_speed.add_theme_font_size_override("font_size", MT.FS_BODY)
	right_vbox.add_child(_detail_speed)

	_detail_active = Label.new()
	_detail_active.add_theme_font_size_override("font_size", MT.FS_BODY)
	right_vbox.add_child(_detail_active)

	right_vbox.add_spacer(true)

	# Action buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(btn_hbox)

	var set_active_btn := Button.new()
	set_active_btn.text = "Set Active"
	set_active_btn.pressed.connect(_on_set_active)
	btn_hbox.add_child(set_active_btn)

	var rename_btn := Button.new()
	rename_btn.text = "Rename"
	rename_btn.pressed.connect(_on_rename)
	btn_hbox.add_child(rename_btn)

	var release_btn := Button.new()
	release_btn.text = "Release"
	release_btn.pressed.connect(_on_release)
	btn_hbox.add_child(release_btn)


func _refresh() -> void:
	# Clear list
	for child in _mount_list.get_children():
		child.queue_free()

	var tmm: Node = get_node_or_null(TMM_PATH)
	if not is_instance_valid(tmm) or not tmm.has_method("get_mounts"):
		_no_mounts_label()
		return

	var mounts: Array = tmm.get_mounts()
	if mounts.is_empty():
		_no_mounts_label()
		return

	for m in mounts:
		if not (m is Dictionary):
			continue
		var mob: Dictionary = m as Dictionary
		var btn := Button.new()
		var mid: String = str(mob.get("id", ""))
		var cname: String = str(mob.get("custom_name", mob.get("name", "Mob")))
		btn.text = cname
		btn.custom_minimum_size = Vector2(0, 32)
		btn.toggle_mode = true
		btn.pressed.connect(_on_mount_selected.bind(mid))
		_mount_list.add_child(btn)
		if mid == _selected_id:
			btn.button_pressed = true

	_show_detail(_selected_id)


func _on_mount_selected(mid: String) -> void:
	_selected_id = mid
	_show_detail(mid)


func _on_set_active() -> void:
	if _selected_id.is_empty():
		return
	var tmm: Node = get_node_or_null(TMM_PATH)
	if is_instance_valid(tmm) and tmm.has_method("set_active_mount"):
		tmm.set_active_mount(_selected_id)
		_show_detail(_selected_id)


func _on_rename() -> void:
	if _selected_id.is_empty():
		return
	var tmm: Node = get_node_or_null(TMM_PATH)
	if not is_instance_valid(tmm) or not tmm.has_method("get_all_tamed"):
		return
	var mounts: Array = tmm.get_all_tamed()
	var cur_name: String = ""
	for m in mounts:
		if m is Dictionary and str(m.get("id", "")) == _selected_id:
			cur_name = str(m.get("custom_name", ""))
			break
	if cur_name.is_empty():
		return

	var popup := PanelContainer.new()
	popup.name = "RenamePopup"
	popup.position = Vector2(size.x * 0.5 - 140, size.y * 0.5 - 60)
	popup.custom_minimum_size = Vector2(280, 120)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.3, 0.3, 0.4)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	popup.add_theme_stylebox_override("panel", sb)
	add_child(popup)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Enter new name:"
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(lbl)

	var line_edit := LineEdit.new()
	line_edit.text = cur_name
	line_edit.select_all()
	vbox.add_child(line_edit)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_hbox)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	btn_hbox.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 30)
	btn_hbox.add_child(cancel_btn)

	var self_ref: WeakRef = weakref(self)
	ok_btn.pressed.connect(func():
		var new_name := line_edit.text.strip_edges()
		if not new_name.is_empty():
			var tmm2: Node = get_node_or_null(TMM_PATH)
			if is_instance_valid(tmm2) and tmm2.has_method("set_custom_name"):
				tmm2.set_custom_name(_selected_id, new_name)
		if self_ref.get_ref():
			_refresh()
			popup.queue_free()
	)
	cancel_btn.pressed.connect(func():
		popup.queue_free()
	)
	line_edit.text_submitted.connect(func(_text: String):
		ok_btn.pressed.emit()
	)
	line_edit.grab_focus()


func _on_release() -> void:
	if _selected_id.is_empty():
		return
	var tmm: Node = get_node_or_null(TMM_PATH)
	if is_instance_valid(tmm) and tmm.has_method("release_tamed"):
		tmm.release_tamed(_selected_id)
	_selected_id = ""
	_refresh()


func _show_detail(mid: String) -> void:
	if mid.is_empty():
		_detail_name.text = ""
		_detail_species.text = ""
		_detail_speed.text = ""
		_detail_active.text = ""
		return

	var tmm: Node = get_node_or_null(TMM_PATH)
	if not is_instance_valid(tmm) or not tmm.has_method("get_all_tamed"):
		return

	var mounts: Array = tmm.get_all_tamed()
	for m in mounts:
		if not (m is Dictionary):
			continue
		var mob: Dictionary = m as Dictionary
		if str(mob.get("id", "")) != mid:
			continue
		_detail_name.text = "Name: %s" % mob.get("custom_name", mob.get("name", "?"))
		_detail_species.text = "Species: %s" % mob.get("template_id", "?")
		var bonus: Dictionary = mob.get("mount_bonus", {})
		var spd: float = float(bonus.get("movement_speed_mult", 1.0))
		_detail_speed.text = "Speed: x%.2f" % spd
		var active_mount: Dictionary = tmm.get_active_mount()
		var is_active: bool = str(active_mount.get("id", "")) == mid
		_detail_active.text = "Status: %s" % ("ACTIVE" if is_active else "inactive")
		_detail_active.add_theme_color_override("font_color", MT.TEXT_SUCCESS if is_active else MT.TEXT_MUTED)
		return


func _no_mounts_label() -> void:
	var lbl := Label.new()
	lbl.text = "No tamed mounts yet."
	lbl.add_theme_color_override("font_color", MT.TEXT_MUTED)
	lbl.add_theme_font_size_override("font_size", MT.FS_BODY)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mount_list.add_child(lbl)
