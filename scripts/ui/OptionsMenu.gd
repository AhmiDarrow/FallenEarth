## OptionsMenu — Settings menu with volume sliders and display options.
##
## Saves settings to user://options.cfg.
class_name OptionsMenu
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const SETTINGS_PATH := "user://options.cfg"

var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _fullscreen_check: CheckBox = null
var _resolution_option: OptionButton = null
var _close_button: Button = null

signal closed


func _ready() -> void:
	# Use `anchors_preset` (property syntax) instead of `anchor_right = 1.0`
	# to avoid Godot's "size overridden after _ready" warning — see
	# BaseShopUI for the full explanation.
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Sync our size to the parent BEFORE building children — otherwise
	# the Panel's `offset_*` (which use `size.x/y * 0.5`) would be 0
	# and the panel would collapse to nothing.
	_sync_size_to_parent()
	_build_ui()
	_load_settings()
	# Stay in lockstep with the parent if it ever resizes.
	var parent := get_parent()
	if parent is Control and not (parent as Control).resized.is_connected(_on_parent_resized):
		(parent as Control).resized.connect(_on_parent_resized)


## Snap our `size` to the parent Control's rect. Required because we
## are added as a child of a non-Container Control and the engine
## doesn't auto-size us from anchors alone.
func _sync_size_to_parent() -> void:
	var parent := get_parent()
	if parent is Control:
		var p: Control = parent as Control
		if p.size.x > 0 and p.size.y > 0:
			size = p.size
			position = Vector2.ZERO


## Re-sync our size and re-center the panel when the parent Control is resized.
func _on_parent_resized() -> void:
	_sync_size_to_parent()
	if has_node("Panel"):
		var panel: Control = get_node("Panel") as Control
		panel.offset_left = size.x * 0.5 - 150
		panel.offset_right = size.x * 0.5 + 150
		panel.offset_top = size.y * 0.5 - 150
		panel.offset_bottom = size.y * 0.5 + 150


func _build_ui() -> void:
	var backdrop := UH.make_backdrop()
	backdrop.name = "Backdrop"
	add_child(backdrop)

	# Panel (centered)
	var panel := UH.make_panel(MT.BG_SURFACE, MT.BORDER_STRONG, MT.RADIUS_LG, 2)
	panel.name = "Panel"
	panel.offset_left = size.x * 0.5 - 150
	panel.offset_right = size.x * 0.5 + 150
	panel.offset_top = size.y * 0.5 - 150
	panel.offset_bottom = size.y * 0.5 + 150
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var margin := UH.make_margin(16)
	margin.name = "Margin"
	panel.add_child(margin)

	var vbox := UH.make_vbox(12)
	vbox.name = "VBox"
	margin.add_child(vbox)

	# Title
	var title := UH.make_accent_label("Settings", MT.FS_H3)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Music volume
	var music_row := UH.make_hbox(8)
	music_row.name = "MusicRow"
	vbox.add_child(music_row)

	var music_label := UH.make_label("Music", MT.FS_SMALL, MT.TEXT_SECONDARY)
	music_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_row.add_child(music_label)

	_music_slider = UH.make_slider(0.0, 1.0, 0.05, 0.7, 120)
	_music_slider.name = "MusicSlider"
	_music_slider.value_changed.connect(_on_music_changed)
	music_row.add_child(_music_slider)

	# SFX volume
	var sfx_row := UH.make_hbox(8)
	sfx_row.name = "SFXRow"
	vbox.add_child(sfx_row)

	var sfx_label := UH.make_label("SFX", MT.FS_SMALL, MT.TEXT_SECONDARY)
	sfx_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_row.add_child(sfx_label)

	_sfx_slider = UH.make_slider(0.0, 1.0, 0.05, 0.8, 120)
	_sfx_slider.name = "SFXSlider"
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_row.add_child(_sfx_slider)

	# Fullscreen
	_fullscreen_check = UH.make_checkbox("Fullscreen")
	_fullscreen_check.name = "Fullscreen"
	_fullscreen_check.pressed.connect(_on_fullscreen_toggled)
	vbox.add_child(_fullscreen_check)

	# Resolution
	var res_row := UH.make_hbox(8)
	res_row.name = "ResolutionRow"
	vbox.add_child(res_row)

	var res_label := UH.make_label("Resolution", MT.FS_SMALL, MT.TEXT_SECONDARY)
	res_row.add_child(res_label)

	_resolution_option = UH.make_option_button([], 120, 24)
	_resolution_option.name = "Resolution"
	_resolution_option.add_item("1280x720", 0)
	_resolution_option.add_item("1600x900", 1)
	_resolution_option.add_item("1920x1080", 2)
	_resolution_option.add_item("2560x1440", 3)
	_resolution_option.item_selected.connect(_on_resolution_changed)
	res_row.add_child(_resolution_option)

	# Close button
	_close_button = UH.make_button("Close", "primary", 100, 32)
	_close_button.name = "CloseButton"
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)
	# Add mod settings section
	_build_mod_settings_section(vbox)
	UH.make_scrollable(vbox)


