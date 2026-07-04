## DisplayManager — Manages game display state, HUD data, and scene rendering config
## Autoload singleton for visual configuration. No Godot UI nodes here; 
## UI scenes reference DisplayManager via $DisplayManager or GameManager autoload.

extends Node


signal health_display_updated(target_id: String, current_h: float, max_h: float)
signal ui_mode_changed(mode: String)  # "hud", "pause_menu", "character_sheet"


@export var display_scale: float = 1.0
@export var fullscreen: bool = false
@export var vsync: bool = true
@export var monitor_index: int = 0
@export var resolution_width: int = 1280
@export var resolution_height: int = 720
@export var ui_visibility: Dictionary = {
	"health_bar": true,
	"inventory_panel": true,
	"map_overlay": true,
	"class_info": true
}

const SETTINGS_PATH := "user://settings.cfg"

var _current_hud_targets: Array[Dictionary] = []
var _current_mode: String = ""
var _available_monitors: Array[Dictionary] = []
var _available_resolutions: Array[Vector2i] = []


func _ready() -> void:
	reset_display_state()
	_enumerate_monitors()
	_load_settings()
	_apply_settings()
	print("[DisplayManager] Initialized (v0.2.0).")


# -- HUD state --

func reset_display_state() -> void:
	_current_hud_targets.clear()
	for key in ui_visibility:
		ui_visibility[key] = true
	print("[DisplayManager] Display state reset.")


func add_hud_target(character_id: String, current_health: float, max_health: float) -> void:
	_current_hud_targets.append({
		"id": character_id,
		"current_health": clampf(current_health, 0.0, max_health),
		"max_health": max_health
	})
	health_display_updated.emit(character_id, _current_hud_targets[-1]["current_health"], max_health)


func remove_hud_target(character_id: String) -> void:
	var removed_any = false
	for i in range(_current_hud_targets.size() - 1, -1, -1):
		if _current_hud_targets[i].get("id") == character_id:
			_current_hud_targets.remove_at(i)
			removed_any = true
	if not removed_any:
		push_warning("[DisplayManager] HUD target %s not found." % character_id)


func get_hud_target(character_id: String) -> Dictionary:
	for t in _current_hud_targets:
		if t.get("id") == character_id:
			return t.duplicate()
	return {}


# -- UI mode management --

func set_ui_mode(mode: String) -> void:
	var valid_modes := ["hud", "pause_menu", "character_sheet", "map_overlay"]
	if not mode in valid_modes:
		push_error("[DisplayManager] Invalid UI mode: %s (valid: %s)" % [mode, str(valid_modes)])
		return

	var was: String = _current_mode if "_current_mode" in self else ""
	_current_mode = mode
	ui_visibility = {}
	match mode:
		"hud":
			for k in ["health_bar", "inventory_panel", "map_overlay"]:
				ui_visibility[k] = true
		"pause_menu":
			for k in ui_visibility:
				ui_visibility[k] = false
			ui_visibility["map_overlay"] = false  # pause should not show map overlay
		"character_sheet":
			for k in ["health_bar", "class_info"]:
				if k in ui_visibility:
					ui_visibility[k] = true
			ui_visibility["inventory_panel"] = "sheet"  # special mode for sheet view
			for k in ui_visibility.keys():
				if not ["health_bar", "class_info", "inventory_panel"].has(k):
					ui_visibility.erase(k)
		"map_overlay":
			ui_visibility["map_overlay"] = true

	print("[DisplayManager] UI mode changed from %s to %s" % [was if was != "" else "(none)", mode])
	ui_mode_changed.emit(mode)


# -- Screen/window management --

func set_display_resolution(width: int, height: int) -> void:
	var config: Vector2i = DisplayServer.window_get_size()
	if width > 0 and height > 0:
		config = Vector2i(width, height)
	
	DisplayServer.window_set_size(config)
	print("[DisplayManager] Display resolution set to %dx%d" % [config.x, config.y])


func toggle_fullscreen(enabled := true) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	fullscreen = enabled
	print("[DisplayManager] Fullscreen toggled to %s" % "on" if enabled else "off")
# -- Settings persistence --

func _enumerate_monitors() -> void:
	_available_monitors.clear()
	var screen_count := DisplayServer.get_screen_count()
	for i in range(screen_count):
		var monitor_name: String = DisplayServer.screen_get_name(i)
		var screen_size: Vector2i = DisplayServer.screen_get_size(i)
		_available_monitors.append({
			"index": i,
			"name": monitor_name,
			"size": screen_size
		})
	print("[DisplayManager] Enumerated %d monitors" % screen_count)

