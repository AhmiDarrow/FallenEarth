## TradeManager — Player-to-player item trading (server-authoritative)
extends Node

signal trade_request_received(from_peer_id: int, from_name: String)
signal trade_request_cancelled(from_peer_id: int)
signal trade_started(partner_id: int, partner_name: String)
signal trade_updated(my_items: Array, partner_items: Array)
signal trade_confirmed(peer_id: int)
signal trade_completed()
signal trade_cancelled(reason: String)

var active_trade_partner: int = -1
# Server-side trade mapping: peer_id -> partner_id (authoritative)
var _server_trade_pairs: Dictionary = {}
var _my_items: Array[Dictionary] = []
var _partner_items: Array[Dictionary] = []
var _my_ready: bool = false
var _partner_ready: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func is_trading() -> bool:
	return active_trade_partner >= 0


# ----- Trade request flow -----

func send_trade_request(target_peer_id: int) -> bool:
	if is_trading():
		return false
	_trade_request_rpc.rpc_id(target_peer_id, multiplayer.get_unique_id(), _get_my_name())
	return true


func accept_trade(from_peer_id: int) -> void:
	_trade_accept_rpc.rpc_id(from_peer_id, multiplayer.get_unique_id(), _get_my_name())


func decline_trade(from_peer_id: int) -> void:
	_trade_decline_rpc.rpc_id(from_peer_id, multiplayer.get_unique_id())


# ----- Trade actions -----

func add_item(item_id: String, qty: int) -> void:
	if not is_trading():
		return
	# Validate we have the item
	var im: Node = get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("has_item"):
		return
	if not im.has_item(item_id, qty):
		return
	# Add to our offer
	for existing in _my_items:
		if existing.get("item_id") == item_id:
			existing["qty"] = existing.get("qty", 0) + qty
			_sync_trade_state()
			return
	_my_items.append({"item_id": item_id, "qty": qty})
	_sync_trade_state()


func remove_offer_item(index: int) -> void:
	if not is_trading() or index < 0 or index >= _my_items.size():
		return
	_my_items.remove_at(index)
	_my_ready = false
	_sync_trade_state()


func confirm_trade() -> void:
	if not is_trading() or _my_items.is_empty():
		return
	_my_ready = true
	_trade_confirm_rpc.rpc_id(active_trade_partner)
	_sync_trade_state()
	_check_both_ready()


func cancel_trade() -> void:
	if not is_trading():
		return
	_trade_cancel_rpc.rpc_id(active_trade_partner, "cancelled")
	_clear_trade()


# ----- RPCs -----

@rpc("any_peer", "call_local", "reliable")
func _trade_request_rpc(from_peer_id: int, from_name: String) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != from_peer_id:
		return
	if is_trading():
		return
	trade_request_received.emit(from_peer_id, from_name)


@rpc("any_peer", "call_local", "reliable")
func _trade_accept_rpc(accepter_id: int, accepter_name: String) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != accepter_id:
		return
	active_trade_partner = accepter_id
	_my_items.clear()
	_partner_items.clear()
	_my_ready = false
	_partner_ready = false
	if multiplayer.is_server():
		_server_trade_pairs[caller] = accepter_id
		_server_trade_pairs[accepter_id] = caller
	trade_started.emit(accepter_id, accepter_name)


@rpc("any_peer", "call_local", "reliable")
func _trade_decline_rpc(decliner_id: int) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != decliner_id:
		return
	trade_request_cancelled.emit(decliner_id)


@rpc("any_peer", "call_local", "reliable")
func _trade_update_rpc(items_data: Array) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != active_trade_partner:
		return
	_partner_items = items_data.duplicate()
	trade_updated.emit(_my_items, _partner_items)


@rpc("any_peer", "call_local", "reliable")
func _trade_confirm_rpc() -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != active_trade_partner:
		return
	_partner_ready = true
	trade_confirmed.emit(caller)


@rpc("any_peer", "call_local", "reliable")
func _trade_cancel_rpc(reason: String) -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller != active_trade_partner and caller != 0:
		return
	_clear_trade()
	trade_cancelled.emit(reason)


