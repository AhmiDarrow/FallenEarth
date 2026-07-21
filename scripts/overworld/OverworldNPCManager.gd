class_name OverworldNPCManager extends Node

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")

var _hw: HubWorld

var _npc_manager: Node = null
var _mission_manager: Node = null
var _recruit_btn: Button = null
var _mission_btn: Button = null
var _npc_info_label: RichTextLabel = null
var _mission_info_label: RichTextLabel = null


func _setup_npc_ui() -> void:
	var panel: VBoxContainer = _hw.get_node_or_null("UI_Canvas/TileInfoPanel") as VBoxContainer
	if not is_instance_valid(panel):
		return
	_npc_info_label = UH.make_rich_header("")
	_npc_info_label.visible = false
	panel.add_child(_npc_info_label)


func _setup_mission_ui() -> void:
	var panel: VBoxContainer = _hw.get_node_or_null("UI_Canvas/TileInfoPanel") as VBoxContainer
	if not is_instance_valid(panel):
		return
	_mission_info_label = UH.make_rich_header("")
	_mission_info_label.name = "MissionInfoLabel"
	_mission_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_info_label.fit_content = true
	panel.add_child(_mission_info_label)


func _ensure_world_npcs() -> void:
	var gs := _hw._gs
	if not is_instance_valid(gs) or not gs.get_world_npcs().is_empty():
		return
	if not is_instance_valid(_npc_manager) or not _npc_manager.has_method("generate_for_world"):
		return
	var wd: Dictionary = gs.get_world_data()
	var seed_str: String = str(wd.get("seed", ""))
	var start: Dictionary = gs.get_start_tile()
	var start_key: String = str(start.get("key", "%d,%d" % [_hw._player_q, _hw._player_r]))
	if seed_str.is_empty() or _hw._tile_map.is_empty():
		return
	_npc_manager.call("generate_for_world", seed_str, _hw._tile_map, start_key)


func _npc_local_position(npc: Dictionary) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(str(npc.get("id", "npc")).hash())
	var base := Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0))
	return Vector2i(
		clampi(base.x + rng.randi_range(-40, 40), 8, LocalMapGen.MAP_SIZE - 8),
		clampi(base.y + rng.randi_range(-40, 40), 8, LocalMapGen.MAP_SIZE - 8),
	)


func _get_npc_at_hex() -> Dictionary:
	if not is_instance_valid(_npc_manager) or not _npc_manager.has_method("get_npc_at_tile"):
		return {}
	return _npc_manager.call("get_npc_at_tile", "%d,%d" % [_hw._player_q, _hw._player_r]) as Dictionary


func _is_near_npc() -> bool:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty():
		return false
	var npos := _npc_local_position(npc)
	return abs(npos.x - _hw._local_x) <= 2 and abs(npos.y - _hw._local_y) <= 2


func _update_npc_ui() -> void:
	if not is_instance_valid(_npc_info_label):
		return
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty() or not _is_near_npc():
		if is_instance_valid(_recruit_btn):
			_recruit_btn.disabled = true
		if is_instance_valid(_mission_btn):
			_mission_btn.disabled = true
			_mission_btn.text = "◆ NO JOBS"
		return

	_refresh_npc_mission_offers(npc)
	var gs := _hw._gs
	var char_data: Dictionary = gs.get_character_data() if is_instance_valid(gs) else {}
	var check: Dictionary = {}
	if is_instance_valid(_npc_manager) and _npc_manager.has_method("can_recruit"):
		check = _npc_manager.call("can_recruit", str(npc.get("id", "")), char_data) as Dictionary

	_update_mission_offer_button(npc)


func _npc_name_at_hex() -> String:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty():
		return "NPC"
	return str(npc.get("name", "NPC"))


