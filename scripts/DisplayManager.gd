## DisplayManager — Manages game display state, HUD data, and scene rendering config
## Autoload singleton for visual configuration. No Godot UI nodes here; 
## UI scenes reference DisplayManager via $DisplayManager or GameManager autoload.

extends Node


signal health_display_updated(target_id: String, current_h: float, max_h: float)
signal ui_mode_changed(mode: String)  # "hud", "pause_menu", "character_sheet"


@export var display_scale: float = 1.0
@export var fullscreen: bool = false
@export var ui_visibility: Dictionary = {
	"health_bar": true,
	"inventory_panel": true,
	"map_overlay": true,
	"class_info": true
}

var _current_hud_targets: Array[Dictionary] = []
var _current_mode: String = ""


func _ready() -> void:
	reset_display_state()
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


func _enter_tree() -> void:
	# Ensure UI visibility defaults are applied
	if not ui_visibility.is_empty():
		for key in ui_visibility.keys():
			if ui_visibility[key] != true and ui_visibility[key] != "sheet":
				ui_visibility[key] = true
