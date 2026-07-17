class_name OverworldNetworkManager extends Node

var _hw: HubWorld


# ============================================================================
# Multiplayer: setup, sync, remote player management
# ============================================================================

func _setup_multiplayer() -> void:
	# Check both GameState flag and NetworkManager connection
	var gs := _hw._gs
	if not is_instance_valid(gs) or not gs.is_multiplayer:
		_hw._is_multiplayer = false
		return
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm == null or not nm.has_method("is_server"):
		_hw._is_multiplayer = false
		return
	if nm.is_server():
		_hw._is_multiplayer = true
		_hw._net_sync = get_node_or_null("/root/NetworkSync")
		if _hw._net_sync != null:
			_hw._net_sync.world_position_updated.connect(_on_remote_position_update)
			_hw._net_sync.remote_player_joined.connect(_on_remote_player_joined)
			_hw._net_sync.remote_player_left.connect(_on_remote_player_left)
			_hw._net_sync.combat_started.connect(_on_mp_combat_started)
			_hw._net_sync.rift_entered.connect(_on_mp_rift_entered)
			_hw._net_sync.rift_exited.connect(_on_mp_rift_exited)
		# Party signals
		var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
		if ppm != null:
			ppm.party_invite_received.connect(_on_party_invite_received)
			ppm.party_joined.connect(_on_party_joined)
			ppm.party_left.connect(_on_party_left)
			ppm.party_member_joined.connect(_on_party_member_joined)
			ppm.party_member_left.connect(_on_party_member_left)
		# Chat + Trade
		_setup_chat_ui()
		_setup_trade()
		print("[HubWorld] Multiplayer host mode active")
		if _hw._net_sync != null and _hw._net_sync.has_method("sync_world_position"):
			_hw._net_sync.sync_world_position(_hw._player_q, _hw._player_r, _hw._local_x, _hw._local_y)
		nm.client_connected.connect(_on_mp_client_connected)
		return

	if nm.has_method("is_client") and nm.is_client():
		_hw._is_multiplayer = true
		_hw._net_sync = get_node_or_null("/root/NetworkSync")
		if _hw._net_sync != null:
			_hw._net_sync.world_position_updated.connect(_on_remote_position_update)
			_hw._net_sync.world_scene_changed.connect(_on_remote_scene_changed)
			_hw._net_sync.combat_started.connect(_on_mp_combat_started)
			_hw._net_sync.rift_entered.connect(_on_mp_rift_entered)
			_hw._net_sync.rift_exited.connect(_on_mp_rift_exited)
		# Party signals
		var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
		if ppm != null:
			ppm.party_invite_received.connect(_on_party_invite_received)
			ppm.party_joined.connect(_on_party_joined)
			ppm.party_left.connect(_on_party_left)
			ppm.party_member_joined.connect(_on_party_member_joined)
			ppm.party_member_left.connect(_on_party_member_left)
		# Chat + Trade
		_setup_chat_ui()
		_setup_trade()
		print("[HubWorld] Multiplayer client mode active")


func _setup_chat_ui() -> void:
	var cm: Node = get_node_or_null("/root/ChatManager")
	if cm == null:
		return
	# Create chat UI overlay
	var chat_ui := load("res://scripts/network/ChatUI.gd").new() as Control
	if chat_ui == null:
		return
	chat_ui.set_chat_manager(cm)
	cm.message_received.connect(chat_ui.add_message)
	var canvas := _hw.get_node_or_null("UI_Canvas") as CanvasLayer
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "UI_Canvas"
		_hw.add_child(canvas)
	canvas.add_child(chat_ui)
	# Store reference for toggle
	_hw.set_meta("chat_ui", chat_ui)
	print("[HubWorld] Chat UI initialized")


