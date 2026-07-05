extends Control

@onready var monitor_option: OptionButton = $VBoxContainer/MonitorHBox/MonitorOption as OptionButton
@onready var resolution_option: OptionButton = $VBoxContainer/ResolutionHBox/ResolutionOption as OptionButton
@onready var fullscreen_check: CheckBox = $VBoxContainer/FullscreenHBox/FullscreenCheck as CheckBox
@onready var vsync_check: CheckBox = $VBoxContainer/VSyncHBox/VSyncCheck as CheckBox
@onready var apply_btn: Button = $VBoxContainer/ButtonHBox/ApplyBtn as Button
@onready var back_btn: Button = $VBoxContainer/ButtonHBox/BackBtn as Button

var _displays: Array[Dictionary] = []
var _resolutions: Array[Vector2i] = []

func _ready() -> void:
	_displays = DisplayManager.get_available_monitors()
	_populate_monitors()
	monitor_option.item_selected.connect(_on_monitor_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	apply_btn.pressed.connect(_on_apply)
	back_btn.pressed.connect(_on_back)
	# Initialize UI with current settings
	monitor_option.select(DisplayManager.get_current_monitor())
	fullscreen_check.button_pressed = DisplayManager.fullscreen
	vsync_check.button_pressed = DisplayManager.vsync
	# Populate resolutions for current monitor
	_populate_resolutions(DisplayManager.get_current_monitor())
	# Find current resolution in list
	var current_res := Vector2i(DisplayManager.resolution_width, DisplayManager.resolution_height)
	for i in range(_resolutions.size()):
		if _resolutions[i] == current_res:
			resolution_option.select(i)
			break

func _populate_monitors() -> void:
	monitor_option.clear()
	for monitor in _displays:
		monitor_option.add_item("%s (%dx%d)" % [monitor["name"], monitor["size"].x, monitor["size"].y])

func _populate_resolutions(monitor_index: int) -> void:
	_resolutions = DisplayManager.get_available_resolutions(monitor_index)
	resolution_option.clear()
	for res in _resolutions:
		resolution_option.add_item("%dx%d" % [res.x, res.y])

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

func _on_back() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs) and not gs.get_character_data().is_empty():
		get_tree().change_scene_to_file("res://scenes/HubWorld.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")