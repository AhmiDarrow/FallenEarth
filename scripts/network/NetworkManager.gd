## NetworkManager — ENet multiplayer peer lifecycle
extends Node

signal server_started(port: int)
signal server_stopped()
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal connection_failed(error: String)
signal player_registered(peer_id: int, player_name: String)
signal player_unregistered(peer_id: int)
signal state_snapshot_taken(snapshot_id: int)
signal mod_mismatch_kicked(reason: String)

enum Role { NONE, SERVER, CLIENT }

const DEFAULT_PORT := 28900
const SNAPSHOT_INTERVAL := 5.0

var role: int = Role.NONE
var peer: ENetMultiplayerPeer = null
var player_names: Dictionary = {}
var player_data: Dictionary = {}
var reconnect_tokens: Dictionary = {}
var _snapshot_timer: float = 0.0
var _snapshot_count: int = 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	randomize()


func _process(delta: float) -> void:
	if role != Role.SERVER:
		return
	_snapshot_timer += delta
	if _snapshot_timer >= SNAPSHOT_INTERVAL:
		_snapshot_timer = 0.0
		_take_state_snapshot()


func start_server(port: int = DEFAULT_PORT) -> bool:
	if role != Role.NONE:
		stop()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("[NetworkManager] Failed to create server on port %d: %d" % [port, err])
		connection_failed.emit("Failed to create server (code %d)" % err)
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	role = Role.SERVER
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[NetworkManager] Server started on port %d" % port)
	server_started.emit(port)
	return true


func start_client(host: String, port: int = DEFAULT_PORT) -> bool:
	if role != Role.NONE:
		stop()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		push_error("[NetworkManager] Failed to connect to %s:%d: %d" % [host, port, err])
		connection_failed.emit("Failed to connect (code %d)" % err)
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	print("[NetworkManager] Client connecting to %s:%d" % [host, port])
	return true


func stop() -> void:
	if role == Role.SERVER:
		server_stopped.emit()
	multiplayer.multiplayer_peer = null
	if peer != null:
		peer.close()
		peer = null
	player_names.clear()
	player_data.clear()
	reconnect_tokens.clear()
	role = Role.NONE
	print("[NetworkManager] Stopped")


func get_my_peer_id() -> int:
	return multiplayer.get_unique_id()


func is_server() -> bool:
	return role == Role.SERVER


func is_client() -> bool:
	return role == Role.CLIENT


func add_player(peer_id: int, player_name: String) -> void:
	player_names[peer_id] = player_name
	player_data[peer_id] = {}
	player_registered.emit(peer_id, player_name)


func unregister_player(peer_id: int) -> void:
	player_names.erase(peer_id)
	player_data.erase(peer_id)
	reconnect_tokens.erase(peer_id)
	player_unregistered.emit(peer_id)


func get_player_name(peer_id: int) -> String:
	return player_names.get(peer_id, "Player_%d" % peer_id)


func update_player_data(peer_id: int, data: Dictionary) -> void:
	player_data[peer_id] = data.duplicate(true)


func get_player_data(peer_id: int) -> Dictionary:
	return player_data.get(peer_id, {}).duplicate(true)


func get_connected_players() -> Array[int]:
	var result: Array[int] = []
	for pid in player_names:
		result.append(pid)
	return result


func issue_reconnect_token(peer_id: int) -> String:
	var token := "%s_%d_%d" % [_generate_token(), peer_id, Time.get_ticks_msec()]
	reconnect_tokens[peer_id] = token
	return token


func validate_reconnect_token(token: String) -> int:
	for pid in reconnect_tokens:
		if reconnect_tokens[pid] == token:
			return pid
	return -1


func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] Peer connected: %d" % peer_id)
	client_connected.emit(peer_id)
	_server_request_mod_list.rpc_id(peer_id, peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] Peer disconnected: %d" % peer_id)
	if reconnect_tokens.has(peer_id):
		print("[NetworkManager] Peer %d has reconnect token — preserving state" % peer_id)
		return
	unregister_player(peer_id)
	client_disconnected.emit(peer_id)


