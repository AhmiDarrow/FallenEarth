## EventBus — Global signal bus with before/after hooks for mod interception.
##
## Autoload #3 — re-emits all game signals through a unified event system.
## Mods can register before-hooks (can modify/cancel) and after-hooks (reactive).
extends Node

# -- Internal hook storage --
# event_name -> {before: [{priority, callback, hook_id}], after: [{priority, callback, hook_id}]}
var _hooks: Dictionary = {}
var _hook_counter: int = 0
var _cancelled: bool = false
var _current_event: String = ""


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_connect_game_signals()


# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

## Emit an event with before/after hooks. Returns the (possibly modified) data.
## If a before-hook calls cancel(), returns null.
func emit(event_name: String, data: Dictionary = {}) -> Variant:
	_current_event = event_name
	_cancelled = false
	# Run before-hooks (sorted by priority, lower first)
	var before_hooks: Array = _hooks.get(event_name, {}).get("before", [])
	before_hooks.sort_custom(func(a, b): return a.priority < b.priority)
	for hook in before_hooks:
		if _cancelled:
			break
		var callback: Callable = hook.callback
		if callback.is_valid():
			var result = callback.call(event_name, data)
			if result is Dictionary:
				data = result
	if _cancelled:
		return null
	# Run after-hooks
	var after_hooks: Array = _hooks.get(event_name, {}).get("after", [])
	after_hooks.sort_custom(func(a, b): return a.priority < b.priority)
	for hook in after_hooks:
		if not _cancelled:
			var callback: Callable = hook.callback
			if callback.is_valid():
				callback.call(event_name, data)
	return data


## Register a before-hook. Lower priority runs first. Returns hook_id.
func before(event_name: String, callback: Callable, priority: int = 100) -> String:
	_hook_counter += 1
	var hook_id := "bh_%d_%s" % [_hook_counter, event_name]
	if not _hooks.has(event_name):
		_hooks[event_name] = {"before": [], "after": []}
	_hooks[event_name]["before"].append({
		"priority": priority,
		"callback": callback,
		"hook_id": hook_id,
	})
	return hook_id


## Register an after-hook. Lower priority runs first. Returns hook_id.
func after(event_name: String, callback: Callable, priority: int = 100) -> String:
	_hook_counter += 1
	var hook_id := "ah_%d_%s" % [_hook_counter, event_name]
	if not _hooks.has(event_name):
		_hooks[event_name] = {"before": [], "after": []}
	_hooks[event_name]["after"].append({
		"priority": priority,
		"callback": callback,
		"hook_id": hook_id,
	})
	return hook_id


## Remove a hook by its ID.
func remove_hook(hook_id: String) -> void:
	for event_name in _hooks:
		for hook_type in ["before", "after"]:
			var hooks: Array = _hooks[event_name][hook_type]
			for i in range(hooks.size() - 1, -1, -1):
				if hooks[i].hook_id == hook_id:
					hooks.remove_at(i)
					return


## Cancel the current event (only works inside before-hooks).
func cancel() -> void:
	_cancelled = true


## Check if the current event was cancelled.
func is_cancelled() -> bool:
	return _cancelled


# ---------------------------------------------------------------------------
# Game signal connections (re-emit through EventBus)
# ---------------------------------------------------------------------------

