## NetworkSync — Property replication, world state sync, networked object management
## Singleton that provides utilities for syncing game state across peers.
extends Node

signal node_spawned(net_id: int, path: String)
signal node_despawned(net_id: int)
signal world_position_updated(peer_id: int, hex_q: int, hex_r: int, local_x: int, local_y: int)
signal remote_player_joined(peer_id: int, player_name: String)
signal remote_player_left(peer_id: int)
signal world_scene_changed(peer_id: int, hex_q: int, hex_r: int)
signal combat_started(encounter: Dictionary, participant_peer_ids: Array)
signal rift_entered(rift_id: String, biome_key: String, rift_data: Dictionary)
signal rift_exited()

var _next_net_id: int = 1000
var _spawned_nodes: Dictionary = {}  # net_id -> NodePath
var _owned_nodes: Dictionary = {}    # peer_id -> Array[net_id]
var _player_positions: Dictionary = {}  # peer_id -> {q, r, lx, ly}
var _remote_visuals: Dictionary = {}    # peer_id -> NodePath in scene tree


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func spawn_node(path: String, properties: Dictionary = {}, parent_path: String = "") -> int:
	var net_id := _next_net_id
	_next_net_id += 1
	_spawn_node_rpc.rpc(net_id, path, properties, parent_path)
	return net_id


func despawn_node(net_id: int) -> void:
	_despawn_node_rpc.rpc(net_id)


func register_owned_node(peer_id: int, net_id: int) -> void:
	if not _owned_nodes.has(peer_id):
		_owned_nodes[peer_id] = []
	_owned_nodes[peer_id].append(net_id)


func get_owned_nodes(peer_id: int) -> Array:
	return _owned_nodes.get(peer_id, []).duplicate()


func sync_property(node_path: NodePath, property: String, value: Variant) -> void:
	_sync_property_rpc.rpc(node_path, property, var_to_bytes(value))


func sync_transform(node_path: NodePath, position: Vector2) -> void:
	_sync_transform_rpc.rpc(node_path, position)


@rpc("authority", "call_local", "reliable")
func _spawn_node_rpc(net_id: int, path: String, properties: Dictionary, parent_path: String) -> void:
	_spawned_nodes[net_id] = path
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("[NetworkSync] Failed to load scene: %s" % path)
		return
	var instance := scene.instantiate() as Node
	if instance == null:
		push_error("[NetworkSync] Failed to instantiate scene: %s" % path)
		return
	var parent: Node = null
	if not parent_path.is_empty():
		parent = get_node_or_null(parent_path)
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		push_warning("[NetworkSync] No parent found for net_id %d — adding to root" % net_id)
		parent = get_tree().root
	parent.add_child(instance)
	instance.add_to_group("net_%d" % net_id)
	# Apply properties
	for key in properties:
		if instance.has_method("set_" + key):
			instance.call("set_" + key, properties[key])
		elif key in instance:
			instance.set(key, properties[key])
	instance.set_meta("net_id", net_id)
	node_spawned.emit(net_id, path)


@rpc("authority", "call_local", "reliable")
func _despawn_node_rpc(net_id: int) -> void:
	_spawned_nodes.erase(net_id)
	for peer_id in _owned_nodes:
		_owned_nodes[peer_id].erase(net_id)
	# Find and remove all nodes in group
	var nodes := get_tree().get_nodes_in_group("net_%d" % net_id)
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	node_despawned.emit(net_id)


@rpc("authority", "call_local", "unreliable")
func _sync_property_rpc(node_path: NodePath, property: String, value_bytes: PackedByteArray) -> void:
	var node := get_node_or_null(node_path)
	if node == null:
		return
	var value: Variant = bytes_to_var(value_bytes)
	if node.has_method("set_" + property):
		node.call("set_" + property, value)
	elif property in node:
		node.set(property, value)


@rpc("authority", "call_local", "unreliable")
func _sync_transform_rpc(node_path: NodePath, position: Vector2) -> void:
	var node := get_node_or_null(node_path) as Node2D
	if node == null:
		return
	node.position = position