func _open_npc_dialogue() -> void:
	if has_node("OverworldNpcDialogue"):
		return
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty():
		return
	var gs := _hw._gs
	var char_data: Dictionary = gs.get_character_data() if is_instance_valid(gs) else {}
	var can_recruit: bool = false
	if is_instance_valid(_npc_manager) and _npc_manager.has_method("can_recruit"):
		var check: Dictionary = _npc_manager.call("can_recruit", str(npc.get("id", "")), char_data) as Dictionary
		can_recruit = bool(check.get("ok", false))

	var panel := UH.make_surface_panel()
	panel.name = "OverworldNpcDialogue"
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = -200
	panel.offset_bottom = -40
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ui_canvas := _hw.get_node_or_null("UI_Canvas") as CanvasLayer
	(ui_canvas if ui_canvas else _hw).add_child(panel)

	var vbox := UH.make_vbox(8)
	panel.add_child(vbox)

	var name_label := UH.make_label("%s (%s)" % [npc.get("name", "?"), npc.get("role", "?")], 16, Color(1, 0.95, 0.7))
	vbox.add_child(name_label)

	var desc_label := UH.make_label(str(npc.get("personality_summary", "A traveler in the wastes.")), MT.FS_BODY, Color(0.85, 0.85, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	if can_recruit:
		var invite_btn := UH.make_button("Invite to Party", "primary", 200, 36)
		var npc_id := str(npc.get("id", ""))
		invite_btn.pressed.connect(func():
			if is_instance_valid(_npc_manager) and _npc_manager.has_method("recruit_npc"):
				if _npc_manager.call("recruit_npc", npc_id, char_data):
					if is_instance_valid(gs):
						gs.sync_party_companions()
					_hw._map_manager._build_local_view()
					_update_npc_ui()
					_hw._hud_manager._update_char_info(gs.get_party_character_data())
			panel.queue_free()
		)
		vbox.add_child(invite_btn)

	var close_btn := UH.make_button("Goodbye", "ghost", 200, 36)
	close_btn.pressed.connect(panel.queue_free)
	vbox.add_child(close_btn)

	UH.make_scrollable(vbox)


func _on_recruit_pressed() -> void:
	if is_instance_valid(_recruit_btn):
		_open_npc_dialogue()


func _refresh_npc_mission_offers(npc: Dictionary) -> void:
	if not is_instance_valid(_mission_manager) or not _mission_manager.has_method("refresh_npc_offers"):
		return
	var gs := _hw._gs
	if not is_instance_valid(gs):
		return
	_mission_manager.call(
		"refresh_npc_offers",
		str(npc.get("id", "")), npc,
		str(gs.get_world_data().get("seed", "")),
		_hw._tile_map, _hw._player_q, _hw._player_r, gs.get_party_character_data()
	)


func _update_mission_offer_button(npc: Dictionary) -> void:
	if not is_instance_valid(_mission_btn) or not is_instance_valid(_mission_manager):
		return
	var offers: Array = _mission_manager.call("get_offers_for_npc", str(npc.get("id", ""))) if _mission_manager.has_method("get_offers_for_npc") else []
	var can_accept: bool = _mission_manager.call("has_active_capacity") if _mission_manager.has_method("has_active_capacity") else false
	_mission_btn.disabled = offers.is_empty() or not can_accept or not _is_near_npc()
	_mission_btn.text = "◆ ACCEPT JOB" if not offers.is_empty() else "◆ NO JOBS"


func _update_mission_ui() -> void:
	if not is_instance_valid(_mission_info_label) or not is_instance_valid(_mission_manager):
		return
	var active: Array = _mission_manager.call("get_active_missions") if _mission_manager.has_method("get_active_missions") else []
	if active.is_empty():
		_mission_info_label.text = "[i]No active missions. Visit ★ settlements on the World Map.[/i]"
		return
	var lines: PackedStringArray = ["[color=#80cbc4][b]ACTIVE MISSIONS[/b][/color]"]
	for mission in active:
		if mission is Dictionary:
			var m: Dictionary = mission as Dictionary
			lines.append("• %s" % m.get("title", "?"))
	_mission_info_label.text = "\n".join(lines)


func _on_accept_mission_pressed() -> void:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty() or not is_instance_valid(_mission_manager):
		return
	var offers: Array = _mission_manager.call("get_offers_for_npc", str(npc.get("id", ""))) if _mission_manager.has_method("get_offers_for_npc") else []
	if offers.is_empty():
		return
	var offer: Dictionary = offers[0] as Dictionary
	var mid: String = str(offer.get("mission_id", ""))
	if _mission_manager.has_method("accept_mission"):
		_mission_manager.call("accept_mission", mid, _hw._game_time)
	_update_mission_ui()


func _tick_missions() -> void:
	if is_instance_valid(_mission_manager) and _mission_manager.has_method("tick_expired"):
		if int(_mission_manager.call("tick_expired", _hw._game_time)) > 0:
			_update_mission_ui()
