## MountScreen — Tab showing all tamed mounts with Set Active / Release / Rename.
class_name MountScreen
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
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
	var hbox := UH.make_hbox(12)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	# Left: mount list
	var left_panel := UH.make_surface_panel(Vector2(240, 0))
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_panel)
	var left_vbox := UH.make_vbox()
	left_panel.add_child(left_vbox)

	var title := UH.make_accent_label("[ Mounts ]", MT.FS_H2)
	left_vbox.add_child(title)

	var scroll := UH.make_scroll_container()
	left_vbox.add_child(scroll)

	_mount_list = UH.make_vbox(4, true, false)
	scroll.add_child(_mount_list)

	# Right: detail panel
	var right_panel := UH.make_surface_panel(Vector2(280, 260))
	hbox.add_child(right_panel)
	var right_vbox := UH.make_vbox()
	right_panel.add_child(right_vbox)

	var detail_title := UH.make_accent_label("[ Mount Details ]", MT.FS_H2)
	right_vbox.add_child(detail_title)

	_detail_name = UH.make_label("", MT.FS_BODY, MT.TEXT_PRIMARY)
	right_vbox.add_child(_detail_name)

	_detail_species = UH.make_label("", MT.FS_BODY, MT.TEXT_PRIMARY)
	right_vbox.add_child(_detail_species)

	_detail_speed = UH.make_label("", MT.FS_BODY, MT.TEXT_PRIMARY)
	right_vbox.add_child(_detail_speed)

	_detail_active = UH.make_label("", MT.FS_BODY, MT.TEXT_PRIMARY)
	right_vbox.add_child(_detail_active)

	right_vbox.add_spacer(true)

	# Action buttons
	var btn_hbox := UH.make_hbox(8)
	right_vbox.add_child(btn_hbox)

	var set_active_btn := UH.make_button("Set Active")
	set_active_btn.pressed.connect(_on_set_active)
	btn_hbox.add_child(set_active_btn)

	var rename_btn := UH.make_button("Rename")
	rename_btn.pressed.connect(_on_rename)
	btn_hbox.add_child(rename_btn)

	var release_btn := UH.make_button("Release")
	release_btn.pressed.connect(_on_release)
	btn_hbox.add_child(release_btn)

	UH.make_scrollable(right_vbox)


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
		var cname: String = str(mob.get("name", "Mount"))
		var btn := UH.make_button(cname, "primary", 0, 32, true)
		var mid: String = str(mob.get("id", ""))
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

	var popup := UH.make_panel(MT.OVERLAY_DARK, MT.BORDER_SUBTLE, MT.RADIUS_LG, 2, Vector2(280, 120))
	popup.name = "RenamePopup"
	popup.position = Vector2(size.x * 0.5 - 140, size.y * 0.5 - 60)
	add_child(popup)

	var vbox := UH.make_vbox(8)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(vbox)

	var lbl := UH.make_label("Enter new name:")
	vbox.add_child(lbl)

	var line_edit := UH.make_line_edit("", 0, 30)
	line_edit.text = cur_name
	line_edit.select_all()
	vbox.add_child(line_edit)

	var btn_hbox := UH.make_center_hbox()
	vbox.add_child(btn_hbox)

	var ok_btn := UH.make_button("OK", "primary", 80, 30)
	btn_hbox.add_child(ok_btn)

	var cancel_btn := UH.make_button("Cancel", "secondary", 80, 30)
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
	var lbl := UH.make_muted_label("No tamed mounts yet.")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mount_list.add_child(lbl)
