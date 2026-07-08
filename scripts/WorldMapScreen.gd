## WorldMapScreen — Strategic hex-sphere map (RimWorld world view).
## Shows faction settlements, quest markers, rifts, and allows inter-region travel.
class_name WorldMapScreen extends Control

signal return_to_local_requested()
signal travel_to_hex_requested(q: int, r: int)

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const StyleBoxHelper = preload("res://scripts/StyleBoxHelper.gd")

const HEX_SIZE := 22.0

@onready var char_label: RichTextLabel = $CharInfoBar/CharLabel as RichTextLabel
@onready var info_label: RichTextLabel = $InfoPanel/InfoLabel as RichTextLabel
@onready var world_grid: Node2D = $WorldGrid as Node2D

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
	print("[WorldMapScreen] Strategic world map loading.")
	_game_time = Time.get_ticks_msec() / 1000.0

	var travel_btn: Button = $BottomBar/TravelHere as Button
	var local_btn: Button = $BottomBar/ReturnLocal as Button
	if is_instance_valid(travel_btn):
		travel_btn.pressed.connect(_on_travel_pressed)
	if is_instance_valid(local_btn):
		local_btn.pressed.connect(_on_return_local_pressed)

	_rift_runner = get_node_or_null("/root/RiftRunner")
	_npc_manager = get_node_or_null("/root/NPCManager")
	_mission_manager = get_node_or_null("/root/MissionManager")
	_world_gen = WorldGenerator.new()
	add_child(_world_gen)

	# Audio: strategic map uses exploration music; mute the biome
	# ambient bed (the map view is a hex-sphere overview, not a tile).
	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play_track"):
		mm.call("play_track", "exploration")
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa != null and aa.has_method("stop_all"):
		aa.call("stop_all", 0.4)

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var char_data: Dictionary = gs.get_party_character_data()
		if not char_data.is_empty():
			_update_char_info(char_data)

		_tile_map = gs.get_tile_map()
		if not _tile_map.is_empty():
			var seed_str: String = str(gs.get_world_data().get("seed", ""))
			_world_gen.load_from_tile_map(_tile_map, seed_str)

		var pos: Vector2i = gs.get_player_position()
		_player_q = pos.x
		_player_r = pos.y
		_selected_q = _player_q
		_selected_r = _player_r

	_build_world_view()
	_update_info_panel()


func _build_world_view() -> void:
	for c in world_grid.get_children():
		c.queue_free()
	_hex_cells.clear()

	var gs: GameState = get_node_or_null("/root/GameState") as GameState

	for key in _tile_map.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() < 2:
			continue
		var q := int(parts[0])
		var r := int(parts[1])
		var tile: Dictionary = _tile_map[key]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(40, 36)
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.add_theme_stylebox_override("focus", StyleBoxHelper.focus_ring())
		btn.text = _hex_marker(q, r, tile, gs)
		btn.tooltip_text = _tile_tooltip(tile, gs, q, r)
		btn.modulate = _biome_color(str(tile.get("name", "")))

		if q == _player_q and r == _player_r:
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		elif q == _selected_q and r == _selected_r:
			btn.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))

		var pos := WorldGenerator.axial_to_pixel(q, r, HEX_SIZE)
		btn.position = pos - Vector2(20, 18)
		btn.pressed.connect(_on_hex_pressed.bind(q, r))
		world_grid.add_child(btn)
		_hex_cells[key] = btn


func _hex_marker(q: int, r: int, tile: Dictionary, gs: GameState) -> String:
	if q == _player_q and r == _player_r:
		return "◎"
	if _has_npc_at(q, r):
		return "★"
	if _has_mission_at(q, r):
		return "!"
	if _has_rift_at(q, r):
		return "⚡"
	if is_instance_valid(gs) and gs.is_hex_discovered(q, r):
		var name_str := str(tile.get("name", "?"))
		return name_str.left(1) if name_str.length() > 0 else "?"
	return "?"


