## LobbyManager — Lobby creation, join codes, UPnP discovery, player list
## Singleton that layers on top of NetworkManager.
extends Node

signal lobby_created(join_code: String)
signal lobby_joined(host: String, port: int)
signal lobby_closed()
signal player_joined_lobby(peer_id: int, player_name: String)
signal player_left_lobby(peer_id: int, player_name: String)
signal lobby_list_updated(lobbies: Array)  # LAN discovery

const DEFAULT_PORT := 28900
const BROADCAST_PORT := 28901
const LOBBY_CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var _net: Node = null
var _upnp: UPNP = null
var _join_code: String = ""
var _lan_broadcast_enabled: bool = true
var _broadcast_peer: PacketPeerUDP = null
var _discovered_lobbies: Array = []  # each: {host, port, name, player_count}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_net = get_node_or_null("/root/NetworkManager")
	if _net == null:
		push_warning("[LobbyManager] NetworkManager not found — will retry")
		await get_tree().process_frame
		_net = get_node_or_null("/root/NetworkManager")


func host_lobby(lobby_name: String = "Fallen Earth Game") -> bool:
	if _net == null or not _net.has_method("start_server"):
		push_error("[LobbyManager] NetworkManager unavailable")
		return false

	if not _net.start_server(DEFAULT_PORT):
		return false

	_join_code = _generate_code()
	_setup_upnp()

	if _lan_broadcast_enabled:
		_start_lan_broadcast(lobby_name)

	print("[LobbyManager] Lobby created: %s (code: %s)" % [lobby_name, _join_code])
	lobby_created.emit(_join_code)

	# Listen for players on the network manager
	if _net.is_connected("client_connected", _on_player_connected):
		return true
	_net.client_connected.connect(_on_player_connected)
	_net.client_disconnected.connect(_on_player_disconnected)
	return true


func join_lobby(host: String, port: int = DEFAULT_PORT) -> bool:
	if _net == null or not _net.has_method("start_client"):
		push_error("[LobbyManager] NetworkManager unavailable")
		return false

	var result: bool = _net.start_client(host, port)
	if result:
		print("[LobbyManager] Joining lobby at %s:%d" % [host, port])
		lobby_joined.emit(host, port)
	return result


func join_by_code(code: String) -> bool:
	# For LAN: resolve join code to IP via broadcast
	code = code.strip_edges().to_upper()
	if code.is_empty():
		return false
	# Simple join: we assume manual IP for now, code is just display
	# In a fuller implementation, a matchmaking relay would map code -> IP
	push_warning("[LobbyManager] join_by_code requires a matchmaking relay or known IP")
	return false


func close_lobby() -> void:
	if _net != null and _net.has_method("stop"):
		_net.stop()
	_cleanup_upnp()
	_cleanup_broadcast()
	_join_code = ""
	lobby_closed.emit()


func get_join_code() -> String:
	return _join_code


func get_player_list() -> Array[Dictionary]:
	if _net == null:
		return []
	var result: Array[Dictionary] = []
	var names: Dictionary = _net.player_names if _net.has_method("get_player_name") else {}
	for pid in names:
		result.append({
			"peer_id": pid,
			"name": _net.get_player_name(pid) if _net.has_method("get_player_name") else str(names[pid]),
		})
	# Include host if server
	if _net != null and _net.is_server():
		result.push_front({
			"peer_id": _net.get_my_peer_id(),
			"name": _net.get_player_name(_net.get_my_peer_id()) if _net.has_method("get_player_name") else "Host",
		})
	return result


func start_lan_discovery() -> void:
	_discovered_lobbies.clear()
	_start_broadcast_listener()


func get_discovered_lobbies() -> Array:
	return _discovered_lobbies.duplicate()


func set_lan_broadcast_enabled(enabled: bool) -> void:
	_lan_broadcast_enabled = enabled
	if not enabled:
		_cleanup_broadcast()


func _generate_code() -> String:
	var result := ""
	for i in range(6):
		result += LOBBY_CODE_CHARS[randi() % LOBBY_CODE_CHARS.length()]
	return result


