extends Control

var _tab_container: TabContainer
var _displays: Array[Dictionary] = []
var _resolutions: Array[Vector2i] = []

# Graphics tab refs
var _monitor_option: OptionButton
var _resolution_option: OptionButton
var _fullscreen_check: CheckBox
var _vsync_check: CheckBox

# Audio tab refs
var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_label: Label
var _sfx_label: Label


func _ready() -> void:
	_displays = DisplayManager.get_available_monitors()
	_build_ui()
	_init_graphics()
	_init_audio()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.06, 1)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main VBox
	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.15
	vbox.anchor_top = 0.1
	vbox.anchor_right = 0.85
	vbox.anchor_bottom = 0.9
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.text = "[center][b]OPTIONS[/b][/center]"
	title.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(title)

	# Tab container
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	_build_graphics_tab()
	_build_keybinds_tab()
	_build_audio_tab()

	# Bottom buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(140, 40)
	apply_btn.pressed.connect(_on_apply)
	btn_hbox.add_child(apply_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(140, 40)
	back_btn.pressed.connect(_on_back)
	btn_hbox.add_child(back_btn)


# ---------------------------------------------------------------------------
# Graphics tab
# ---------------------------------------------------------------------------

func _build_graphics_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "Graphics"
	container.add_theme_constant_override("separation", 10)
	_tab_container.add_child(container)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	# Monitor
	_monitor_option = _add_option_row(inner, "Monitor:")
	_monitor_option.item_selected.connect(_on_monitor_selected)

	# Resolution
	_resolution_option = _add_option_row(inner, "Resolution:")
	_resolution_option.item_selected.connect(_on_resolution_selected)

	# Fullscreen
	_fullscreen_check = _add_check_row(inner, "Fullscreen:")
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	# VSync
	_vsync_check = _add_check_row(inner, "VSync:")
	_vsync_check.toggled.connect(_on_vsync_toggled)


func _init_graphics() -> void:
	_monitor_option.select(DisplayManager.get_current_monitor())
	_fullscreen_check.button_pressed = DisplayManager.fullscreen
	_vsync_check.button_pressed = DisplayManager.vsync
	_populate_resolutions(DisplayManager.get_current_monitor())
	var current_res := Vector2i(DisplayManager.resolution_width, DisplayManager.resolution_height)
	for i in range(_resolutions.size()):
		if _resolutions[i] == current_res:
			_resolution_option.select(i)
			break


func _populate_monitors() -> void:
	_monitor_option.clear()
	for monitor in _displays:
		_monitor_option.add_item("%s (%dx%d)" % [monitor["name"], monitor["size"].x, monitor["size"].y])


func _populate_resolutions(monitor_index: int) -> void:
	_resolutions = DisplayManager.get_available_resolutions(monitor_index)
	_resolution_option.clear()
	for res in _resolutions:
		_resolution_option.add_item("%dx%d" % [res.x, res.y])


func _on_monitor_selected(index: int) -> void:
	DisplayManager.set_monitor(index)
	_populate_resolutions(index)


func _on_resolution_selected(index: int) -> void:
	var res := _resolutions[index]
	DisplayManager.set_resolution(res.x, res.y)


func _on_fullscreen_toggled(button_pressed: bool) -> void:
	DisplayManager.toggle_fullscreen(button_pressed)


func _on_vsync_toggled(button_pressed: bool) -> void:
	DisplayManager.vsync = button_pressed
	if button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayManager.save_settings()


func _on_apply() -> void:
	DisplayManager.apply_settings()
	DisplayManager.save_settings()


# ---------------------------------------------------------------------------
# Keybinds tab
# ---------------------------------------------------------------------------

func _build_keybinds_tab() -> void:
	var script: GDScript = load("res://scripts/ui/KeybindsScreen.gd")
	if script == null:
		push_error("[Options] KeybindsScreen.gd not found")
		return
	var screen = script.new()
	screen.name = "Keybinds"
	_tab_container.add_child(screen)


# ---------------------------------------------------------------------------
# Audio tab
# ---------------------------------------------------------------------------

func _build_audio_tab() -> void:
	var container := VBoxContainer.new()
	container.name = "Audio"
	container.add_theme_constant_override("separation", 10)
	_tab_container.add_child(container)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	scroll.add_child(inner)

	# Load current volumes
	var config := ConfigFile.new()
	var music_vol: float = 0.7
	var sfx_vol: float = 0.8
	if config.load("user://options.cfg") == OK:
		music_vol = config.get_value("audio", "music", 0.7)
		sfx_vol = config.get_value("audio", "sfx", 0.8)

	# Music volume
	_music_label = Label.new()
	_music_label.text = "Music: %d%%" % int(music_vol * 100)
	_music_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	inner.add_child(_music_label)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.01
	_music_slider.value = music_vol
	_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_slider.custom_minimum_size = Vector2(0, 24)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	inner.add_child(_music_slider)

	# SFX volume
	_sfx_label = Label.new()
	_sfx_label.text = "SFX: %d%%" % int(sfx_vol * 100)
	_sfx_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	inner.add_child(_sfx_label)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.01
	_sfx_slider.value = sfx_vol
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.custom_minimum_size = Vector2(0, 24)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	inner.add_child(_sfx_slider)


func _init_audio() -> void:
	pass  # Sliders initialized in _build_audio_tab from config


func _on_music_volume_changed(value: float) -> void:
	_music_label.text = "Music: %d%%" % int(value * 100)
	_save_audio_settings("music", value)
	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("set_volume"):
		mm.set_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	_sfx_label.text = "SFX: %d%%" % int(value * 100)
	_save_audio_settings("sfx", value)
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa != null and aa.has_method("set_volume"):
		aa.set_volume(value)


func _save_audio_settings(key: String, value: float) -> void:
	var config := ConfigFile.new()
	config.load("user://options.cfg")
	config.set_value("audio", key, value)
	config.save("user://options.cfg")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _add_option_row(parent: Control, label_text: String) -> OptionButton:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(lbl)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(280, 30)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(opt)
	return opt


func _add_check_row(parent: Control, label_text: String) -> CheckBox:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(lbl)

	var chk := CheckBox.new()
	chk.custom_minimum_size = Vector2(280, 30)
	chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(chk)
	return chk


func _on_back() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs) and not gs.get_character_data().is_empty():
		get_tree().change_scene_to_file("res://scenes/HubWorld.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