func _tile_tooltip(tile: Dictionary, gs: GameState, q: int, r: int) -> String:
	var discovered := is_instance_valid(gs) and gs.is_hex_discovered(q, r)
	var biome := str(tile.get("name", "Unknown")) if discovered else "Unexplored"
	return "%s (%d,%d) | T:%.0f%% R:%.0f%%" % [
		biome, q, r,
		float(tile.get("temperature", 0.5)) * 100.0,
		float(tile.get("rainfall", 0.5)) * 100.0,
	]


func _biome_color(biome: String) -> Color:
	match biome:
		"Ash Wastes":
			return Color(0.75, 0.65, 0.5)
		"Rust Canyons":
			return Color(0.85, 0.45, 0.35)
		"Neon Bogs":
			return Color(0.4, 0.85, 0.55)
		"Scorched Plains":
			return Color(0.9, 0.6, 0.3)
		"Ironwood Thicket":
			return Color(0.35, 0.6, 0.35)
		"Glass Dunes":
			return Color(0.7, 0.8, 0.95)
		"Corpse Fields":
			return Color(0.55, 0.45, 0.5)
		"Stormspire Highlands":
			return Color(0.5, 0.55, 0.75)
		"Toxin Marshes":
			return Color(0.45, 0.7, 0.4)
		"Dead City Outskirts":
			return Color(0.5, 0.5, 0.55)
		_:
			return Color(0.35, 0.35, 0.4)


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


func _on_hex_pressed(q: int, r: int) -> void:
	_selected_q = q
	_selected_r = r
	_build_world_view()
	_update_info_panel()


func _update_info_panel() -> void:
	var key := "%d,%d" % [_selected_q, _selected_r]
	var tile: Dictionary = _tile_map.get(key, {})
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	var discovered := is_instance_valid(gs) and gs.is_hex_discovered(_selected_q, _selected_r)
	var dist := WorldGenerator.hex_distance(_selected_q, _selected_r, _player_q, _player_r)
	var can_travel := dist == 1 and key in _tile_map

	var lines: PackedStringArray = []
	if discovered and not tile.is_empty():
		lines.append("[b]Region (%d, %d)[/b] — [color=#c8e6c9]%s[/color]" % [
			_selected_q, _selected_r, tile.get("name", "?"),
		])
		lines.append("Temp %.0f%% | Rain %.0f%% | Rift %.0f%%" % [
			float(tile.get("temperature", 0.5)) * 100.0,
			float(tile.get("rainfall", 0.5)) * 100.0,
			float(tile.get("rift_chance", 0.0)) * 100.0,
		])
	else:
		lines.append("[b]Region (%d, %d)[/b] — [color=#9e9e9e]Unexplored[/color]" % [_selected_q, _selected_r])

	if _has_npc_at(_selected_q, _selected_r):
		lines.append("[color=#ffe082]★ Faction settlement present[/color]")
	if _has_mission_at(_selected_q, _selected_r):
		lines.append("[color=#80cbc4]! Active mission target[/color]")
	if _has_rift_at(_selected_q, _selected_r):
		lines.append("[color=#e1bee7]⚡ Rift tunnel detected[/color]")

	if _selected_q == _player_q and _selected_r == _player_r:
		lines.append("[i]You are here (local map).[/i]")
	elif can_travel:
		lines.append("[i]Adjacent — click Travel to enter this 512×512 region.[/i]")
	elif dist > 1:
		lines.append("[i]Too far — travel via adjacent regions first.[/i]")

	info_label.text = "\n".join(lines)

	var travel_btn: Button = $BottomBar/TravelHere as Button
	if is_instance_valid(travel_btn):
		travel_btn.disabled = not can_travel or (_selected_q == _player_q and _selected_r == _player_r)
		travel_btn.text = "▶ TRAVEL HERE" if can_travel else "▶ ADJACENT ONLY"


func _update_char_info(data: Dictionary) -> void:
	var char_name: String = str(data.get("name", data.get("id", "???")))
	var race: String = str(data.get("race", "???"))
	var cls: String = str(data.get("class", "???"))
	char_label.text = "[b]%s[/b] — %s / %s  [color=#fff59d]World Map[/color]" % [char_name, race, cls]


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