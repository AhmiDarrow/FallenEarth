class_name OverworldRiftManager extends Node

signal rift_proceed(rift: Dictionary)
signal world_map_pressed()
signal markers_dirty()
signal local_view_needs_build()

var rift_runner: Node
var rift_info_label: RichTextLabel
var gm: GameManager
var gs: GameState
var transition_screen: CanvasLayer
var ui_parent: CanvasLayer
var is_multiplayer: bool = false
var net_sync: Node
var tile_map: Dictionary = {}
var local_map: Dictionary = {}
var player_q: int = 0
var player_r: int = 0
var local_x: int = 256
var local_y: int = 256
var game_time: float = 0.0
var party_pull_callback: Callable


func tick_rifts() -> void:
	if not is_instance_valid(rift_runner):
		return
	if rift_runner.has_method("prune_expired_rifts"):
		rift_runner.prune_expired_rifts(game_time)

	if rift_runner.has_method("try_spawn_local_rift"):
		var tile: Dictionary = tile_map.get("%d,%d" % [player_q, player_r], {})
		var spawned: Dictionary = rift_runner.try_spawn_local_rift(
			player_q, player_r, str(tile.get("name", "Ash Wastes")), local_map, game_time
		)
		if not spawned.is_empty():
			markers_dirty.emit()

	local_view_needs_build.emit()
	update_rift_ui()


func spawn_initial_rift_if_needed() -> void:
	if not is_instance_valid(rift_runner):
		return
	if rift_runner.has_method("get_rifts_in_hex"):
		var existing: Array = rift_runner.get_rifts_in_hex(player_q, player_r, game_time)
		if not existing.is_empty():
			return
	var tile: Dictionary = tile_map.get("%d,%d" % [player_q, player_r], {})
	if rift_runner.has_method("add_rift_entrance"):
		var rng := RandomNumberGenerator.new()
		var seed_for_rift: String = str(gs.get_world_data().get("seed", "start")) if is_instance_valid(gs) else "start"
		rng.seed = hash(seed_for_rift) + player_q * 1000 + player_r
		var lx2 := rng.randi_range(local_x + 4, local_x + 12)
		var ly2 := rng.randi_range(local_y - 5, local_y + 5)
		lx2 = clampi(lx2, 4, Constants.MAP_SIZE - 4)
		ly2 = clampi(ly2, 4, Constants.MAP_SIZE - 4)
		rift_runner.add_rift_entrance(
			player_q, player_r,
			str(tile.get("name", "Ash Wastes")),
			600.0, "", null, lx2, ly2
		)
		# Place a second test rift right next to spawn for quick testing.
		rift_runner.add_rift_entrance(
			player_q, player_r,
			str(tile.get("name", "Ash Wastes")),
			600.0, "", null,
			clampi(local_x + 2, 4, Constants.MAP_SIZE - 4),
			clampi(local_y, 4, Constants.MAP_SIZE - 4)
		)
	local_view_needs_build.emit()
	update_rift_ui()


func get_rift_at_player() -> Dictionary:
	if not is_instance_valid(rift_runner) or not rift_runner.has_method("get_rift_at_local"):
		return {}
	return rift_runner.get_rift_at_local(player_q, player_r, local_x, local_y, game_time)


func update_rift_ui() -> void:
	# v0.4.0 polish: rift info no longer writes to a dedicated
	# TileInfoPanel label (the OLD scene tree was removed). The hub
	# HUD's HoverTooltip + tile info region already show nearby-rift
	# counts via _update_tile_info; this method now just exposes the
	# state for callers that need it without dead UI writes.
	var rift: Dictionary = get_rift_at_player()
	var on_rift := not rift.is_empty()
	if on_rift:
		var remaining: float = float(rift.get("duration", 0.0)) - (game_time - float(rift.get("spawn_time", 0.0)))
		# Emit a transient toast through the hub's HUD notification
		# helper if it's available. Otherwise, no-op.
		var manager: Node = _find_overworld_hud_manager()
		if manager != null and manager.has_method("_show_notification"):
			manager.call("_show_notification",
				"⚡ Rift tunnel ACTIVE — ~%d min left. Press F to enter." %
				maxi(0, int(remaining / 60.0)))


func open_rift_entry_ui() -> void:
	if not is_instance_valid(ui_parent):
		return
	if ui_parent.has_node("RiftEntryUI"):
		return
	var rift: Dictionary = get_rift_at_player()
	if rift.is_empty():
		return
	rift["entry_q"] = player_q
	rift["entry_r"] = player_r
	rift["entry_local_x"] = local_x
	rift["entry_local_y"] = local_y

	var ui_script: GDScript = load("res://scripts/ui/RiftEntryUI.gd")
	if ui_script == null:
		return
	var ui: Control = ui_script.new()
	ui.name = "RiftEntryUI"
	ui.setup(rift)
	ui.proceed_requested.connect(_on_rift_proceed)
	ui.cancelled.connect(func(): if is_instance_valid(ui): ui.queue_free())
	ui_parent.add_child(ui)


func _on_rift_proceed(rift: Dictionary) -> void:
	var rift_id: String = str(rift.get("rift_id", "rift_0001"))
	var biome: String = str(rift.get("biome_key", "Ash Wastes"))
	rift_proceed.emit(rift)

	if is_multiplayer and multiplayer.is_server() and net_sync != null and net_sync.has_method("sync_rift_enter"):
		net_sync.sync_rift_enter(rift_id, biome, rift)
		if party_pull_callback.is_valid():
			party_pull_callback.call(rift_id, biome, rift)

	if is_instance_valid(gm):
		if is_instance_valid(transition_screen):
			await transition_screen.fade_out(0.4)
		gm.go_to_rift(rift_id, biome, rift)


func open_world_map() -> void:
	if is_instance_valid(gm):
		if is_instance_valid(transition_screen):
			await transition_screen.fade_out(0.4)
		gm.go_to_world_map()


## Locate OverworldHUDManager in the tree (set by HubWorld when this
## manager is constructed). Returns null when not present.
func _find_overworld_hud_manager() -> Node:
	if ui_parent == null:
		return null
	var node := ui_parent.find_child("HUDManager", true, false)
	return node
