## WorldMapPanel — Strategic hex-sphere map drawn entirely via _draw() methods.
## Shows faction settlements, quest markers, rifts, and allows inter-region travel.
extends Control

signal return_to_local_requested()
signal travel_to_hex_requested(q: int, r: int)

const HEX_SIZE := 22.0
const DISPLAY = preload("res://scripts/DisplayManager.gd")

@onready var _world_grid_rect := Rect2(Vector2.ZERO, Vector2(1200, 700))
@onready var _info_panel_rect := Rect2(Vector2(1220, 10), Vector2(320, 600))
@onready var _travel_btn_rect := Rect2(Vector2(1550, 500), Vector2(180, 50))
@onready var _local_btn_rect := Rect2(Vector2(1550, 560), Vector2(180, 50))

var _world_gen: WorldGenerator = null
var _tile_map: Dictionary = {}
var _player_q: int = 0
var _player_r: int = 0
var _hex_cells: Dictionary = {}
var _selected_q: int = 0
var _selected_r: int = 0
var _rift_runner: Node = null
var _npc_manager: Node = null
var _mission_manager: Node = null
var _game_time: float = 0.0

func _ready() -> void:
	_game_time = Time.get_ticks_msec() / 1000.0
	_configure_panels()

func _configure_panels() -> void:
	# Build world view (hex markers drawn as simple text symbols)
	for key in _tile_map.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() < 2:
			continue
		var q := int(parts[0])
		var r := int(parts[1])
		var tile: Dictionary = _tile_map[key]
		var marker := _hex_marker(q, r, tile)
		var color := _biome_color(str(tile.get("name", "")))
		var text_rect := Rect2(
			WorldGenerator.axial_to_pixel(q, r, HEX_SIZE) - Vector2(11, 9),
			Vector2(22, 18)
		)
		# Draw hex marker
		var font := get_theme_font("font")
		var fg := color.lighten(0.15)
		DISPLAY.draw_multiline(text_rect, marker, 10.0, fg, 0.0)

		# Highlight player / selected
		if q == _player_q and r == _player_r:
			DISPLAY.draw_circle(text_rect.position + Vector2(11, 9), 4.5, Color(1.0, 0.95, 0.6))
		elif q == _selected_q and r == _selected_r:
			DISPLAY.draw_circle(text_rect.position + Vector2(11, 9), 4.5, Color(0.7, 0.9, 1.0))

		# Store for click handling (simple 2D coordinate map)
		var world_pos := WorldGenerator.axial_to_pixel(q, r, HEX_SIZE)
		_hex_cells[world_pos] = {"q": q, "r": r, "tile": tile}

	# Draw info panel background
	DISPLAY.draw_rusted_panel(_info_panel_rect, "[b]Region (%d, %d)[/b] — [color=#c8e6c9]%s[/color]" % [
		_selected_q, _selected_r, _tile_map.get("%d,%d" % [_selected_q, _selected_r], {}).get("name", "?")
	])

	# Draw travel button (active)
	DISPLAY.draw_button(_travel_btn_rect, "▶ TRAVEL HERE", _is_travel_active())

	# Draw local return button (always active)
	DISPLAY.draw_button(_local_btn_rect, "◀ RETURN TO LOCAL", false)


func _is_travel_active() -> bool:
	var dist := WorldGenerator.hex_distance(_selected_q, _selected_r, _player_q, _player_r)
	return dist == 1 and "%d,%d" % [_selected_q, _selected_r] in _tile_map


func _hex_marker(q: int, r: int, tile: Dictionary) -> String:
	if q == _player_q and r == _player_r:
		return "◎"
	if _has_npc_at(q, r):
		return "★"
	if _has_mission_at(q, r):
		return "!"
	if _has_rift_at(q, r):
		return "⚡"
	var name_str := str(tile.get("name", "?"))
	return name_str.left(1) if name_str.length() > 0 else "?"


func _has_npc_at(q: int, r: int) -> bool:
	if not is_instance_valid(_npc_manager) or not _npc_manager.has_method("get_npc_at_tile"):
		return false
	return not (_npc_manager.call("get_npc_at_tile", "%d,%d" % [q, r]) as Dictionary).is_empty()


func _has_mission_at(q: int, r: int) -> bool:
	if not is_instance_valid(_mission_manager) or not _mission_manager.has_method("get_mission_at_tile"):
		return false
	return not (_mission_manager.call("get_mission_at_tile", q, r) as Dictionary).is_empty()


func _has_rift_at(q: int, r: int) -> bool:
	if not is_instance_valid(_rift_runner) or not _rift_runner.has_method("get_rift_at"):
		return false
	return not (_rift_runner.get_rift_at(q, r, _game_time) as Dictionary).is_empty()


func _biome_color(biome: String) -> Color:
	match biome:
		"Ash Wastes": return Color(0.75, 0.65, 0.5)
		"Rust Canyons": return Color(0.85, 0.45, 0.35)
		"Neon Bogs": return Color(0.4, 0.85, 0.55)
		"Scorched Plains": return Color(0.9, 0.6, 0.3)
		"Ironwood Thicket": return Color(0.35, 0.6, 0.35)
		"Glass Dunes": return Color(0.7, 0.8, 0.95)
		"Corpse Fields": return Color(0.55, 0.45, 0.5)
		"Stormspire Highlands": return Color(0.5, 0.55, 0.75)
		"Toxin Marshes": return Color(0.45, 0.7, 0.4)
		"Dead City Outskirts": return Color(0.5, 0.5, 0.55)
		_: return Color(0.35, 0.35, 0.4)


func _on_travel_pressed() -> void:
	var dist := WorldGenerator.hex_distance(_selected_q, _selected_r, _player_q, _player_r)
	if dist != 1:
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		gs.travel_to_hex(_selected_q, _selected_r)
		if is_instance_valid(_mission_manager) and _mission_manager.has_method("report_tile_visit"):
			_mission_manager.call("report_tile_visit", _selected_q, _selected_r)
	travel_to_hex_requested.emit(_selected_q, _selected_r)
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_hub({})


func _on_return_local_pressed() -> void:
	return_to_local_requested.emit()
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_hub({})
