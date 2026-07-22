## WorldMapScreen — Strategic hexasphere globe (3D orbit view with fog, path travel, markers).
class_name WorldMapScreen
extends Control

signal return_to_local_requested()
signal travel_to_hex_requested(q: int, r: int)

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const HGV = preload("res://scripts/ui/HexGlobeView.gd")

@onready var char_label: RichTextLabel = $CharInfoBar/CharLabel as RichTextLabel
@onready var info_label: RichTextLabel = $InfoPanel/InfoLabel as RichTextLabel

var _globe: HGV
var _world_gen: WorldGenerator = null
var _tile_map: Dictionary = {}
var _player_key: String = ""
var _selected_key: String = ""
var _player_q: int = 0
var _player_r: int = 0
var _selected_q: int = 0
var _selected_r: int = 0
var _rift_runner: Node = null
var _npc_manager: Node = null
var _mission_manager: Node = null
var _game_time: float = 0.0
var _discovered_set: Dictionary = {}


func _ready() -> void:
	print("[WorldMapScreen] Strategic globe map loading.")
	_game_time = Time.get_ticks_msec() / 1000.0

	var travel_btn: Button = $BottomBar/TravelHere as Button
	var local_btn: Button = $BottomBar/ReturnLocal as Button
	if is_instance_valid(travel_btn):
		travel_btn.pressed.connect(_on_travel_pressed)
		MT.apply_button_style(travel_btn, "primary")
	if is_instance_valid(local_btn):
		local_btn.pressed.connect(_on_return_local_pressed)
		MT.apply_button_style(local_btn, "secondary")

	_rift_runner = get_node_or_null("/root/RiftRunner")
	_npc_manager = get_node_or_null("/root/NPCManager")
	_mission_manager = get_node_or_null("/root/MissionManager")

	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play_track"):
		mm.call("play_track", "exploration")
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa != null and aa.has_method("stop_all"):
		aa.call("stop_all", 0.4)

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	var char_data: Dictionary = gs.get_party_character_data()
	if not char_data.is_empty():
		_update_char_info(char_data)

	_tile_map = gs.get_tile_map()
	if _tile_map.is_empty():
		return

	_world_gen = WorldGenerator.new()
	add_child(_world_gen)
	var seed_str: String = str(gs.get_world_data().get("seed", ""))
	_world_gen.load_from_tile_map(_tile_map, seed_str)

	var pos: Vector2i = gs.get_player_position()
	_player_q = pos.x
	_player_r = pos.y
	_player_key = "%d,%d" % [_player_q, _player_r]
	_selected_q = _player_q
	_selected_r = _player_r
	_selected_key = _player_key

	var hex_r: int = WorldGenerator.detect_hex_radius(_tile_map.size())
	_globe = HGV.new()
	_globe.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_globe)
	move_child(_globe, 1)
	_globe.tile_clicked.connect(_on_tile_clicked)
	_globe.setup(_tile_map, hex_r)

	for d in gs.get_discovered_hexes():
		_discovered_set[d] = true

	_apply_visual_state()


func _apply_fog() -> void:
	var dark: Color = Color(0.08, 0.08, 0.12)
	for key in _tile_map:
		if _discovered_set.has(key) or key == _player_key:
			continue
		_globe.set_tile_color(key, dark)


func _apply_markers() -> void:
	var player_color := Color(1.0, 0.95, 0.5)
	var settlement_color := Color(1.0, 0.88, 0.5)
	var mission_color := Color(0.5, 0.8, 0.77)
	var rift_color := Color(0.88, 0.73, 0.9)

	for key in _tile_map:
		var tile: Dictionary = _tile_map[key]
		if key == _player_key:
			_globe.set_tile_emission(key, player_color)
			continue
		if not _discovered_set.has(key):
			continue
		var q: int = int(tile.get("q", 0))
		var r: int = int(tile.get("r", 0))
		if _has_npc_at(q, r):
			_globe.set_tile_emission(key, settlement_color, 0.4)
		elif _has_mission_at(q, r):
			_globe.set_tile_emission(key, mission_color, 0.4)
		elif _has_rift_at(q, r):
			_globe.set_tile_emission(key, rift_color, 0.4)


func _apply_visual_state() -> void:
	if not is_instance_valid(_globe) or not _globe.is_built():
		call_deferred("_apply_visual_state")
		return
	_apply_fog()
	_apply_markers()
	_globe.highlight_tile(_player_key)
	_update_info_panel()


func _reapply_fog() -> void:
	var dark: Color = Color(0.08, 0.08, 0.12)
	for key in _tile_map:
		if _discovered_set.has(key) or key == _player_key:
			continue
		_globe.set_tile_color(key, dark)