func _on_music_changed(value: float) -> void:
	# Push live volume to the music manager so the change is
	# audible immediately (not just on next launch).
	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("set_volume"):
		mm.call("set_volume", value)
	_save_settings()


func _on_sfx_changed(value: float) -> void:
	# Push live volume to the ambient/SFX bed.
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa != null and aa.has_method("set_volume"):
		aa.call("set_volume", value)
	_save_settings()


func _on_fullscreen_toggled() -> void:
	if _fullscreen_check.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _on_resolution_changed(index: int) -> void:
	var resolutions: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]
	if index >= 0 and index < resolutions.size():
		var res: Vector2i = resolutions[index]
		DisplayServer.window_set_size(res)
	_save_settings()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
	queue_free()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", _music_slider.value)
	config.set_value("audio", "sfx", _sfx_slider.value)
	config.set_value("display", "fullscreen", _fullscreen_check.button_pressed)
	config.set_value("display", "resolution_idx", _resolution_option.selected)
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_music_slider.value = config.get_value("audio", "music", 0.7)
	_sfx_slider.value = config.get_value("audio", "sfx", 0.8)
	_fullscreen_check.button_pressed = config.get_value("display", "fullscreen", false)
	_resolution_option.selected = config.get_value("display", "resolution_idx", 2)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()


## Build mod settings section in the options menu
func _build_mod_settings_section(parent_vbox: VBoxContainer) -> void:
	var mod_api := get_node_or_null("/root/ModAPI")
	if mod_api == null:
		return
	var all_settings: Dictionary = mod_api.get_all_settings()
	if all_settings.is_empty():
		return
	# Add separator
	var separator := UH.make_separator()
	separator.name = "ModSeparator"
	parent_vbox.add_child(separator)
	# Add section title
	var section_title := UH.make_accent_label("Mod Settings", MT.FS_STAT)
	section_title.name = "ModSectionTitle"
	parent_vbox.add_child(section_title)
	# Add settings for each mod
	for mod_id in all_settings:
		var mod_label := UH.make_label(mod_id, MT.FS_SMALL, MT.TEXT_LINK)
		mod_label.name = "ModLabel_%s" % mod_id
		parent_vbox.add_child(mod_label)
		for key in all_settings[mod_id]:
			var setting: Dictionary = all_settings[mod_id][key]
			var row := UH.make_hbox(8)
			parent_vbox.add_child(row)
			var label := UH.make_label(setting.get("display_name", key), MT.FS_SMALL, MT.TEXT_SECONDARY)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			match setting.type:
				"float":
					var slider := UH.make_slider(0.0, 10.0, 0.1, setting.value, 120)
					slider.value_changed.connect(func(val): mod_api.set_setting(mod_id, key, val))
					row.add_child(slider)
				"bool":
					var check := UH.make_checkbox("")
					check.button_pressed = setting.value
					check.pressed.connect(func(): mod_api.set_setting(mod_id, key, check.button_pressed))
					row.add_child(check)
				"String":
					var line_edit := UH.make_line_edit("", 120, 24)
					line_edit.text = str(setting.value)
					line_edit.text_changed.connect(func(text): mod_api.set_setting(mod_id, key, text))
					row.add_child(line_edit)
