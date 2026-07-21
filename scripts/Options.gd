extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

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
	add_child(UH.make_backdrop(MT.BG_DEEP))

	# Main VBox
	var vbox := UH.make_vbox(8)
	vbox.anchor_left = 0.15
	vbox.anchor_top = 0.1
	vbox.anchor_right = 0.85
	vbox.anchor_bottom = 0.9
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(vbox)

	# Title
	var title := UH.make_rich_header("[center][b]OPTIONS[/b][/center]", 40)
	title.fit_content = true
	vbox.add_child(title)

	# Tab container
	_tab_container = UH.make_tab_container()
	vbox.add_child(_tab_container)

	_build_general_tab()
	_build_graphics_tab()
	_build_audio_tab()
	_build_keybinds_tab()

	# Bottom buttons
	var btn_hbox := UH.make_hbox(16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var apply_btn := UH.make_button("Apply", "primary", 140, 40)
	apply_btn.pressed.connect(_on_apply)
	btn_hbox.add_child(apply_btn)

	var back_btn := UH.make_button("Back", "secondary", 140, 40)
	back_btn.pressed.connect(_on_back)
	btn_hbox.add_child(back_btn)


# ---------------------------------------------------------------------------
# General tab
# ---------------------------------------------------------------------------

func _build_general_tab() -> void:
	var container := UH.make_vbox(12)
	container.name = "General"
	_tab_container.add_child(container)

	var scroll := UH.make_scroll_container()
	container.add_child(scroll)

	var inner := UH.make_vbox(12, true)
	scroll.add_child(inner)

	# Theme selection
	inner.add_child(UH.make_label("UI Theme:", MT.FS_BODY, MT.TEXT_SECONDARY))

	var theme_row := UH.make_hbox(8)
	inner.add_child(theme_row)

	var theme_option := UH.make_option_button([], 280, 30)
	theme_option.name = "ThemeOption"
	theme_row.add_child(theme_option)

	var tm := get_node_or_null("/root/ThemeManager")
	var themes: Array[Dictionary] = tm.get_themes() if tm != null else []
	var saved_theme: String = tm.get_current_theme() if tm != null else ""
	var selected_idx := 0
	for i in themes.size():
		theme_option.add_item(themes[i].display_name, i)
		theme_option.set_item_metadata(i, themes[i].name)
		if themes[i].name == saved_theme:
			selected_idx = i
	theme_option.selected = selected_idx
	theme_option.item_selected.connect(_on_theme_selected.bind(theme_option))

	var theme_desc := UH.make_label(_theme_description(saved_theme), MT.FS_SMALL, MT.TEXT_MUTED)
	theme_desc.name = "ThemeDesc"
	theme_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(theme_desc)

	inner.add_child(UH.make_separator())

	# Mod themes info
	inner.add_child(UH.make_label("Mods can register additional themes via ModAPI.", MT.FS_TINY, MT.TEXT_MUTED))


func _on_theme_selected(index: int, option: OptionButton) -> void:
	var theme_name: String = option.get_item_metadata(index)
	var tm := get_node_or_null("/root/ThemeManager")
	if tm != null:
		tm.apply_theme(theme_name)
	call_deferred("_rebuild_after_theme")
	var desc_label := find_child("ThemeDesc", true, false) as Label
	if desc_label != null:
		desc_label.text = _theme_description(theme_name)


func _rebuild_after_theme() -> void:
	for c in get_children():
		c.queue_free()
	_build_ui()
	_init_graphics()
	_init_audio()


func _theme_description(name: String) -> String:
	match name:
		"twilight": return "Purple, green, and orange accents on dark purple backgrounds. (Default)"
		"ember": return "Warm reds, gold, and amber tones on dark backgrounds."
		"frost": return "Cool blues, cyans, and icy highlights on dark blue backgrounds."
		"viridian": return "Emerald greens and deep teals for a natural feel."
		"nocturne": return "Dark grays with hot pink and electric blue neon accents."
		"abyss": return "Ultra-dark low-contrast theme — easy on the eyes."
		"ochre": return "Blue/orange colorblind-friendly palette with high contrast."
		"terra": return "Original warm earth tones — browns, golds, and beiges."
		_: return ""


# ---------------------------------------------------------------------------
# Graphics tab
# ---------------------------------------------------------------------------

func _build_graphics_tab() -> void:
	var container := UH.make_vbox(10)
	container.name = "Graphics"
	_tab_container.add_child(container)

	var scroll := UH.make_scroll_container()
	container.add_child(scroll)

	var inner := UH.make_vbox(8, true)
	scroll.add_child(inner)

	# Monitor
	_monitor_option = UH.make_option_row(inner, "Monitor:")
	_monitor_option.item_selected.connect(_on_monitor_selected)

	# Resolution
	_resolution_option = UH.make_option_row(inner, "Resolution:")
	_resolution_option.item_selected.connect(_on_resolution_selected)

	# Fullscreen
	_fullscreen_check = UH.make_check_row(inner, "Fullscreen:")
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	# VSync
	_vsync_check = UH.make_check_row(inner, "VSync:")
	_vsync_check.toggled.connect(_on_vsync_toggled)


func _init_graphics() -> void:
	_populate_monitors()
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
	var container := UH.make_vbox(10)
	container.name = "Audio"
	_tab_container.add_child(container)

	var scroll := UH.make_scroll_container()
	container.add_child(scroll)

	var inner := UH.make_vbox(12, true)
	scroll.add_child(inner)

	# Load current volumes
	var config := ConfigFile.new()
	var music_vol: float = 0.7
	var sfx_vol: float = 0.8
	if config.load("user://options.cfg") == OK:
		music_vol = config.get_value("audio", "music", 0.7)
		sfx_vol = config.get_value("audio", "sfx", 0.8)

	# Music volume
	_music_label = UH.make_label("Music: %d%%" % int(music_vol * 100), MT.FS_BODY, MT.TEXT_SECONDARY)
	inner.add_child(_music_label)

	_music_slider = UH.make_slider(0.0, 1.0, 0.01, music_vol)
	_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_slider.custom_minimum_size = Vector2(0, 24)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	inner.add_child(_music_slider)

	# SFX volume
	_sfx_label = UH.make_label("SFX: %d%%" % int(sfx_vol * 100), MT.FS_BODY, MT.TEXT_SECONDARY)
	inner.add_child(_sfx_label)

	_sfx_slider = UH.make_slider(0.0, 1.0, 0.01, sfx_vol)
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
	return UH.make_option_row(parent, label_text)


func _add_check_row(parent: Control, label_text: String) -> CheckBox:
	return UH.make_check_row(parent, label_text)


func _on_back() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs) and not gs.get_character_data().is_empty():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/HubWorld.tscn")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/MainMenu.tscn")