func _rpc_register_self(new_peer_id: int) -> void:
	register_player.rpc_id(new_peer_id, multiplayer.get_unique_id())


@rpc("any_peer", "call_local", "reliable")
func register_player(requester_id: int) -> void:
	if not is_server():
		return
	var caller_id := multiplayer.get_remote_sender_id()
	var name_str := "Player_%d" % caller_id
	add_player(caller_id, name_str)
	_sync_player_list()


func _sync_player_list() -> void:
	_sync_player_list_all.rpc(player_names.duplicate())


@rpc("authority", "call_local", "reliable")
func _sync_player_list_all(names: Dictionary) -> void:
	player_names = names.duplicate()


@rpc("authority", "call_local", "reliable")
func _server_request_mod_list(peer_id: int) -> void:
	if not is_server():
		return
	_client_send_mod_list.rpc_id(peer_id, multiplayer.get_unique_id())


@rpc("any_peer", "call_local", "reliable")
func _client_send_mod_list(requester_id: int) -> void:
	if not is_server():
		return
	var caller_id := multiplayer.get_remote_sender_id()
	var ml := get_node_or_null("/root/ModLoader")
	var mod_summary: Dictionary = {}
	if ml != null and ml.has_method("get_installed_mods_summary"):
		mod_summary = ml.get_installed_mods_summary()
	_server_receive_mod_list.rpc_id(requester_id, caller_id, mod_summary)


@rpc("authority", "call_local", "reliable")
func _server_receive_mod_list(peer_id: int, client_mods: Dictionary) -> void:
	if not is_server():
		return
	var ml := get_node_or_null("/root/ModLoader")
	var server_mods: Dictionary = {}
	if ml != null and ml.has_method("get_installed_mods_summary"):
		server_mods = ml.get_installed_mods_summary()
	var server_list: Array = server_mods.get("installed", [])
	var client_list: Array = client_mods.get("installed", [])
	var missing: Array = []
	var extra: Array = []
	for mod_entry in server_list:
		var mod_id: String = str(mod_entry).split("@")[0]
		if not _list_has_mod(client_list, mod_id):
			missing.append(str(mod_entry))
	for mod_entry in client_list:
		var mod_id: String = str(mod_entry).split("@")[0]
		if not _list_has_mod(server_list, mod_id):
			extra.append(str(mod_entry))
	if missing.is_empty() and extra.is_empty():
		var name_str := "Player_%d" % peer_id
		add_player(peer_id, name_str)
		_sync_player_list()
	else:
		_kick_with_mod_mismatch(peer_id, missing, extra)


func _list_has_mod(mod_list: Array, mod_id: String) -> bool:
	for entry in mod_list:
		if str(entry).split("@")[0] == mod_id:
			return true
	return false


func _kick_with_mod_mismatch(peer_id: int, missing: Array, extra: Array) -> void:
	var reason := "Mod mismatch with server."
	if not missing.is_empty():
		reason += " Missing: [%s]." % ", ".join(missing)
	if not extra.is_empty():
		reason += " Extra (not on server): [%s]." % ", ".join(extra)
	reason += " Install the required mods and reconnect."
	print("[NetworkManager] Kicking peer %d: %s" % [peer_id, reason])
	_notify_mod_mismatch.rpc_id(peer_id, reason)
	await get_tree().create_timer(1.0).timeout
	multiplayer.disconnect_peer(peer_id)


@rpc("authority", "call_local", "reliable")
func _notify_mod_mismatch(reason: String) -> void:
	mod_mismatch_kicked.emit(reason)


func _generate_token() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var result := ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(8):
		result += chars[rng.randi() % chars.length()]
	return result


func _take_state_snapshot() -> void:
	_snapshot_count += 1
	var snapshot := {
		"id": _snapshot_count,
		"time": Time.get_ticks_msec(),
		"players": player_data.duplicate(true),
		"names": player_names.duplicate(true),
	}
	_take_state_snapshot_rpc.rpc(snapshot)


@rpc("authority", "call_local", "reliable")
func _take_state_snapshot_rpc(snapshot: Dictionary) -> void:
	state_snapshot_taken.emit(snapshot.id)
