## PlayerPartyManager — Player-to-player party system
extends Node

signal party_invite_received(from_peer_id: int, from_name: String)
signal party_invite_expired(from_peer_id: int)
signal party_joined(leader_peer_id: int, members: Array)
signal party_left()
signal party_member_joined(peer_id: int, name: String)
signal party_member_left(peer_id: int, name: String)
signal party_leader_changed(new_leader: int)
signal party_data_updated(party: Dictionary)
signal auto_join_changed(peer_id: int, battles: bool, rifts: bool)

const INVITE_TIMEOUT := 15.0

var party_leader: int = -1
var party_members: Dictionary = {}
var _pending_invites: Dictionary = {}
var _net: Node = null
var _net_sync: Node = null


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_net = get_node_or_null("/root/NetworkManager")
	_net_sync = get_node_or_null("/root/NetworkSync")


func _process(delta: float) -> void:
	var expired: Array[int] = []
	for pid in _pending_invites:
		var inv: Dictionary = _pending_invites[pid]
		inv["timer"] -= delta
		if inv["timer"] <= 0.0:
			expired.append(pid)
	for pid in expired:
		_pending_invites.erase(pid)
		party_invite_expired.emit(pid)


func is_in_party() -> bool:
	return party_leader >= 0


func is_party_leader() -> bool:
	if not is_in_party():
		return false
	var my_id := multiplayer.get_unique_id()
	return party_leader == my_id


func get_party_member_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_in_party():
		return result
	for pid in party_members:
		var m: Dictionary = party_members[pid].duplicate()
		m["peer_id"] = pid
		result.append(m)
	var my_id := multiplayer.get_unique_id()
	if not _member_dict_has_id(result, my_id):
		var nm: Node = get_node_or_null("/root/NetworkManager")
		var my_name := "Player_%d" % my_id
		if nm != null and nm.has_method("get_player_name"):
			my_name = nm.get_player_name(my_id)
		result.append({"peer_id": my_id, "name": my_name, "auto_join_battles": true, "auto_join_rifts": true})
	return result


func _member_dict_has_id(list: Array, pid: int) -> bool:
	for entry in list:
		if int(entry.get("peer_id", -1)) == pid:
			return true
	return false


func send_invite(target_peer_id: int) -> bool:
	if not _can_initiate_party():
		return false
	_send_invite_rpc.rpc_id(target_peer_id, multiplayer.get_unique_id(), _get_my_name())
	return true


func accept_invite(from_peer_id: int) -> void:
	_pending_invites.erase(from_peer_id)
	_accept_invite_rpc.rpc_id(from_peer_id, multiplayer.get_unique_id(), _get_my_name())


func decline_invite(from_peer_id: int) -> void:
	_pending_invites.erase(from_peer_id)
	_decline_invite_rpc.rpc_id(from_peer_id, multiplayer.get_unique_id())


func leave_party() -> void:
	if not is_in_party():
		return
	if is_party_leader():
		_disband_party()
		return
	_leave_party_rpc.rpc_id(party_leader, multiplayer.get_unique_id())
	_clear_party_state()


func kick_from_party(target_peer_id: int) -> void:
	if not is_party_leader():
		return
	_kick_from_party_rpc.rpc_id(target_peer_id)
	_remove_member(target_peer_id)


func set_auto_join(battles: bool, rifts: bool) -> void:
	if not is_in_party():
		return
	var my_id := multiplayer.get_unique_id()
	if party_members.has(my_id):
		party_members[my_id]["auto_join_battles"] = battles
		party_members[my_id]["auto_join_rifts"] = rifts
	auto_join_changed.emit(my_id, battles, rifts)
	_sync_auto_join_rpc.rpc_id(party_leader, my_id, battles, rifts)


@rpc("any_peer", "call_local", "reliable")
func _send_invite_rpc(from_peer_id: int, from_name: String) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != from_peer_id:
		return
	if is_in_party():
		_invite_declined_rpc.rpc_id(caller, "already_in_party")
		return
	_pending_invites[from_peer_id] = {"from_name": from_name, "timer": INVITE_TIMEOUT}
	party_invite_received.emit(from_peer_id, from_name)