func _setup_trade() -> void:
	var tm: Node = get_node_or_null("/root/TradeManager")
	if tm == null:
		return
	tm.trade_request_received.connect(_on_trade_request_received)
	tm.trade_started.connect(_on_trade_started)
	tm.trade_updated.connect(_on_trade_updated)
	tm.trade_completed.connect(_on_trade_completed)
	tm.trade_cancelled.connect(_on_trade_cancelled)
	print("[HubWorld] Trade system initialized")


func _cleanup_remote_players() -> void:
	for pid in _hw._remote_players:
		var rp: Node2D = _hw._remote_players[pid]
		if is_instance_valid(rp):
			rp.queue_free()
	_hw._remote_players.clear()


func _disconnect_net_signals() -> void:
	var ns := get_node_or_null("/root/NetworkSync")
	if ns != null:
		if ns.world_position_updated.is_connected(_on_remote_position_update):
			ns.world_position_updated.disconnect(_on_remote_position_update)
		if ns.remote_player_joined.is_connected(_on_remote_player_joined):
			ns.remote_player_joined.disconnect(_on_remote_player_joined)
		if ns.remote_player_left.is_connected(_on_remote_player_left):
			ns.remote_player_left.disconnect(_on_remote_player_left)
		if ns.has_signal("world_scene_changed") and ns.world_scene_changed.is_connected(_on_remote_scene_changed):
			ns.world_scene_changed.disconnect(_on_remote_scene_changed)
		if ns.combat_started.is_connected(_on_mp_combat_started):
			ns.combat_started.disconnect(_on_mp_combat_started)
		if ns.rift_entered.is_connected(_on_mp_rift_entered):
			ns.rift_entered.disconnect(_on_mp_rift_entered)
		if ns.rift_exited.is_connected(_on_mp_rift_exited):
			ns.rift_exited.disconnect(_on_mp_rift_exited)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm != null and nm.has_signal("client_connected") and nm.client_connected.is_connected(_on_mp_client_connected):
		nm.client_connected.disconnect(_on_mp_client_connected)
	var ppm := get_node_or_null("/root/PlayerPartyManager")
	if ppm != null:
		if ppm.party_invite_received.is_connected(_on_party_invite_received):
			ppm.party_invite_received.disconnect(_on_party_invite_received)
		if ppm.party_joined.is_connected(_on_party_joined):
			ppm.party_joined.disconnect(_on_party_joined)
		if ppm.party_left.is_connected(_on_party_left):
			ppm.party_left.disconnect(_on_party_left)
		if ppm.party_member_joined.is_connected(_on_party_member_joined):
			ppm.party_member_joined.disconnect(_on_party_member_joined)
		if ppm.party_member_left.is_connected(_on_party_member_left):
			ppm.party_member_left.disconnect(_on_party_member_left)


func _ensure_remote_player(peer_id: int) -> RemotePlayer:
	if _hw._remote_players.has(peer_id):
		var existing := _hw._remote_players[peer_id] as RemotePlayer
		if is_instance_valid(existing):
			return existing
	var rp := RemotePlayer.new()
	var nm: Node = get_node_or_null("/root/NetworkManager")
	var pname := "Player_%d" % peer_id
	if nm != null and nm.has_method("get_player_name"):
		pname = nm.get_player_name(peer_id)
	rp.set_player_info(pname, peer_id)
	rp.cell_size = _hw._map_view.get_cell_size() if is_instance_valid(_hw._map_view) else 24
	_hw._remote_players[peer_id] = rp
	# Add to the world grid
	if is_instance_valid(_hw.world_grid):
		_hw.world_grid.add_child(rp)
	return rp


func _on_remote_position_update(peer_id: int, hex_q: int, hex_r: int, local_x: int, local_y: int) -> void:
	# Only render remote players on the same hex we're currently on
	if hex_q != _hw._player_q or hex_r != _hw._player_r:
		_remove_remote_player_from_scene(peer_id)
		return
	var rp := _ensure_remote_player(peer_id)
	rp.set_grid_pos(local_x, local_y)