## Broadcast the host's hex + local position to all peers.
func sync_world_position(hex_q: int, hex_r: int, local_x: int, local_y: int) -> void:
	var caller := multiplayer.get_unique_id()
	_player_positions[caller] = {"q": hex_q, "r": hex_r, "lx": local_x, "ly": local_y}
	_sync_world_position_rpc.rpc(caller, hex_q, hex_r, local_x, local_y)


## Broadcast a world-map hex transition to all peers.
func sync_hex_transition(hex_q: int, hex_r: int) -> void:
	var caller := multiplayer.get_unique_id()
	_player_positions[caller] = {"q": hex_q, "r": hex_r, "lx": _player_positions.get(caller, {}).get("lx", 0), "ly": _player_positions.get(caller, {}).get("ly", 0)}
	_sync_hex_transition_rpc.rpc(caller, hex_q, hex_r)


@rpc("authority", "call_local", "reliable")
func _sync_world_position_rpc(peer_id: int, hex_q: int, hex_r: int, local_x: int, local_y: int) -> void:
	_player_positions[peer_id] = {"q": hex_q, "r": hex_r, "lx": local_x, "ly": local_y}
	world_position_updated.emit(peer_id, hex_q, hex_r, local_x, local_y)


@rpc("authority", "call_local", "reliable")
func _sync_hex_transition_rpc(peer_id: int, hex_q: int, hex_r: int) -> void:
	if not _player_positions.has(peer_id):
		_player_positions[peer_id] = {"q": hex_q, "r": hex_r, "lx": 0, "ly": 0}
	else:
		var pos: Dictionary = _player_positions[peer_id]
		pos.q = hex_q
		pos.r = hex_r
	world_scene_changed.emit(peer_id, hex_q, hex_r)


## Broadcast combat start to specific peers with encounter data.
func sync_combat_start(encounter: Dictionary, target_peers: Array[int]) -> void:
	for pid in target_peers:
		_combat_start_rpc.rpc_id(pid, encounter)
	# Also signal locally for the host
	combat_started.emit(encounter, target_peers)


## Notify all peers that host combat was triggered (broadcast version).
func sync_combat_start_all(encounter: Dictionary) -> void:
	_combat_start_rpc.rpc(encounter)
	combat_started.emit(encounter, [])


@rpc("authority", "call_local", "reliable")
func _combat_start_rpc(encounter: Dictionary) -> void:
	combat_started.emit(encounter, [])


## Broadcast rift entry to all peers.
func sync_rift_enter(rift_id: String, biome_key: String, rift_data: Dictionary) -> void:
	_rift_enter_rpc.rpc(rift_id, biome_key, rift_data)


## Send rift entry to specific peers only.
func sync_rift_enter_targeted(rift_id: String, biome_key: String, rift_data: Dictionary, target_peers: Array[int]) -> void:
	for pid in target_peers:
		_rift_enter_rpc.rpc_id(pid, rift_id, biome_key, rift_data)


## Broadcast rift exit to all peers.
func sync_rift_exit() -> void:
	_rift_exit_rpc.rpc()


@rpc("authority", "call_local", "reliable")
func _rift_enter_rpc(rift_id: String, biome_key: String, rift_data: Dictionary) -> void:
	rift_entered.emit(rift_id, biome_key, rift_data)


@rpc("authority", "call_local", "reliable")
func _rift_exit_rpc() -> void:
	rift_exited.emit()


func get_remote_position(peer_id: int) -> Dictionary:
	return _player_positions.get(peer_id, {}).duplicate()


func get_all_remote_positions() -> Dictionary:
	return _player_positions.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"spawned": _spawned_nodes.duplicate(true),
		"owned": _owned_nodes.duplicate(true),
		"next_id": _next_net_id,
	}


func restore_snapshot(snapshot: Dictionary) -> void:
	_spawned_nodes = snapshot.get("spawned", {}).duplicate(true)
	_owned_nodes = snapshot.get("owned", {}).duplicate(true)
	_next_net_id = snapshot.get("next_id", _next_net_id)
