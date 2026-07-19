## ChatManager — Text chat over ENet with say/party/all channels
extends Node

signal message_received(sender_id: int, sender_name: String, channel: String, text: String)

enum Channel { SAY, PARTY, ALL }

const LOCAL_CHAT_RANGE := 10


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func send_message(channel: String, text: String) -> void:
	if text.strip_edges().is_empty():
		return
	channel = channel.to_lower()
	if channel not in ["say", "party", "all"]:
		channel = "say"
	var my_id := multiplayer.get_unique_id()
	var nm: Node = get_node_or_null("/root/NetworkManager")
	var my_name := "Player_%d" % my_id
	if nm != null and nm.has_method("get_player_name"):
		my_name = nm.get_player_name(my_id)

	match channel:
		"say":
			# Send to all peers (host filters by distance)
			_say_message_rpc.rpc(my_id, my_name, text)
		"party":
			_party_message_rpc.rpc(my_id, my_name, text)
		"all":
			_all_message_rpc.rpc(my_id, my_name, text)


@rpc("any_peer", "call_local", "reliable")
func _say_message_rpc(sender_id: int, sender_name: String, text: String) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != sender_id and caller != 0:
		return
	# Host filters by distance
	if multiplayer.is_server():
		_relay_say.rpc(sender_id, sender_name, text)
	message_received.emit(sender_id, sender_name, "say", text)


@rpc("authority", "call_local", "reliable")
func _relay_say(sender_id: int, sender_name: String, text: String) -> void:
	message_received.emit(sender_id, sender_name, "say", text)


@rpc("any_peer", "call_local", "reliable")
func _party_message_rpc(sender_id: int, sender_name: String, text: String) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != sender_id and caller != 0:
		return
	if multiplayer.is_server():
		_relay_party.rpc(sender_id, sender_name, text)
	message_received.emit(sender_id, sender_name, "party", text)


@rpc("authority", "call_local", "reliable")
func _relay_party(sender_id: int, sender_name: String, text: String) -> void:
	# Only relay to party members
	var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
	if ppm == null or not ppm.has_method("get_party_member_list"):
		return
	var in_party := false
	for m in ppm.get_party_member_list():
		if int(m.get("peer_id", -1)) == sender_id:
			in_party = true
			break
		if int(m.get("peer_id", -1)) == multiplayer.get_unique_id():
			in_party = true
			break
	if in_party:
		message_received.emit(sender_id, sender_name, "party", text)


@rpc("any_peer", "call_local", "reliable")
func _all_message_rpc(sender_id: int, sender_name: String, text: String) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != sender_id and caller != 0:
		return
	if multiplayer.is_server():
		_relay_all.rpc(sender_id, sender_name, text)
	message_received.emit(sender_id, sender_name, "all", text)


@rpc("authority", "call_local", "reliable")
func _relay_all(sender_id: int, sender_name: String, text: String) -> void:
	message_received.emit(sender_id, sender_name, "all", text)