func _on_remote_scene_changed(peer_id: int, hex_q: int, hex_r: int) -> void:
	# Remote player moved to a different hex region
	_remove_remote_player_from_scene(peer_id)


func _on_remote_player_joined(peer_id: int, player_name: String) -> void:
	print("[HubWorld] Remote player joined: %s (%d)" % [player_name, peer_id])


func _on_remote_player_left(peer_id: int) -> void:
	_remove_remote_player_from_scene(peer_id)
	_hw._remote_players.erase(peer_id)


func _remove_remote_player_from_scene(peer_id: int) -> void:
	if not _hw._remote_players.has(peer_id):
		return
	var rp := _hw._remote_players[peer_id] as Node2D
	if is_instance_valid(rp):
		rp.queue_free()
	_hw._remote_players.erase(peer_id)


func _on_mp_combat_started(encounter: Dictionary, _participant_peer_ids: Array) -> void:
	if multiplayer.is_server():
		return
	print("[HubWorld] Combat started via multiplayer sync")
	var gm: GameManager = _hw._gm
	if is_instance_valid(gm):
		gm.go_to_tactical_combat(encounter)


func _on_mp_rift_entered(rift_id: String, biome_key: String, rift_data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	print("[HubWorld] Rift enter via multiplayer sync: %s" % rift_id)
	var gm: GameManager = _hw._gm
	if is_instance_valid(gm):
		gm.go_to_rift(rift_id, biome_key, rift_data)


func _on_mp_rift_exited() -> void:
	if multiplayer.is_server():
		return
	print("[HubWorld] Rift exit via multiplayer sync")
	var gm: GameManager = _hw._gm
	if is_instance_valid(gm):
		var gs := _hw._gs
		var char_data: Dictionary = gs.get_character_data() if is_instance_valid(gs) else {}
		gm.go_to_hub(char_data)


func _on_mp_client_connected(peer_id: int) -> void:
	print("[HubWorld] Client %d connected — sending current world state" % peer_id)
	if _hw._net_sync != null and _hw._net_sync.has_method("sync_world_position"):
		_hw._net_sync.sync_world_position(_hw._player_q, _hw._player_r, _hw._local_x, _hw._local_y)
	if _hw._net_sync != null and _hw._net_sync.has_method("sync_hex_transition"):
		_hw._net_sync.sync_hex_transition.rpc_id(peer_id, peer_id, _hw._player_q, _hw._player_r)


func _on_trade_request_received(from_peer_id: int, from_name: String) -> void:
	print("[HubWorld] Trade request from %s (%d)" % [from_name, from_peer_id])
	var popup := AcceptDialog.new()
	popup.dialog_text = "%s wants to trade." % from_name
	popup.title = "Trade Request"
	popup.size = Vector2i(300, 120)
	_hw.add_child(popup)
	popup.popup_centered()
	var hbox := HBoxContainer.new()
	popup.add_child(hbox)
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.pressed.connect(func() -> void:
		var tm: Node = get_node_or_null("/root/TradeManager")
		if tm != null and tm.has_method("accept_trade"):
			tm.accept_trade(from_peer_id)
		popup.queue_free()
	)
	hbox.add_child(accept_btn)
	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.pressed.connect(func() -> void:
		var tm: Node = get_node_or_null("/root/TradeManager")
		if tm != null and tm.has_method("decline_trade"):
			tm.decline_trade(from_peer_id)
		popup.queue_free()
	)
	hbox.add_child(decline_btn)


func _on_trade_started(partner_id: int, partner_name: String) -> void:
	print("[HubWorld] Trade started with %s (%d)" % [partner_name, partner_id])
	var trade_ui := preload("res://scripts/network/TradeUI.gd").new(partner_id, partner_name) as Control
	if trade_ui == null:
		return
	trade_ui.set_trade_manager(get_node_or_null("/root/TradeManager"))
	var canvas := _hw.get_node_or_null("UI_Canvas") as CanvasLayer
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "UI_Canvas"
		_hw.add_child(canvas)
	canvas.add_child(trade_ui)
	_hw.set_meta("trade_ui", trade_ui)


func _on_trade_updated(my_items: Array, partner_items: Array) -> void:
	var trade_ui = _hw.get_meta("trade_ui") if _hw.has_meta("trade_ui") else null
	if trade_ui != null and is_instance_valid(trade_ui) and trade_ui.has_method("refresh"):
		trade_ui.refresh(my_items, partner_items)


func _on_trade_completed() -> void:
	_show_notification("Trade completed!")
	var trade_ui = _hw.get_meta("trade_ui") if _hw.has_meta("trade_ui") else null
	if trade_ui != null and is_instance_valid(trade_ui):
		trade_ui.queue_free()
		_hw.remove_meta("trade_ui")


func _on_trade_cancelled(reason: String) -> void:
	_show_notification("Trade cancelled: %s" % reason)
	var trade_ui = _hw.get_meta("trade_ui") if _hw.has_meta("trade_ui") else null
	if trade_ui != null and is_instance_valid(trade_ui):
		trade_ui.queue_free()
		_hw.remove_meta("trade_ui")


func _focus_chat_input() -> void:
	var chat_ui = _hw.get_meta("chat_ui") if _hw.has_meta("chat_ui") else null
	if chat_ui == null or not is_instance_valid(chat_ui):
		return
	# Find the LineEdit in the chat UI
	for c in chat_ui.get_children():
		var panel := c as PanelContainer
		if panel == null:
			continue
		var vbox := panel.get_child(0) if panel.get_child_count() > 0 else null
		if vbox == null or not (vbox is VBoxContainer):
			continue
		var line_edit := vbox.get_child(vbox.get_child_count() - 1) if vbox.get_child_count() > 0 else null
		if line_edit != null and (line_edit is LineEdit):
			if not line_edit.has_focus():
				line_edit.grab_focus()
			return


func _on_party_invite_received(from_peer_id: int, from_name: String) -> void:
	print("[HubWorld] Party invite from %s (%d)" % [from_name, from_peer_id])
	_show_party_invite_popup(from_peer_id, from_name)


func _on_party_joined(leader_peer_id: int, members: Array) -> void:
	print("[HubWorld] Joined party led by %d" % leader_peer_id)
	_show_notification("Joined party!")


func _on_party_left() -> void:
	print("[HubWorld] Left party")
	_show_notification("Left party")


func _on_party_member_joined(peer_id: int, name: String) -> void:
	print("[HubWorld] Party member joined: %s (%d)" % [name, peer_id])
	_show_notification("%s joined the party" % name)


func _on_party_member_left(peer_id: int, name: String) -> void:
	print("[HubWorld] Party member left: %s (%d)" % [name, peer_id])
	_show_notification("%s left the party" % name)


func _show_party_invite_popup(from_peer_id: int, from_name: String) -> void:
	var popup := AcceptDialog.new()
	popup.dialog_text = "%s has invited you to a party." % from_name
	popup.title = "Party Invite"
	popup.size = Vector2i(300, 120)
	_hw.add_child(popup)
	popup.popup_centered()
	# Add custom buttons
	var hbox := HBoxContainer.new()
	popup.add_child(hbox)
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.pressed.connect(func() -> void:
		var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
		if ppm != null and ppm.has_method("accept_invite"):
			ppm.accept_invite(from_peer_id)
		popup.queue_free()
	)
	hbox.add_child(accept_btn)
	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.pressed.connect(func() -> void:
		var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
		if ppm != null and ppm.has_method("decline_invite"):
			ppm.decline_invite(from_peer_id)
		popup.queue_free()
	)
	hbox.add_child(decline_btn)
	# Auto-timeout after 15 seconds
	var timer := Timer.new()
	timer.wait_time = 14.0
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(popup):
			var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
			if ppm != null and ppm.has_method("decline_invite"):
				ppm.decline_invite(from_peer_id)
			popup.queue_free()
		timer.queue_free()
	)
	_hw.add_child(timer)
	timer.start()


