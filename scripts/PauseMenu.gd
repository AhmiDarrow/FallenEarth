## PauseMenu — In-game overlay with Save, Load, Options, Exit to Menu, Exit to Desktop.
## Instantiated as an overlay child; pauses the scene tree while remaining interactive.
class_name PauseMenu
extends Control

const UIBackgrounds = preload("res://scripts/UIBackgrounds.gd")

signal resumed()
signal save_requested()
signal load_requested()
signal options_requested()
signal exit_to_menu_requested()

var _save_popup: Window = null
var _load_popup: Window = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Background texture behind overlay
	var overlay := $Overlay as ColorRect
	if overlay != null:
		UIBackgrounds.apply_modal_bg(overlay)
	# Style buttons with design system
	ButtonStyleHelper.apply_primary($VBoxContainer/ResumeBtn)
	ButtonStyleHelper.apply_secondary($VBoxContainer/SaveBtn)
	ButtonStyleHelper.apply_secondary($VBoxContainer/LoadBtn)
	ButtonStyleHelper.apply_secondary($VBoxContainer/OptionsBtn)
	ButtonStyleHelper.apply_danger($VBoxContainer/ExitMenuBtn)
	ButtonStyleHelper.apply_danger($VBoxContainer/ExitDesktopBtn)
	# Wire signals
	$VBoxContainer/ResumeBtn.pressed.connect(_on_resume)
	$VBoxContainer/SaveBtn.pressed.connect(_on_save)
	$VBoxContainer/LoadBtn.pressed.connect(_on_load)
	$VBoxContainer/OptionsBtn.pressed.connect(_on_options)
	$VBoxContainer/ExitMenuBtn.pressed.connect(_on_exit_to_menu)
	$VBoxContainer/ExitDesktopBtn.pressed.connect(_on_exit_desktop)


func open() -> void:
	visible = true
	# Force full-viewport geometry since parent may not propagate layout
	var vp_size: Vector2 = get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = vp_size
	size = vp_size
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	move_to_front()
	get_tree().paused = true
	print("[PauseMenu] Opened. size=", size, " pos=", position)


func close() -> void:
	visible = false
	get_tree().paused = false
	print("[PauseMenu] Closed.")


func _on_resume() -> void:
	close()
	resumed.emit()


func _on_save() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var slots: Array[Dictionary] = _list_saves()
	_show_save_popup(slots, gs)


func _on_load() -> void:
	var slots: Array[Dictionary] = _list_saves()
	if slots.is_empty():
		return
	_show_load_popup(slots)


func _on_options() -> void:
	close()
	options_requested.emit()
	get_tree().change_scene_to_file("res://scenes/ui/Options.tscn")


func _on_exit_to_menu() -> void:
	close()
	exit_to_menu_requested.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_exit_desktop() -> void:
	get_tree().paused = false
	get_tree().quit()


# -- Save slot helpers --

func _list_saves() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in range(9):
		var path := "user://saves/slot_%d.json" % i
		if FileAccess.file_exists(path):
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if is_instance_valid(file):
				var data: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
				var c: Variant = data.get("character", {})
				if (not c is Dictionary) or c.is_empty():
					c = data.get("game_state", {})
				var nm: String = str(data.get("save_name", ""))
				if nm == "" and c is Dictionary:
					nm = c.get("name", c.get("id", "Untitled"))
				if nm == "":
					nm = "Slot %d" % i
				var race := ""
				var cls := ""
				if c is Dictionary:
					race = str(c.get("race", ""))
					cls = str(c.get("class", ""))
				slots.append({
					"slot": i,
					"name": nm,
					"race": race,
					"class": cls,
					"autosave": data.get("autosave", false),
				})
				file.close()
	return slots


func _show_save_popup(slots: Array[Dictionary], gs: GameState) -> void:
	if is_instance_valid(_save_popup):
		_save_popup.queue_free()

	_save_popup = Window.new()
	_save_popup.title = "Save Game"
	_save_popup.size = Vector2i(420, 320)
	_save_popup.unresizable = true
	_save_popup.transient = true
	_save_popup.exclusive = true
	_save_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_save_popup)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	_save_popup.add_child(root)

	var title := Label.new()
	title.text = "Select a slot to save:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for entry in slots:
		var btn := Button.new()
		var autosave_tag := " [autosave]" if entry.get("autosave", false) else ""
		var detail := ""
		if entry.get("race", "") != "":
			detail = " — %s / %s" % [entry["race"], entry.get("class", "?")]
		btn.text = "Slot %d: %s%s%s" % [entry["slot"], entry["name"], detail, autosave_tag]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(360, 36)
		var slot_id: int = int(entry["slot"])
		btn.pressed.connect(func() -> void:
			gs.save_game(slot_id)
			_save_popup.hide()
		)
		list.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _save_popup.hide())
	root.add_child(cancel)

	_save_popup.popup_centered()


func _show_load_popup(slots: Array[Dictionary]) -> void:
	if is_instance_valid(_load_popup):
		_load_popup.queue_free()

	_load_popup = Window.new()
	_load_popup.title = "Load Game"
	_load_popup.size = Vector2i(420, 320)
	_load_popup.unresizable = true
	_load_popup.transient = true
	_load_popup.exclusive = true
	_load_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_load_popup)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	_load_popup.add_child(root)

	var title := Label.new()
	title.text = "Select a save slot:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for entry in slots:
		var btn := Button.new()
		var autosave_tag := " [autosave]" if entry.get("autosave", false) else ""
		var detail := ""
		if entry.get("race", "") != "":
			detail = " — %s / %s" % [entry["race"], entry.get("class", "?")]
		btn.text = "Slot %d: %s%s%s" % [entry["slot"], entry["name"], detail, autosave_tag]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(360, 36)
		var slot_id: int = int(entry["slot"])
		btn.pressed.connect(func() -> void:
			_load_popup.hide()
			close()
			var gs: GameState = get_node_or_null("/root/GameState") as GameState
			if is_instance_valid(gs) and gs.load_game(slot_id):
				var char_data: Dictionary = gs.get_character_data()
				var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
				if is_instance_valid(gm) and not char_data.is_empty():
					gm.go_to_hub(char_data)
		)
		list.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _load_popup.hide())
	root.add_child(cancel)

	_load_popup.popup_centered()
