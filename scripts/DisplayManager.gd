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


# -- Pure draw UI helpers --

@export_group("Assets")
const _rust_pattern = preload("res://assets/ui/rust_grid.svg")
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
	return [
		rect.position - Vector2(0, _rust_pattern.size.y),
		rect.position + Vector2(0, 0),
		rect.position + rect.size - Vector2(_rust_pattern.size.x, 0),
		rect.position + rect.size,
	]

func draw_rusted_panel(rect: Rect2, text: String) -> void:
	var r := rect.stretched_size
	var margin := r.x * 0.025
	var label_rect := Rect2(rect.position + Vector2(margin, margin), Vector2(r.x - margin * 2, r.y - margin * 2 - 4))
	draw_rect(rect, panel_bg, 0.0)
	draw_rect(label_rect, Color(0.00, 0.00, 0.00, 0.0), 0.0)
	draw_multiline(label_rect, text, 12.0, Color(0.90, 0.88, 0.85), 0.0)
	draw_rect(get_rust_rect(rect), rust_accent, 0.0, 1.5)

func draw_health_bar(rect: Rect2, pct: float, name: String = "") -> void:
	var h := rect.size - Vector2(2, 0)
	var fg := health_bar_bg.lerp(health_bar_fade, pct)
	var bg := health_bar_bg * 0.25
	draw_rect(rect, bg, 0.0)
	draw_rect(Rect2(rect.position, h.x, h.y * pct), fg, 0.0)
	if name != "":
		var label := Rect2(rect.position + Vector2(4, 0), Vector2(rect.size.x - 8, rect.size.y - 4))
		draw_multiline(label, name, 10.0, Color(0.85, 0.80, 0.75), 0.0)

func draw_inventory_slot(rect: Rect2, item: Dictionary, idx: int) -> void:
	var r := rect.size - Vector2(1, 1)
	draw_rect(rect, inv_bg, 0.0)
	if item.get("icon", null) != null:
		var icon_rect := Rect2(rect.position, r, 0.0)
		var icon_scale := Vector2(1.0, 1.0)
		if item.get("aspect_ratio") != null:
			var ar := item["aspect_ratio"]
			if ar < r.y / r.x:
				icon_scale = Vector2(r.x / r.y / ar, 1.0)
			else:
				icon_scale = Vector2(1.0, r.y / r.x / ar)
		draw_texture_rect(icon_rect, item["icon"], icon_scale, 0.0)
	else:
		draw_rect(icon_rect, Color(0.15, 0.14, 0.13), 0.0)
	if item.get("name", "") != "":
		var label := Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, rect.size.y - 4))
		var name: String = str(item.get("name", "")).left_truncate(14)
		draw_multiline(label, name, 9.0, Color(0.80, 0.78, 0.75), 0.0)
	if item.get("qty", 0) > 1:
		draw_circle(rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 2), 1.2, inv_accent)

func draw_button(rect: Rect2, text: String, pressed: bool = false) -> void:
	var fg := Color(0.35, 0.32, 0.28)
	var bg := panel_bg
	if pressed:
		fg = Color(0.55, 0.50, 0.45)
		bg = Color(0.12, 0.10, 0.08)
	draw_rect(rect, bg, 0.0)
	var label := Rect2(rect.position + Vector2(4, 2), Vector2(rect.size.x - 8, rect.size.y - 4))
	draw_multiline(label, text, 11.0, fg, 0.0)
	draw_rect(get_rust_rect(rect), rust_accent, 0.0, 1.2)

func draw_compass(rect: Rect2, heading: float, north: Vector2 = Vector2.ZERO) -> void:
	var cx := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.6)
	var size := Vector2(rect.size.x - 8, rect.size.y - 12)
	draw_circle(cx, size.x * 0.25, Color(0.35, 0.32, 0.28))
	var n := cx - north * size.x * 0.1
	var s := cx + north * size.x * 0.1
	var e := cx + Vector2(size.x * 0.1, 0)
	var w := cx - Vector2(size.x * 0.1, 0)
	draw_line(n - Vector2(0, 2), n + Vector2(0, 2), Color(0.60, 0.58, 0.55))
	draw_line(e - Vector2(2, 0), e + Vector2(2, 0), Color(0.60, 0.58, 0.55))
	draw_line(s - Vector2(0, 2), s + Vector2(0, 2), Color(0.60, 0.58, 0.55))
	draw_line(w - Vector2(2, 0), w + Vector2(2, 0), Color(0.60, 0.58, 0.55))
	var rh := cx + Vector2(1.8, 0) * cos(deg2rad(heading)) + Vector2(0, 1.8) * sin(deg2rad(heading))
	draw_circle(rh, 1.2, Color(0.95, 0.90, 0.80))
	draw_multiline(Rect2(cx - Vector2(size.x * 0.2, size.y * 0.1), Vector2(size.x * 0.4, size.y * 0.2)),
		"[center][i]N\nE\nS\nW[/i][/center]", 9.0, Color(0.65, 0.62, 0.58), 0.0)

func draw_minimap(rect: Rect2, player_pos: Vector2, visible_tiles: Dictionary) -> void:
	var r := rect.size - Vector2(2, 2)
	draw_rect(rect, panel_bg, 0.0)
	for key in visible_tiles:
		var tile: Dictionary = visible_tiles[key]
		var cx := (tile["x"] - 16) * rect.size.x / 32
		var cy := (tile["y"] - 16) * rect.size.y / 32
		var color := tile.get("biome", "Ash Wastes")
		match color:
			"Ash Wastes": color = Color(0.22, 0.20, 0.22)
			"Fungal Gardens": color = Color(0.18, 0.32, 0.20),
			"Ruined City": color = Color(0.32, 0.28, 0.30),
			"Void Shallows": color = Color(0.20, 0.18, 0.32),
			_: color = Color(0.25, 0.25, 0.25)
		draw_rect(Rect2(cx, cy, r.x / 32, r.y / 32), color, 0.0)
	if player_pos.x >= 0 and player_pos.y >= 0:
		var px := (player_pos.x - 16) * rect.size.x / 32
		var py := (player_pos.y - 16) * rect.size.y / 32
		draw_circle(Rect2(px, py, 1.5, 1.5), Color(1.0, 1.0, 1.0))