func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		print("[DisplayManager] No settings file found, using defaults.")
		return
	monitor_index = config.get_value("display", "monitor", 0)
	resolution_width = config.get_value("display", "width", 1280)
	resolution_height = config.get_value("display", "height", 720)
	fullscreen = config.get_value("display", "fullscreen", false)
	vsync = config.get_value("display", "vsync", true)
	print("[DisplayManager] Settings loaded from %s" % SETTINGS_PATH)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "monitor", monitor_index)
	config.set_value("display", "width", resolution_width)
	config.set_value("display", "height", resolution_height)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[DisplayManager] Failed to save settings to %s" % SETTINGS_PATH)
	else:
		print("[DisplayManager] Settings saved to %s" % SETTINGS_PATH)

func _apply_settings() -> void:
	# Set monitor
	if monitor_index >= 0 and monitor_index < _available_monitors.size():
		# Godot doesn't have a direct set_monitor; we can move window to that screen
		var screen_pos: Vector2i = DisplayServer.screen_get_position(monitor_index)
		DisplayServer.window_set_position(screen_pos)
	# Set resolution
	set_display_resolution(resolution_width, resolution_height)
	# Set fullscreen
	toggle_fullscreen(fullscreen)
	# Set vsync
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[DisplayManager] Settings applied")

func get_available_monitors() -> Array[Dictionary]:
	return _available_monitors

func set_monitor(index: int) -> void:
	if index >= 0 and index < _available_monitors.size():
		monitor_index = index
		var screen_pos: Vector2i = DisplayServer.screen_get_position(index)
		DisplayServer.window_set_position(screen_pos)
		_save_settings()
		print("[DisplayManager] Monitor set to %d (%s)" % [index, _available_monitors[index]["name"]])

func get_current_monitor() -> int:
	return monitor_index

func get_available_resolutions(monitor: int = -1) -> Array[Vector2i]:
	# Godot doesn't have a direct get_resolutions per monitor; we can return common resolutions
	# For simplicity, return a fixed list of common resolutions
	var resolutions: Array[Vector2i] = []
	resolutions.append(Vector2i(640, 480))
	resolutions.append(Vector2i(800, 600))
	resolutions.append(Vector2i(1024, 768))
	resolutions.append(Vector2i(1280, 720))
	resolutions.append(Vector2i(1280, 800))
	resolutions.append(Vector2i(1366, 768))
	resolutions.append(Vector2i(1440, 900))
	resolutions.append(Vector2i(1600, 900))
	resolutions.append(Vector2i(1920, 1080))
	resolutions.append(Vector2i(2560, 1440))
	resolutions.append(Vector2i(3840, 2160))
	# Filter out resolutions larger than monitor size
	if monitor >= 0 and monitor < _available_monitors.size():
		var monitor_size: Vector2i = _available_monitors[monitor]["size"]
		resolutions = resolutions.filter(func(res: Vector2i) -> bool: return res.x <= monitor_size.x and res.y <= monitor_size.y)
	return resolutions

func set_resolution(width: int, height: int) -> void:
	resolution_width = width
	resolution_height = height
	set_display_resolution(width, height)
	_save_settings()


func _enter_tree() -> void:
	# Ensure UI visibility defaults are applied
	if not ui_visibility.is_empty():
		for key in ui_visibility.keys():
			if ui_visibility[key] != true and ui_visibility[key] != "sheet":
				ui_visibility[key] = true


# -- Pure draw UI helpers --

@export_group("Assets")
const _rust_pattern = null  # preload("res://assets/ui/rust_grid.svg")  # asset missing; stubbed for clean load
const _rust_modulate = Color(0.18, 0.12, 0.10)

@export_group("UI")
var panel_bg: Color = Color(0.08, 0.06, 0.05)
var border_color: Color = Color(0.35, 0.28, 0.20)
var border_width := 2.0
var rust_accent: Color = Color(0.65, 0.30, 0.20)

@export_group("Health Bar")
var health_bar_bg: Color = Color(0.20, 0.18, 0.15)
var health_bar_fade: Color = Color(0.10, 0.09, 0.08)

@export_group("Inventory")
var inv_bg: Color = Color(0.06, 0.05, 0.04)
var inv_border: Color = Color(0.28, 0.25, 0.22)
var inv_accent: Color = Color(0.45, 0.35, 0.30)

func get_rust_rect(rect: Rect2) -> PackedVector2Array:
	# stubbed (rust pattern asset missing / display draws disabled for load)
	return [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	]

func draw_rusted_panel(rect: Rect2, text: String) -> void:
	# NOTE: Stubs to allow clean parse (this autoload extends Node, not a CanvasItem).
	# Real drawing lives in UI Controls / Node2D _draw methods or dedicated renderers.
	return

func draw_health_bar(rect: Rect2, pct: float, name: String = "") -> void:
	return

func draw_inventory_slot(rect: Rect2, item: Dictionary, idx: int) -> void:
	return

func draw_button(rect: Rect2, text: String, pressed: bool = false) -> void:
	return

func draw_compass(rect: Rect2, heading: float, north: Vector2 = Vector2.ZERO) -> void:
	return

func draw_minimap(rect: Rect2, player_pos: Vector2, visible_tiles: Dictionary) -> void:
	return