@rpc("any_peer", "call_local", "reliable")
func _accept_invite_rpc(accepter_id: int, accepter_name: String) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != accepter_id:
		return
	if not _can_initiate_party():
		return
	_add_member(accepter_id, accepter_name)
	_joined_party_rpc.rpc_id(accepter_id, multiplayer.get_unique_id(), _serialize_party())
	_broadcast_party_update()


@rpc("any_peer", "call_local", "reliable")
func _decline_invite_rpc(decliner_id: int) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != decliner_id:
		return
	print("[PlayerPartyManager] Player %d declined invite" % decliner_id)


@rpc("authority", "call_local", "reliable")
func _joined_party_rpc(leader_id: int, party_data: Dictionary) -> void:
	party_leader = leader_id
	_deserialize_party(party_data)
	party_joined.emit(leader_id, get_party_member_list())


@rpc("any_peer", "call_local", "reliable")
func _leave_party_rpc(leaver_id: int) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != leaver_id:
		return
	_remove_member(leaver_id)
	if party_members.is_empty():
		_clear_party_state()
	else:
		_broadcast_party_update()


@rpc("authority", "call_local", "reliable")
func _kick_from_party_rpc() -> void:
	_clear_party_state()
	party_left.emit()


@rpc("authority", "call_local", "reliable")
func _party_update_rpc(party_data: Dictionary) -> void:
	_deserialize_party(party_data)
	party_data_updated.emit(party_data)


@rpc("any_peer", "call_local", "reliable")
func _sync_auto_join_rpc(peer_id: int, battles: bool, rifts: bool) -> void:
	if party_members.has(peer_id):
		party_members[peer_id]["auto_join_battles"] = battles
		party_members[peer_id]["auto_join_rifts"] = rifts
	auto_join_changed.emit(peer_id, battles, rifts)


@rpc("any_peer", "call_local", "reliable")
func _invite_declined_rpc(reason: String) -> void:
	print("[PlayerPartyManager] Invite declined: %s" % reason)


func _can_initiate_party() -> bool:
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm == null or not nm.has_method("is_server"):
		return false
	return nm.is_server()


func _get_my_name() -> String:
	var my_id := multiplayer.get_unique_id()
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm != null and nm.has_method("get_player_name"):
		return nm.get_player_name(my_id)
	return "Player_%d" % my_id


func _add_member(peer_id: int, name: String) -> void:
	party_members[peer_id] = {
		"name": name,
		"auto_join_battles": true,
		"auto_join_rifts": true,
		"character_data": {},
	}
	party_member_joined.emit(peer_id, name)


func _remove_member(peer_id: int) -> void:
	var name := ""
	if party_members.has(peer_id):
		name = party_members[peer_id].get("name", "")
		party_members.erase(peer_id)
	party_member_left.emit(peer_id, name)


func _clear_party_state() -> void:
	var old_members := party_members.duplicate()
	party_leader = -1
	party_members.clear()
	party_left.emit()
	for pid in old_members:
		party_member_left.emit(pid, old_members[pid].get("name", ""))


func _disband_party() -> void:
	for pid in party_members:
		_kick_from_party_rpc.rpc_id(pid)
	_clear_party_state()


func _broadcast_party_update() -> void:
	var data := _serialize_party()
	for pid in party_members:
		_party_update_rpc.rpc_id(pid, data)


func _serialize_party() -> Dictionary:
	return {
		"leader": party_leader,
		"members": party_members.duplicate(true),
	}


func _deserialize_party(data: Dictionary) -> void:
	party_leader = int(data.get("leader", -1))
	var raw: Dictionary = data.get("members", {})
	party_members.clear()
	for pid in raw:
		party_members[int(pid)] = raw[pid].duplicate(true)


func get_auto_join_battles() -> bool:
	if not is_in_party():
		return false
	var my_id := multiplayer.get_unique_id()
	if party_members.has(my_id):
		return party_members[my_id].get("auto_join_battles", true)
	return true


func get_auto_join_rifts() -> bool:
	if not is_in_party():
		return false
	var my_id := multiplayer.get_unique_id()
	if party_members.has(my_id):
		return party_members[my_id].get("auto_join_rifts", true)
	return true


func is_member_auto_join_battles(peer_id: int) -> bool:
	if party_members.has(peer_id):
		return party_members[peer_id].get("auto_join_battles", true)
	return false


func is_member_auto_join_rifts(peer_id: int) -> bool:
	if party_members.has(peer_id):
		return party_members[peer_id].get("auto_join_rifts", true)
	return false