func _pull_party_into_rift(rift_id: String, biome: String, rift: Dictionary) -> void:
	var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
	if ppm == null or not ppm.has_method("get_party_member_list"):
		return
	if not ppm.has_method("is_party_leader") or not ppm.is_party_leader():
		return
	var targets: Array[int] = []
	for member in ppm.get_party_member_list():
		var pid: int = int(member.get("peer_id", -1))
		if pid < 0:
			continue
		if pid == multiplayer.get_unique_id():
			continue
		# Only pull if on same hex and auto_join_rifts enabled
		if _hw._remote_players.has(pid):
			if ppm.has_method("is_member_auto_join_rifts") and ppm.is_member_auto_join_rifts(pid):
				targets.append(pid)
	if targets.is_empty():
		return
	if _hw._net_sync != null and _hw._net_sync.has_method("sync_rift_enter_targeted"):
		_hw._net_sync.sync_rift_enter_targeted(rift_id, biome, rift, targets)
		print("[HubWorld] Pulling %d party member(s) into rift" % targets.size())


func _add_nearby_players_to_encounter(encounter: Dictionary, combat_lx: int, combat_ly: int) -> void:
	var participants: Array[Dictionary] = []
	# 1. Nearby remote players (within 5 cells)
	var nearby := _get_remote_players_near(combat_lx, combat_ly, 5)
	for pid in nearby:
		var nm: Node = get_node_or_null("/root/NetworkManager")
		var pname := "Player_%d" % pid
		if nm != null and nm.has_method("get_player_name"):
			pname = nm.get_player_name(pid)
		participants.append({"peer_id": pid, "name": pname, "source": "nearby"})
	# 2. Party members with auto_join_battles (on same hex, any distance)
	var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
	if ppm != null and ppm.has_method("get_party_member_list") and ppm.has_method("is_party_leader"):
		if ppm.is_party_leader():
			for member in ppm.get_party_member_list():
				var pid: int = int(member.get("peer_id", -1))
				if pid < 0:
					continue
				# Skip if already included from nearby check
				var already := false
				for p in participants:
					if int(p.get("peer_id", -1)) == pid:
						already = true
						break
				if already:
					continue
				# Check if on same hex and auto_join enabled
				if ppm.has_method("is_member_auto_join_battles") and ppm.is_member_auto_join_battles(pid):
					var rp := _hw._remote_players.get(pid) as RemotePlayer
					if rp != null and is_instance_valid(rp):
						participants.append({"peer_id": pid, "name": member.get("name", "Player_%d" % pid), "source": "party"})
	if participants.is_empty():
		return
	encounter["multiplayer_participants"] = participants
	print("[HubWorld] %d remote player(s) included in combat (%d nearby, %d party)" % [
		participants.size(), nearby.size(), participants.size() - nearby.size()
	])


func _get_remote_players_near(grid_x: int, grid_y: int, range_cells: int) -> Array[int]:
	var result: Array[int] = []
	for pid in _hw._remote_players:
		var rp := _hw._remote_players[pid] as RemotePlayer
		if not is_instance_valid(rp):
			continue
		var dx = abs(int(rp.position.x / rp.cell_size) - grid_x)
		var dy = abs(int(rp.position.y / rp.cell_size) - grid_y)
		if dx <= range_cells and dy <= range_cells:
			result.append(pid)
	return result


func _show_notification(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
	label.position = Vector2(400, 300)
	label.size = Vector2(480, 30)
	label.z_index = 200
	var canvas := _hw.get_node_or_null("UI_Canvas") as CanvasLayer
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "UINotify"
		_hw.add_child(canvas)
	canvas.add_child(label)
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
		timer.queue_free()
	)
	_hw.add_child(timer)
	timer.start()