@rpc("any_peer", "call_local", "reliable")
func _trade_execute_rpc(trade_data: Dictionary) -> void:
	# Server-authoritative execution (host validates + transfers)
	if not multiplayer.is_server():
		return
	var caller := multiplayer.get_remote_sender_id()
	if caller == 0:
		return
	var from_items: Array = trade_data.get("from_items", [])
	var to_items: Array = trade_data.get("to_items", [])
	var im: Node = get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("add_item") or not im.has_method("remove_item"):
		return
	# Validate caller actually has the items they're trading
	for item in from_items:
		if not im.has_item(item.get("item_id", ""), item.get("qty", 1)):
			_trade_cancel_rpc.rpc_id(caller, "validation failed")
			return
	# Remove from caller's inventory on server
	for item in from_items:
		im.remove_item(item.get("item_id", ""), item.get("qty", 1))
	# Add to caller's inventory (from partner)
	for item in to_items:
		im.add_item(item.get("item_id", ""), item.get("qty", 1))
	# Server-side partner lookup — never trust client-provided partner_id
	var partner_id := _get_trade_partner(caller)
	if partner_id < 0:
		return
	# Remove partner's offered items from partner's inventory
	_trade_remove_items_rpc.rpc_id(partner_id, to_items)
	# Give partner the caller's items
	_trade_receive_items_rpc.rpc_id(partner_id, trade_data.get("from_items", []))
	_trade_complete_rpc.rpc_id(caller)
	_trade_complete_rpc.rpc_id(partner_id)


@rpc("authority", "call_local", "reliable")
func _trade_receive_items_rpc(items: Array) -> void:
	var im: Node = get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("add_item"):
		return
	for item in items:
		im.add_item(item.get("item_id", ""), item.get("qty", 1))


@rpc("authority", "reliable")
func _trade_remove_items_rpc(items: Array) -> void:
	var im: Node = get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("remove_item"):
		return
	for item in items:
		im.remove_item(item.get("item_id", ""), item.get("qty", 1))


@rpc("authority", "call_local", "reliable")
func _trade_complete_rpc() -> void:
	_clear_trade()
	trade_completed.emit()


# ----- Internal -----

func _sync_trade_state() -> void:
	if active_trade_partner < 0:
		return
	_trade_update_rpc.rpc_id(active_trade_partner, _my_items.duplicate())
	trade_updated.emit(_my_items, _partner_items)


func _check_both_ready() -> void:
	if not _my_ready or not _partner_ready:
		return
	# Both confirmed — execute trade on server
	if multiplayer.is_server():
		_execute_trade()
	else:
		# Client: send execution request to server (host)
		var trade_data := {
			"from_items": _my_items.duplicate(),
			"to_items": _partner_items.duplicate(),
			"partner_id": active_trade_partner,
		}
		_trade_execute_rpc.rpc_id(1, trade_data)


func _execute_trade() -> void:
	var im: Node = get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("add_item") or not im.has_method("remove_item"):
		return
	# Validate we have all items before executing
	for item in _my_items:
		if not im.has_item(item.get("item_id", ""), item.get("qty", 1)):
			push_warning("[TradeManager] Missing item %s x%d — cancelling trade" % [item.get("item_id", ""), item.get("qty", 1)])
			_clear_trade()
			trade_cancelled.emit("missing items")
			return
	# Remove my offered items
	for item in _my_items:
		im.remove_item(item.get("item_id", ""), item.get("qty", 1))
	# Give me partner's items
	for item in _partner_items:
		im.add_item(item.get("item_id", ""), item.get("qty", 1))
	# Remove partner's offered items on partner's machine, then send mine
	_trade_remove_items_rpc.rpc_id(active_trade_partner, _partner_items)
	_trade_receive_items_rpc.rpc_id(active_trade_partner, _my_items)
	_trade_complete_rpc.rpc()
	trade_completed.emit()
	_clear_trade()


func _clear_trade() -> void:
	var old_partner := active_trade_partner
	active_trade_partner = -1
	_my_items.clear()
	_partner_items.clear()
	_my_ready = false
	_partner_ready = false
	if multiplayer.is_server() and old_partner >= 0:
		_server_trade_pairs.erase(old_partner)
		_server_trade_pairs.erase(multiplayer.get_unique_id())


func _get_my_name() -> String:
	var my_id := multiplayer.get_unique_id()
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm != null and nm.has_method("get_player_name"):
		return nm.get_player_name(my_id)
	return "Player_%d" % my_id


func _get_trade_partner(caller_id: int) -> int:
	if multiplayer.is_server():
		return _server_trade_pairs.get(caller_id, -1)
	return active_trade_partner