func _on_tile_clicked(key: String) -> void:
	var parts: PackedStringArray = key.split(",")
	if parts.size() < 2:
		return
	_selected_q = int(parts[0])
	_selected_r = int(parts[1])
	_selected_key = key
	_globe.clear_highlights()
	_reapply_fog()

	if _discovered_set.has(key) or key == _player_key:
		_globe.highlight_tile(key)
	else:
		_globe.set_tile_emission(key, Color(0.5, 0.5, 0.7), 0.25)
	_globe.highlight_tile(_player_key)

	_update_info_panel()


func _update_info_panel() -> void:
	var tile: Dictionary = _tile_map.get(_selected_key, {})
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	var discovered: bool = is_instance_valid(gs) and (_discovered_set.has(_selected_key) or _selected_key == _player_key)

	var path: Array[String] = []
	var can_travel: bool = false
	var travel_reason: String = ""
	var hop_count: int = 0

	if _selected_key != _player_key:
		var allowed: Dictionary = {}
		for k in _discovered_set:
			allowed[k] = true
		allowed[_player_key] = true

		path = WorldGenerator.find_path(_player_key, _selected_key, allowed)
		if not path.is_empty():
			can_travel = true
			hop_count = path.size() - 1
			travel_reason = "Discovered route (%d hop%s)" % [hop_count, "s" if hop_count != 1 else ""]
		elif WorldGenerator.are_neighbors(_player_key, _selected_key):
			can_travel = true
			hop_count = 1
			travel_reason = "Adjacent (1 hop, into uncharted)"
		else:
			travel_reason = "No discovered route"

	var lines: PackedStringArray = []
	if discovered and not tile.is_empty():
		lines.append("[b]Region %s[/b] — [color=#c8e6c9]%s[/color]" % [
			_selected_key, tile.get("name", "?"),
		])
		lines.append("Temp %.0f%% | Rain %.0f%% | Rift %.0f%%" % [
			float(tile.get("temperature", 0.5)) * 100.0,
			float(tile.get("rainfall", 0.5)) * 100.0,
			float(tile.get("rift_chance", 0.0)) * 100.0,
		])
	else:
		lines.append("[b]Region %s[/b] — [color=#9e9e9e]Unexplored[/color]" % [_selected_key])

	if discovered:
		if _has_npc_at(_selected_q, _selected_r):
			lines.append("[color=#ffe082]★ Faction settlement[/color]")
		if _has_mission_at(_selected_q, _selected_r):
			lines.append("[color=#80cbc4]! Active mission target[/color]")
		if _has_rift_at(_selected_q, _selected_r):
			lines.append("[color=#e1bee7]⚡ Rift tunnel detected[/color]")

	if _selected_key == _player_key:
		lines.append("[i]You are here (local map).[/i]")
	elif can_travel:
		lines.append("[i]%s[/i]" % travel_reason)
	else:
		lines.append("[i]%s[/i]" % travel_reason)

	info_label.text = "\n".join(lines)

	var travel_btn: Button = $BottomBar/TravelHere as Button
	if is_instance_valid(travel_btn):
		travel_btn.disabled = not can_travel
		travel_btn.text = "▶ TRAVEL (%d)" % hop_count if can_travel else "▶ NO ROUTE"


func _update_char_info(data: Dictionary) -> void:
	var char_name: String = str(data.get("name", data.get("id", "???")))
	var race: String = str(data.get("race", "???"))
	var cls: String = str(data.get("class", "???"))
	char_label.text = "[b]%s[/b] — %s / %s  [color=#fff59d]World Map[/color]" % [char_name, race, cls]


func _on_travel_pressed() -> void:
	if _selected_key == _player_key:
		return

	var allowed: Dictionary = {}
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		for d in gs.get_discovered_hexes():
			allowed[d] = true
		allowed[_player_key] = true

	var path: Array[String] = WorldGenerator.find_path(_player_key, _selected_key, allowed)
	if path.is_empty():
		if not WorldGenerator.are_neighbors(_player_key, _selected_key):
			return
		path = [_player_key, _selected_key]

	var dest_q: int = _selected_q
	var dest_r: int = _selected_r

	if is_instance_valid(gs):
		gs.travel_to_hex(dest_q, dest_r)
		gs.discover_hex(dest_q, dest_r)
		if is_instance_valid(_mission_manager) and _mission_manager.has_method("report_tile_visit"):
			_mission_manager.call("report_tile_visit", dest_q, dest_r)

	travel_to_hex_requested.emit(dest_q, dest_r)
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_hub({})


func _on_return_local_pressed() -> void:
	return_to_local_requested.emit()
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_hub({})


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