func _setup_upnp() -> void:
	_upnp = UPNP.new()
	var err := _upnp.discover()
	if err != OK:
		print("[LobbyManager] UPnP discovery failed (code %d) — LAN only" % err)
		_upnp = null
		return
	var gateway_err := _upnp.add_port_mapping(DEFAULT_PORT)
	if gateway_err != OK:
		print("[LobbyManager] UPnP port mapping failed (code %d) — LAN only" % gateway_err)
	else:
		print("[LobbyManager] UPnP port %d mapped successfully" % DEFAULT_PORT)


func _cleanup_upnp() -> void:
	if _upnp != null:
		_upnp.delete_port_mapping(DEFAULT_PORT)
		_upnp = null


func _start_lan_broadcast(lobby_name: String) -> void:
	_cleanup_broadcast()
	_broadcast_peer = PacketPeerUDP.new()
	_broadcast_peer.set_broadcast_enabled(true)
	var err: Error = _broadcast_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	if err != OK:
		_broadcast_peer = null
		return
	var announce := JSON.stringify({
		"type": "fallen_earth_lobby",
		"name": lobby_name,
		"port": DEFAULT_PORT,
		"code": _join_code,
		"players": 1,
	})
	_broadcast_peer.put_var(announce.to_utf8_buffer())
	# Start periodic broadcast
	var timer := Timer.new()
	timer.name = "BroadcastTimer"
	timer.wait_time = 3.0
	timer.timeout.connect(_broadcast_announce.bind(lobby_name))
	add_child(timer)
	timer.start()


func _broadcast_announce(lobby_name: String) -> void:
	if _broadcast_peer == null:
		return
	var announce := JSON.stringify({
		"type": "fallen_earth_lobby",
		"name": lobby_name,
		"port": DEFAULT_PORT,
		"code": _join_code,
		"players": _get_player_count(),
	})
	_broadcast_peer.put_var(announce.to_utf8_buffer())


func _get_player_count() -> int:
	if _net == null:
		return 1
	var count := 1  # host
	for pid in _net.player_names:
		count += 1
	return count


func _start_broadcast_listener() -> void:
	var listener := PacketPeerUDP.new()
	var err := listener.bind(BROADCAST_PORT, "*")
	if err != OK:
		print("[LobbyManager] Could not bind broadcast listener (port %d): %d" % [BROADCAST_PORT, err])
		return
	# Use a timer to poll
	var poll_timer := Timer.new()
	poll_timer.name = "PollTimer"
	poll_timer.wait_time = 1.0
	poll_timer.timeout.connect(_poll_broadcast.bind(listener))
	add_child(poll_timer)
	poll_timer.start()


func _poll_broadcast(listener: PacketPeerUDP) -> void:
	while listener.get_available_packet_count() > 0:
		var data: PackedByteArray = listener.get_var()
		if data.is_empty():
			continue
		var text := data.get_string_from_utf8()
		var parsed: Dictionary = JSON.parse_string(text) as Dictionary
		if parsed == null or parsed.get("type") != "fallen_earth_lobby":
			continue
		var host := listener.get_packet_ip()
		var entry := {
			"host": host,
			"port": int(parsed.get("port", DEFAULT_PORT)),
			"name": str(parsed.get("name", "Unknown")),
			"code": str(parsed.get("code", "")),
			"players": int(parsed.get("players", 0)),
		}
		# Deduplicate
		var exists := false
		for existing in _discovered_lobbies:
			if existing.host == entry.host and existing.port == entry.port:
				exists = true
				existing.name = entry.name
				existing.players = entry.players
				break
		if not exists:
			_discovered_lobbies.append(entry)
		lobby_list_updated.emit(_discovered_lobbies.duplicate())


func _cleanup_broadcast() -> void:
	if _broadcast_peer != null:
		_broadcast_peer.close()
		_broadcast_peer = null
	var timer := get_node_or_null("BroadcastTimer")
	if timer != null:
		timer.queue_free()
	var poll_timer := get_node_or_null("PollTimer")
	if poll_timer != null:
		poll_timer.queue_free()


func _on_player_connected(peer_id: int) -> void:
	if _net == null:
		return
	var name_str: String = _net.get_player_name(peer_id) if _net.has_method("get_player_name") else "Player_%d" % peer_id
	player_joined_lobby.emit(peer_id, name_str)


func _on_player_disconnected(peer_id: int) -> void:
	if _net == null:
		return
	var name_str: String = _net.get_player_name(peer_id) if _net.has_method("get_player_name") else "Player_%d" % peer_id
	player_left_lobby.emit(peer_id, name_str)