func _connect_game_signals() -> void:
	_connect_signal_if_exists("/root/GameState", "character_created",
		func(cid, rid, cid2, orig): emit("character_created", {"character_id": cid, "race_id": rid, "class_id": cid2, "origin": orig}))
	_connect_signal_if_exists("/root/GameState", "game_saved",
		func(slot_id): emit("game_saved", {"slot_id": slot_id}))
	_connect_signal_if_exists("/root/GameState", "game_loaded",
		func(slot_id, save_data): emit("game_loaded", {"slot_id": slot_id, "save_data": save_data}))
	_connect_signal_if_exists("/root/GameState", "active_scene_changed",
		func(scene_name): emit("active_scene_changed", {"scene_name": scene_name}))
	_connect_signal_if_exists("/root/GameState", "class_level_up",
		func(new_level, levels_gained): emit("level_up", {"new_level": new_level, "levels_gained": levels_gained}))
	_connect_signal_if_exists("/root/GameState", "class_xp_gained",
		func(amount, total_xp): emit("xp_gained", {"amount": amount, "total_xp": total_xp}))

	_connect_signal_if_exists("/root/InventoryHandler", "inventory_changed",
		func(): emit("inventory_changed", {}))
	# InventoryHandler no longer emits item_added / item_full — use inventory_changed

	_connect_signal_if_exists("/root/ProgressionManager", "xp_changed",
		func(current_xp, xp_to_next): emit("xp_changed", {"current_xp": current_xp, "xp_to_next": xp_to_next}))
	_connect_signal_if_exists("/root/ProgressionManager", "level_up",
		func(new_level, levels_gained): emit("level_up", {"new_level": new_level, "levels_gained": levels_gained}))
	_connect_signal_if_exists("/root/ProgressionManager", "ec_changed",
		func(current_ec): emit("ec_changed", {"current_ec": current_ec}))

	_connect_signal_if_exists("/root/MissionManager", "mission_offered",
		func(mission_id, data): emit("mission_offered", {"mission_id": mission_id, "data": data}))
	_connect_signal_if_exists("/root/MissionManager", "mission_accepted",
		func(mission_id): emit("mission_accepted", {"mission_id": mission_id}))
	_connect_signal_if_exists("/root/MissionManager", "mission_completed",
		func(mission_id, rewards): emit("mission_completed", {"mission_id": mission_id, "rewards": rewards}))
	_connect_signal_if_exists("/root/MissionManager", "mission_failed",
		func(mission_id): emit("mission_failed", {"mission_id": mission_id}))

	_connect_signal_if_exists("/root/RiftRunner", "rift_entered",
		func(rift_id, biome_key): emit("rift_entered", {"rift_id": rift_id, "biome_key": biome_key}))
	_connect_signal_if_exists("/root/RiftRunner", "rift_cleared",
		func(rift_id, loot): emit("rift_cleared", {"rift_id": rift_id, "loot": loot}))
	_connect_signal_if_exists("/root/RiftRunner", "rift_collapsed",
		func(rift_id): emit("rift_collapsed", {"rift_id": rift_id}))

	_connect_signal_if_exists("/root/NPCManager", "npc_recruited",
		func(npc_id, npc_data): emit("npc_recruited", {"npc_id": npc_id, "npc_data": npc_data}))
	_connect_signal_if_exists("/root/NPCManager", "faction_rep_changed",
		func(faction_key, old_rep, new_rep): emit("faction_rep_changed", {"faction_key": faction_key, "old_rep": old_rep, "new_rep": new_rep}))

	_connect_signal_if_exists("/root/PartyNPCManager", "npc_dismissed",
		func(npc_id): emit("npc_dismissed", {"npc_id": npc_id}))
	_connect_signal_if_exists("/root/PartyNPCManager", "party_changed",
		func(): emit("party_changed", {}))

	_connect_signal_if_exists("/root/EquipmentManager", "equipment_changed",
		func(npc_id, slot): emit("equipment_changed", {"npc_id": npc_id, "slot": slot}))
	_connect_signal_if_exists("/root/EquipmentManager", "main_hand_changed",
		func(npc_id, item_id): emit("main_hand_changed", {"npc_id": npc_id, "item_id": item_id}))

	_connect_signal_if_exists("/root/CraftingManager", "recipe_unlocked",
		func(recipe_id): emit("recipe_unlocked", {"recipe_id": recipe_id}))
	_connect_signal_if_exists("/root/CraftingManager", "recipe_crafted",
		func(recipe_id, result_items): emit("recipe_crafted", {"recipe_id": recipe_id, "result_items": result_items}))

	_connect_signal_if_exists("/root/BaseManager", "base_placed",
		func(hex_key, local_x, local_y): emit("base_placed", {"hex_key": hex_key, "local_x": local_x, "local_y": local_y}))
	_connect_signal_if_exists("/root/BaseManager", "base_upgraded",
		func(new_level): emit("base_upgraded", {"new_level": new_level}))
	_connect_signal_if_exists("/root/BaseManager", "resident_added",
		func(npc_id): emit("resident_added", {"npc_id": npc_id}))
	_connect_signal_if_exists("/root/BaseManager", "resident_removed",
		func(npc_id): emit("resident_removed", {"npc_id": npc_id}))
	_connect_signal_if_exists("/root/BaseManager", "settlement_named",
		func(name): emit("settlement_named", {"name": name}))

	_connect_signal_if_exists("/root/BaseShopManager", "shop_opened",
		func(shop_type, npc_id): emit("shop_opened", {"shop_type": shop_type, "npc_id": npc_id}))
	_connect_signal_if_exists("/root/BaseShopManager", "shop_closed",
		func(shop_type, npc_id): emit("shop_closed", {"shop_type": shop_type, "npc_id": npc_id}))

	_connect_signal_if_exists("/root/TamedMobManager", "tamed_mob_added",
		func(mob_data): emit("tamed_mob_added", {"mob_data": mob_data}))
	_connect_signal_if_exists("/root/TamedMobManager", "tamed_mob_removed",
		func(mob_id): emit("tamed_mob_removed", {"mob_id": mob_id}))
	_connect_signal_if_exists("/root/TamedMobManager", "mount_changed",
		func(mob_id): emit("mount_changed", {"mob_id": mob_id}))

	_connect_signal_if_exists("/root/RespawnManager", "player_respawning",
		func(respawn_data): emit("player_respawning", {"respawn_data": respawn_data}))

	_connect_signal_if_exists("/root/ChatManager", "message_received",
		func(sender_id, sender_name, channel, text): emit("message_received", {"sender_id": sender_id, "sender_name": sender_name, "channel": channel, "text": text}))

	_connect_signal_if_exists("/root/LobbyManager", "lobby_created",
		func(lobby_id): emit("lobby_created", {"lobby_id": lobby_id}))
	_connect_signal_if_exists("/root/LobbyManager", "lobby_joined",
		func(lobby_id): emit("lobby_joined", {"lobby_id": lobby_id}))
	_connect_signal_if_exists("/root/LobbyManager", "lobby_closed",
		func(): emit("lobby_closed", {}))
	_connect_signal_if_exists("/root/LobbyManager", "player_joined_lobby",
		func(peer_id, name): emit("player_joined_lobby", {"peer_id": peer_id, "name": name}))
	_connect_signal_if_exists("/root/LobbyManager", "player_left_lobby",
		func(peer_id): emit("player_left_lobby", {"peer_id": peer_id}))

	_connect_signal_if_exists("/root/PlayerPartyManager", "party_invite_received",
		func(from_peer_id, from_name): emit("party_invite_received", {"from_peer_id": from_peer_id, "from_name": from_name}))
	_connect_signal_if_exists("/root/PlayerPartyManager", "party_joined",
		func(leader_peer_id, members): emit("party_joined", {"leader_peer_id": leader_peer_id, "members": members}))
	_connect_signal_if_exists("/root/PlayerPartyManager", "party_left",
		func(): emit("party_left", {}))
	_connect_signal_if_exists("/root/PlayerPartyManager", "party_member_joined",
		func(peer_id, name): emit("party_member_joined", {"peer_id": peer_id, "name": name}))
	_connect_signal_if_exists("/root/PlayerPartyManager", "party_member_left",
		func(peer_id): emit("party_member_left", {"peer_id": peer_id}))

	_connect_signal_if_exists("/root/GameManager", "scene_changed",
		func(scene_path): emit("scene_changed", {"scene_path": scene_path}))

	print("[EventBus] Connected to game signals")


func _connect_signal_if_exists(node_path: String, signal_name: String, callback: Callable) -> void:
	var node := get_node_or_null(node_path)
	if node == null:
		return
	if not node.has_signal(signal_name):
		return
	node.connect(signal_name, callback)
