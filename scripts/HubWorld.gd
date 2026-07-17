## HubWorld — Local 512×512 playfield for the current sphere hex region.
## Walk the local map; cross edges to adjacent hex regions; open World Map for strategic travel.
class_name HubWorld extends Node2D

signal enter_rift_requested(rift_id: String)
signal back_to_menu_requested()

const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")
const MobSpawnerScript = preload("res://scripts/mob/MobSpawner.gd")
const MobManagerScript = preload("res://scripts/mob/OverworldMobManager.gd")
const MobPoolScript = preload("res://scripts/mob/OverworldMobPool.gd")
const MobInstanceScript = preload("res://scripts/mob/MobInstance.gd")
const MobDataScript = preload("res://scripts/mob/MobData.gd")
const CharacterVisualScript = preload("res://scripts/CharacterVisual.gd")
const InventoryMgrScript = preload("res://scripts/InventoryManager.gd")
const ProgressionMgrScript = preload("res://scripts/ProgressionManager.gd")
const HoverTooltipScript = preload("res://scripts/HoverTooltip.gd")
const LootRollerScript = preload("res://scripts/LootRoller.gd")
const HUDScript = preload("res://scripts/ui/HUD.gd")
const CharacterMenuScript = preload("res://scripts/ui/CharacterMenu.gd")
const BaseMgrScript = preload("res://scripts/BaseManager.gd")
const BaseNodeScene = preload("res://scenes/BaseNode.tscn")
const BaseScene = preload("res://scenes/Base.tscn")
const LootPopupScript = preload("res://scripts/ui/LootPopup.gd")
const LootPopupScene = preload("res://scenes/ui/LootPopup.tscn")
const SettlementMgrScript = preload("res://scripts/SettlementManager.gd")
const TransitionScreenScene = preload("res://scenes/TransitionScreen.tscn")
const EntityVisualComponentScript = preload("res://scripts/procedural/EntityVisualComponent.gd")

const RIFT_CHECK_INTERVAL := 30.0
const GATHER_RANGE_CELLS := 1  # adjacent cells; player can gather from 1 tile away

@onready var char_label: RichTextLabel = get_node_or_null("UI_Canvas/CharInfoBar/CharLabel") as RichTextLabel
@onready var tile_info_label: RichTextLabel = get_node_or_null("UI_Canvas/TileInfoPanel/TileInfoLabel") as RichTextLabel
@onready var rift_info_label: RichTextLabel = get_node_or_null("UI_Canvas/TileInfoPanel/RiftInfoLabel") as RichTextLabel
@onready var world_grid: Node2D = $World as Node2D
@onready var camera: Camera2D = $World/Camera2D as Camera2D

var _world_gen: WorldGenerator = null
var _tile_map: Dictionary = {}
var _local_map: Dictionary = {}
var _player_q: int = 0
var _player_r: int = 0
var _local_x: int = 256
var _local_y: int = 256
var _map_view: Node2D = null
var _marker_layer: Node2D = null
var _mob_layer: Node2D = null
var _mob_sprite_layer: Node2D = null
var _node_layer: Node2D = null
var _pickup_layer: Node2D = null
var _marker_nodes: Dictionary = {}

# Phase 1 gather state. _gathering_node is set when the player presses E
# adjacent to a HarvestNode; the timer counts down to 0, then the yield
# is awarded to InventoryManager. _gathering_node is null when idle.
var _gathering_node: Node2D = null
var _gather_timer: float = 0.0
var _gather_total: float = 0.0
var _gather_yield_preview: Dictionary = {}

# v0.9.1c: small list of HarvestNodes currently respawning. Each frame
# we only tick THIS list, not all 16k+ resource nodes. Most nodes are
# not depleted, so iterating them is pure overhead. When a node depletes
# (in _tick_gather), it's added here; when respawn completes in
# HarvestNode._process, we remove it via the deferred_remove callback.
var _active_respawn_nodes: Array[Node2D] = []

# v0.9.1c: dirty flag for marker/mob refresh. Mobs and rifts change
# infrequently (rifts spawn on a 30s timer, mobs change on combat/seed).
# Walking the player doesn't change any of them, so we skip the full
# rebuild on every move. This alone takes per-move from ~25ms to ~1ms.
var _world_markers_dirty: bool = true

# Track which hexes have had mobs seeded so killed mobs aren't re-seeded
# when HubWorld reloads (deterministic RNG would place them again).
var _seeded_hexes: Dictionary = {}
## Cached KeybindManager autoload (looked up once, reused per keypress).
var _keybind_mgr: Node = null

# Currently equipped MainHand tool (Phase 1 placeholder until
# EquipmentManager lands in Phase 4). Empty dict = no tool.
var _equipped_tool: Dictionary = {}

# Phase 2: full in-game HUD (top bar, HP/MP/XP bars, minimap, hotbar).
var _hud: Control = null

# Phase 3: settlement enter / exit

# Phase 6: base (player-chosen placement, upgrades, leave-base)
var _base_node: Node2D = null
var _base_interior: Control = null

# v0.6.0: currently-open CookingTableUI (null when not open).
var _cooking_table_ui: Control = null
var _rift_runner: Node = null
var _rift_manager: OverworldRiftManager = null
var _map_manager: OverworldMapManager = null
var _player_manager: OverworldPlayerManager = null
var _interaction_manager: OverworldInteractionManager = null
var _hud_manager: OverworldHUDManager = null
var _npc_manager_ui: OverworldNPCManager = null
var _pending_char_data: Dictionary = {}
var _network_manager: OverworldNetworkManager = null
var _game_time: float = 0.0
var _rift_check_timer: float = 0.0
var _npc_manager: Node = null
var _mission_manager: Node = null
var _player_visual: Node2D = null
var _transition_screen: CanvasLayer = null

# Multiplayer: remote player avatars on this hex
var _remote_players: Dictionary = {}  # peer_id -> RemotePlayer node
var _is_multiplayer: bool = false  # synced from GameState.is_multiplayer
var _net_sync: Node = null

# Cached autoload references (populated in _ready)
var _gs: GameState = null
var _em: EquipmentManager = null
var _gm: GameManager = null
var _inv: Node = null
var _sm: Node = null
var _ppm: Node = null

# v0.10.1: Mob AI managed by OverworldMobManager child node.
var _mob_manager: OverworldMobManager = null
var _mob_pool: OverworldMobPool = null
var _mobs_container: Node2D = null

# Guard against multiple combat initiations in the same frame
var _combat_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_gs = get_node_or_null("/root/GameState") as GameState
	_em = get_node_or_null("/root/EquipmentManager") as EquipmentManager
	_gm = get_node_or_null("/root/GameManager") as GameManager
	_inv = get_node_or_null("/root/InventoryManager")
	_sm = get_node_or_null("/root/SettlementManager")
	_ppm = get_node_or_null("/root/PlayerPartyManager")

	_rift_runner = get_node_or_null("/root/RiftRunner")
	_npc_manager = get_node_or_null("/root/NPCManager")
	_mission_manager = get_node_or_null("/root/MissionManager")

	_rift_manager = OverworldRiftManager.new()
	_rift_manager.name = "RiftManager"
	_rift_manager.rift_runner = _rift_runner
	_rift_manager.rift_info_label = rift_info_label
	_rift_manager.gm = _gm
	_rift_manager.gs = _gs
	_rift_manager.transition_screen = _transition_screen if _transition_screen else null
	_rift_manager.ui_parent = get_node_or_null("UI_Canvas") as CanvasLayer
	_rift_manager.is_multiplayer = _gs.is_multiplayer if is_instance_valid(_gs) else false
	_rift_manager.net_sync = _net_sync
	_rift_manager.tile_map = _tile_map
	_rift_manager.local_map = _local_map
	_rift_manager.party_pull_callback = func(rid: String, biome: String, rift: Dictionary): if _network_manager: _network_manager._pull_party_into_rift(rid, biome, rift)
	_rift_manager.rift_proceed.connect(func(rift: Dictionary): enter_rift_requested.emit(rift.get("rift_id", "")))
	add_child(_rift_manager)

	_map_manager = OverworldMapManager.new()
	_map_manager.name = "MapManager"
	_map_manager._hw = self
	_rift_manager.markers_dirty.connect(_map_manager._mark_world_markers_dirty)
	_rift_manager.local_view_needs_build.connect(_map_manager._build_local_view)
	add_child(_map_manager)

	_player_manager = OverworldPlayerManager.new()
	_player_manager.name = "PlayerManager"
	_player_manager._hw = self
	add_child(_player_manager)

	_interaction_manager = OverworldInteractionManager.new()
	_interaction_manager.name = "InteractionManager"
	_interaction_manager._hw = self
	add_child(_interaction_manager)

	_hud_manager = OverworldHUDManager.new()
	_hud_manager.name = "HUDManager"
	_hud_manager._hw = self
	add_child(_hud_manager)

	_npc_manager_ui = OverworldNPCManager.new()
	_npc_manager_ui.name = "NPCManager"
	_npc_manager_ui._hw = self
	add_child(_npc_manager_ui)

	_network_manager = OverworldNetworkManager.new()
	_network_manager.name = "NetworkManager"
	_network_manager._hw = self
	add_child(_network_manager)

	_world_gen = WorldGenerator.new()
	add_child(_world_gen)

	# Wire SettlementManager's left_settlement to HubWorld's
	# _leave_settlement so when the Settlement interior calls
	# leave_settlement(), the world view comes back.
	if _sm != null and not _sm.is_connected("left_settlement", _interaction_manager._leave_settlement):
		_sm.connect("left_settlement", _interaction_manager._leave_settlement)

	_npc_manager_ui._setup_npc_ui()
	_npc_manager_ui._setup_mission_ui()

	# Phase F: Transition screen for fade effects
	if TransitionScreenScene != null:
		_transition_screen = TransitionScreenScene.instantiate()
		add_child(_transition_screen)
		if _rift_manager != null:
			_rift_manager.transition_screen = _transition_screen

	if is_instance_valid(_gs):
		var char_data: Dictionary = _gs.get_party_character_data()
		if not char_data.is_empty():
			_hud_manager._update_char_info(char_data)
		elif not _pending_char_data.is_empty():
			_hud_manager._update_char_info(_pending_char_data)
			_pending_char_data = {}

		_tile_map = _gs.get_tile_map()
		if _tile_map.is_empty() and _gs.has_world():
			var wd: Dictionary = _gs.get_world_data()
			if wd.get("tile_map") is Dictionary:
				_tile_map = wd["tile_map"]

		if not _tile_map.is_empty():
			var seed_str: String = str(_gs.get_world_data().get("seed", ""))
			_world_gen.load_from_tile_map(_tile_map, seed_str)

		var pos: Vector2i = _gs.get_player_position()
		_player_q = pos.x
		_player_r = pos.y
		var local_pos: Vector2i = _gs.get_local_position()
		_local_x = local_pos.x
		_local_y = local_pos.y

		_local_map = _gs.ensure_hex_state(_player_q, _player_r)
		_gs.set_local_position(_local_x, _local_y)

		# Phase 5: procedural joinable-NPC spawn on entering a new hex
		var party_mgr: Node = get_node_or_null("/root/PartyNPCManager")
		if party_mgr != null and party_mgr.has_method("spawn_for_hex"):
			# Skip spawn if this hex was already populated (e.g. from
			# a save, or for a hex the player has visited before).
			# Phase 5 simplification: only spawn if the hex has no
			# joinable NPCs already.
			var has_spawn: bool = false
			for n in party_mgr.available_npcs:
				if str(n.get("spawn_hex", "")) == str(_player_q) + "," + str(_player_r):
					has_spawn = true
					break
			if not has_spawn:
				party_mgr.spawn_for_hex("%d,%d" % [_player_q, _player_r], "")

		var start: Dictionary = _gs.get_start_tile()
		if not start.is_empty():
			_hud_manager._append_start_info(start)

	if not _pending_char_data.is_empty() and is_instance_valid(_hud_manager):
		_hud_manager._update_char_info(_pending_char_data)
		_pending_char_data = {}

	_map_manager._setup_map_view()
	if is_instance_valid(_map_view):
		_map_view.configure(_local_map)
	_restore_sleeping_bag()
	_map_manager._setup_player_visual()
	# Wire equipment changes to update player visual overlay
	if is_instance_valid(_em):
		if not _em.equipment_changed.is_connected(_on_equipment_changed):
			_em.equipment_changed.connect(_on_equipment_changed)
		# Apply current equipment overlay immediately
		if is_instance_valid(_player_visual):
			var equip: Dictionary = _em.get_equipment("player")
			_player_visual.call("update_equipment", equip)
	# Wire mount changes to update player visual
	var tmm := get_node_or_null("/root/TamedMobManager")
	if is_instance_valid(tmm):
		if not tmm.mount_changed.is_connected(_on_mount_changed):
			tmm.mount_changed.connect(_on_mount_changed)
		_update_mount_visual()
	_hud_manager._setup_hover_tooltip()
	_hud_manager._setup_hud()
	_hud_manager._setup_ui_scaling()
	_game_time = 0.0
	_map_manager._build_local_view()
	_hud_manager._update_tile_info()
	_rift_manager.update_rift_ui()
	_npc_manager_ui._update_npc_ui()
	_npc_manager_ui._update_mission_ui()
	_rift_manager.spawn_initial_rift_if_needed()
	_npc_manager_ui._ensure_world_npcs()
	_seed_local_mobs()
	# Diagnostic: confirm mobs were seeded into GameState
	if is_instance_valid(_gs):
		var diag_mobs: Dictionary = _gs.get_overworld_mobs()
		var diag_prefix: String = "%d,%d|" % [_player_q, _player_r]
		var diag_count := 0
		for mk in diag_mobs:
			if str(mk).begins_with(diag_prefix):
				diag_count += 1
		if diag_count > 0:
			pass
	# v0.9.1c: Mobs were just seeded — force marker refresh on the
	# next _build_local_view call.
	_map_manager._mark_world_markers_dirty()
	_map_manager._build_local_view()
	_interaction_manager._save_to_autoslot_if_can()
	# Audio: exploration music + ambient bed for the current biome.
	_start_audio_for_current_region()

	# Multiplayer setup
	_network_manager._setup_multiplayer()
	if _rift_manager != null and _net_sync != null:
		_rift_manager.net_sync = _net_sync






func _process(delta: float) -> void:
	_hud_manager.process_hud(delta)

	_game_time += delta
	_rift_check_timer += delta
	if _rift_check_timer >= RIFT_CHECK_INTERVAL:
		_rift_check_timer = 0.0
		_rift_manager.game_time = _game_time
		_rift_manager.player_q = _player_q
		_rift_manager.player_r = _player_r
		_rift_manager.local_x = _local_x
		_rift_manager.local_y = _local_y
		_rift_manager.tick_rifts()
		_npc_manager_ui._tick_missions()

	# Gather timer ticks down each frame.
	_interaction_manager._tick_gather(delta)

	# HarvestNode respawn timers tick down each frame.
	_interaction_manager._tick_active_respawn_nodes(delta)

	# v0.10.0: Tick overworld mob AI via new MobManager.
	if _mob_manager != null and is_instance_valid(_mob_manager):
		_mob_manager.tick_all(delta, _local_x, _local_y)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return	# Note: we do NOT early-return on `get_tree().paused` here. The
	# character-menu hotkeys (I/E/C/P/S) must work even while the
	# pause menu is open, so the player can flip between inventory
	# and the pause menu without having to dismiss one first. The
	# game-specific input (movement, interact, world map) is gated
	# separately below by `_interaction_manager._is_ui_overlay_open()` and the explicit
	# `get_tree().paused` check in the `Interact` / movement blocks.

	if _keybind_mgr == null:
		_keybind_mgr = get_node_or_null("/root/KeybindManager")
	var km: Node = _keybind_mgr
	if km == null:
		_fallback_unhandled_input(event)
		return

	# Character-menu hotkeys — always allowed (open new or switch tabs)
	# even while the pause menu is open. These don't mutate game state.
	if km.is_action_pressed("inventory", event):
		_hud_manager.open_character_tab("inventory")
		return
	if km.is_action_pressed("equipment", event):
		if not _interaction_manager._has_adjacent_harvest_node():
			_hud_manager.open_character_tab("equipment")
			return
	if km.is_action_pressed("crafting", event):
		_hud_manager.open_character_tab("crafting")
		return
	if km.is_action_pressed("party", event):
		_hud_manager.open_character_tab("party")
		return
	if km.is_action_pressed("jobs", event):
		_hud_manager.open_character_tab("jobs")
		return
	# S is shared between `move_down` and `stats` (see KeybindManager).
	# Per the original Phase 3 design: S only opens the Stats tab when
	# the CharacterMenu is already open — otherwise S is left to fall
	# through to movement below. Same applies to the fallback handler.
	if km.is_action_pressed("stats", event):
		if _hud != null and is_instance_valid(_hud) and _hud.has_method("is_character_menu_open") and _hud.is_character_menu_open():
			_hud_manager.open_character_tab("stats")
			return
		# Menu closed: don't consume the event — let it reach the
		# movement block below so S moves the player south.

	# Chat toggle (Enter key) — focus chat input when multiplayer active
	if _is_multiplayer and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_network_manager._focus_chat_input()
		return

	# Block remaining game input when any UI overlay is open OR the
	# game is paused (e.g. pause menu).
	if _interaction_manager._is_ui_overlay_open() or get_tree().paused:
		return

	# Interact / gather
	if km.is_action_pressed("interact", event) and not event.echo:
		if _sm != null and _sm.is_inside_settlement():
			_interaction_manager._leave_settlement()
			return
		if is_instance_valid(_base_interior):
			_interaction_manager._leave_base()
			return
		var bm_e: Node = get_node_or_null("/root/BaseManager")
		if bm_e != null and bm_e.can_unlock() and bm_e.is_unplaced():
			_interaction_manager._open_base_placement()
			return
		if _interaction_manager._adjacent_cooking_table() != null:
			_interaction_manager._open_cooking_table_ui()
			return
		if _interaction_manager._adjacent_sleeping_bag() != null:
			_interaction_manager._interact_sleeping_bag(_interaction_manager._adjacent_sleeping_bag())
			return
		var adj_bld: Node2D = _interaction_manager._adjacent_building()
		if adj_bld != null:
			_interaction_manager._interact_building(adj_bld)
			return
		if not _rift_manager.get_rift_at_player().is_empty():
			_rift_manager.open_rift_entry_ui()
			return
		if _npc_manager_ui._is_near_npc():
			_npc_manager_ui._open_npc_dialogue()
			return
		if _interaction_manager._place_sleeping_bag():
			return
		_interaction_manager._try_start_gather()
		return

	# World map
	if km.is_action_pressed("world_map", event):
		_rift_manager.open_world_map()
		return

	# Movement
	var dir := Vector2i.ZERO
	if km.is_action_pressed("move_up", event):
		dir = Vector2i(0, -1)
	elif km.is_action_pressed("move_down", event):
		dir = Vector2i(0, 1)
	elif km.is_action_pressed("move_left", event):
		dir = Vector2i(-1, 0)
	elif km.is_action_pressed("move_right", event):
		dir = Vector2i(1, 0)

	if dir != Vector2i.ZERO:
		_player_manager._try_move_local(dir.x, dir.y)


## Fallback when KeybindManager is not available (uses hardcoded defaults).
func _fallback_unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	# Character-menu hotkeys — always allowed even while paused
	match event.keycode:
		KEY_I:
			_hud_manager.open_character_tab("inventory")
			return
		KEY_E:
			if not _interaction_manager._has_adjacent_harvest_node():
				_hud_manager.open_character_tab("equipment")
				return
		KEY_C:
			_hud_manager.open_character_tab("crafting")
			return
		KEY_P:
			_hud_manager.open_character_tab("party")
			return
		KEY_J:
			_hud_manager.open_character_tab("jobs")
			return
		KEY_S:
			# S is shared with movement. Only open Stats when the
			# CharacterMenu is already open; otherwise let S fall
			# through to the movement block below.
			if _hud != null and is_instance_valid(_hud) and _hud.has_method("is_character_menu_open") and _hud.is_character_menu_open():
				_hud_manager.open_character_tab("stats")
				return
	# Block remaining game input when any UI overlay is open OR the
	# game is paused (e.g. pause menu).
	if _interaction_manager._is_ui_overlay_open() or get_tree().paused:
		return
	match event.keycode:
		KEY_M:
			_rift_manager.open_world_map()
		KEY_UP, KEY_W:
			_player_manager._try_move_local(0, -1)
		KEY_DOWN, KEY_S:
			_player_manager._try_move_local(0, 1)
		KEY_LEFT, KEY_A:
			_player_manager._try_move_local(-1, 0)
		KEY_RIGHT, KEY_D:
			_player_manager._try_move_local(1, 0)




func set_character_data(data: Dictionary) -> void:
	if _hud_manager != null:
		_hud_manager._update_char_info(data)
	else:
		_pending_char_data = data.duplicate()


## Called by OverworldMobManager signal when a mob reaches the player cell.
func _on_mob_reached_player(mob_data: MobData) -> void:
	if _combat_pending or _interaction_manager._is_ui_overlay_open() or get_tree().paused:
		return
	_combat_pending = true
	var gs := _gs
	if not is_instance_valid(gs):
		_combat_pending = false
		return
	var lx := mob_data.grid_x
	var ly := mob_data.grid_y
	var tile_key := "%d,%d|%d,%d" % [_player_q, _player_r, lx, ly]
	var char_data: Dictionary = gs.get_party_character_data()
	var em := _em
	var equip_stats: Dictionary = em.get_combat_stats("player") if is_instance_valid(em) else {}
	var biome: String = str(_tile_map.get("%d,%d" % [_player_q, _player_r], {}).get("name", "Ash Wastes"))
	var enemy_dict := mob_data.to_enemy_dict()
	var encounter: Dictionary = EncounterBuilder.build_overworld(char_data, enemy_dict, tile_key, biome, equip_stats)
	if encounter.is_empty():
		_combat_pending = false
		return
	gs.remove_overworld_mob(gs.mob_key(_player_q, _player_r, lx, ly))
	_map_manager._mark_world_markers_dirty()

	# Multiplayer: include nearby remote players in combat
	if _is_multiplayer and multiplayer.is_server():
		_network_manager._add_nearby_players_to_encounter(encounter, lx, ly)

	var gm: GameManager = _gm
	if is_instance_valid(gm):
		gm.go_to_tactical_combat(encounter)

	# Multiplayer: broadcast combat start to affected peers
	if _is_multiplayer and _net_sync != null and _net_sync.has_method("sync_combat_start"):
		_net_sync.sync_combat_start_all(encounter)


# ---------------------------------------------------------------------------
# Phase 1: Floor pickups (sticks, stones)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Phase 1: Resource node gathering (E key)
# ---------------------------------------------------------------------------

# Currently equipped MainHand tool. Phase 1 placeholder; real tool
# tracking lands in Phase 4 with EquipmentManager.
func _start_audio_for_current_region() -> void:
	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play_track"):
		mm.call("play_track", "exploration")
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa == null or not aa.has_method("map_biome"):
		return
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	var biome_name: String = str(tile.get("name", _local_map.get("biome", "")))
	var ambient_key: String = aa.call("map_biome", biome_name) as String
	if ambient_key.is_empty():
		aa.call("stop_all", 0.5)
	else:
		aa.call("play_biome", ambient_key, 1.0)


func _mark_world_markers_dirty() -> void:
	_world_markers_dirty = true


func get_random_spawn_point() -> Vector2:
	if is_instance_valid(_player_visual):
		return _player_visual.global_position + Vector2(randf_range(-300, 300), randf_range(-300, 300))
	return Vector2(256 * 24 + 12, 256 * 24 + 12)


func _restore_sleeping_bag() -> void:
	if not is_instance_valid(_gs) or not is_instance_valid(_map_view):
		return
	var hex_state: Dictionary = _gs.get_hex_state(_player_q, _player_r)
	if hex_state.is_empty():
		return
	var bag_data = hex_state.get("placed_sleeping_bag", {})
	if not (bag_data is Dictionary) or bag_data.is_empty():
		return
	var lx: int = int(bag_data.get("local_x", -1))
	var ly: int = int(bag_data.get("local_y", -1))
	if lx < 0 or ly < 0:
		return
	var bag := SleepingBag.new()
	var cell_size: int = _map_view.get_cell_size() if _map_view.has_method("get_cell_size") else 24
	bag.position = Vector2(lx * cell_size + cell_size * 0.5, ly * cell_size + cell_size * 0.5)
	if _map_view.has_method("add_sleeping_bag"):
		_map_view.add_sleeping_bag(Vector2i(lx, ly), bag)


func _seed_local_mobs() -> void:
	var gs := _gs
	if not is_instance_valid(gs):
		return

	if _tile_map.is_empty():
		push_warning("[HubWorld] _tile_map is empty — cannot seed mobs.")
		return
	# Skip if this hex was already seeded (prevents killed mobs from
	# re-appearing when HubWorld reloads — deterministic RNG would
	# place them at the same positions).
	var hex_key: String = "%d,%d" % [_player_q, _player_r]
	if _seeded_hexes.has(hex_key):
		return
	_seeded_hexes[hex_key] = true

	var rng := RandomNumberGenerator.new()
	rng.seed = LocalMapGen.hash_seed(LocalMapGen.make_local_seed(
		str(gs.get_world_data().get("seed", "mobs")), _player_q, _player_r
	))
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	var biome: String = str(tile.get("name", "Ash Wastes"))
	var danger: float = float(tile.get("rift_chance", 0.25))
	var level_range: Dictionary = tile.get("level_range", {"min_level": 2, "max_level": 6})
	# v0.9.1: Bumped density. With the previous 2-9 mobs in 502×502, the
	# player had to walk hundreds of cells to find one. Bumping to 8-18
	# + adding 2 guaranteed "near-spawn" mobs ensures the player
	# sees a fight within walking distance of their starting cell.
	var count := rng.randi_range(8, 12 + int(danger * 8))
	var seeded := 0
	var skipped_blocked := 0
	var skipped_near := 0
	var skipped_duplicate := 0
	var skipped_no_enemy := 0

	# v0.9.1: 2 guaranteed mobs in the player's camera view (within
	# 20 cells of spawn). Camera shows ~53×30 cells, so cells in the
	# 3..20 distance range are always visible from spawn.
	for _i in range(2):
		var tries: int = 0
		while tries < 16:
			tries += 1
			var ndx: int = rng.randi_range(-20, 20)
			var ndy: int = rng.randi_range(-15, 15)
			# Skip if too close (<3) — keep them on screen but not on the player
			if abs(ndx) + abs(ndy) < 3:
				continue
			var nlx: int = clampi(_local_x + ndx, 4, LocalMapGen.MAP_SIZE - 4)
			var nly: int = clampi(_local_y + ndy, 4, LocalMapGen.MAP_SIZE - 4)
			if LocalMapGen.get_movement_cost(_local_map, nlx, nly) < 0:
				continue
			var nkey: String = gs.mob_key(_player_q, _player_r, nlx, nly)
			if not gs.get_overworld_mob(nkey).is_empty():
				continue
			var near_diff: Dictionary = {"min_level": int(level_range.get("min_level", 2)), "max_level": mini(int(level_range.get("min_level", 2)) + 3, int(level_range.get("max_level", 5)))}
			var near_enemy: Dictionary = EncounterBuilder.generate_procedural_enemy(
				str(gs.get_world_data().get("seed", "")), _tile_map,
				"%d,%d" % [_player_q, _player_r], near_diff, "upworld", biome
			)
			if near_enemy.is_empty():
				continue
			gs.set_local_mob(_player_q, _player_r, nlx, nly, near_enemy)
			seeded += 1
			break

	for i in count:
		var lx := rng.randi_range(10, LocalMapGen.MAP_SIZE - 10)
		var ly := rng.randi_range(10, LocalMapGen.MAP_SIZE - 10)
		if LocalMapGen.get_movement_cost(_local_map, lx, ly) < 0:
			skipped_blocked += 1
			continue
		# v0.9.1: 2-cell exclusion (was 5) so mobs can spawn right next
		# to the player. The player needs to be on an adjacent cell to
		# trigger combat, and walking 5+ cells felt like a desert.
		if abs(lx - _local_x) + abs(ly - _local_y) < 2:
			skipped_near += 1
			continue
		# v0.8.0: skip mobs inside the town boundary (clearing + buildings)
		var town_bnd: Variant = _local_map.get("settlement", {}).get("boundary", null)
		if town_bnd is Rect2i and town_bnd.has_point(Vector2i(lx, ly)):
			skipped_blocked += 1
			continue
		var key := gs.mob_key(_player_q, _player_r, lx, ly)
		if not gs.get_overworld_mob(key).is_empty():
			skipped_duplicate += 1
			continue

		# Generate enemy via EncounterBuilder (independent of NPC system)
		var difficulty: Dictionary = {"min_level": int(level_range.get("min_level", 2)), "max_level": int(level_range.get("max_level", 6))}
		var enemy: Dictionary = EncounterBuilder.generate_procedural_enemy(
			str(gs.get_world_data().get("seed", "")), _tile_map,
			"%d,%d" % [_player_q, _player_r], difficulty, "upworld", biome
		)
		if enemy.is_empty():
			skipped_no_enemy += 1
			continue

		gs.set_local_mob(_player_q, _player_r, lx, ly, enemy)
		seeded += 1



func _start_local_combat(lx: int, ly: int, mob: Dictionary, mission: Dictionary = {}) -> void:
	if _combat_pending:
		return
	_combat_pending = true
	var gs := _gs
	if not is_instance_valid(gs):
		_combat_pending = false
		return
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	var biome: String = str(tile.get("name", "Ash Wastes"))
	var tile_key := "%d,%d|%d,%d" % [_player_q, _player_r, lx, ly]
	var char_data: Dictionary = gs.get_party_character_data()
	var equip_stats: Dictionary = _em.get_combat_stats("player") if is_instance_valid(_em) else {}
	var encounter: Dictionary = {}
	var mission_id: String = str(mob.get("mission_id", mission.get("mission_id", "")))
	if not mission_id.is_empty() and is_instance_valid(_mission_manager) and _mission_manager.has_method("build_mission_encounter"):
		encounter = _mission_manager.call("build_mission_encounter", mission_id, char_data, equip_stats) as Dictionary
	if encounter.is_empty():
		encounter = EncounterBuilder.build_overworld(char_data, mob, tile_key, biome, equip_stats)
	_map_manager._mark_world_markers_dirty()

	# Multiplayer: include nearby remote players in combat
	if _is_multiplayer and multiplayer.is_server():
		_network_manager._add_nearby_players_to_encounter(encounter, lx, ly)

	# Remove the mob from GameState to prevent double-triggering
	gs.remove_overworld_mob(gs.mob_key(_player_q, _player_r, lx, ly))

	var gm: GameManager = _gm
	if is_instance_valid(gm):
		gm.go_to_tactical_combat(encounter)

	# Multiplayer: broadcast combat start to affected peers
	if _is_multiplayer and _net_sync != null and _net_sync.has_method("sync_combat_start"):
		_net_sync.sync_combat_start_all(encounter)


func _on_equipment_changed(npc_id: String, slot: String) -> void:
	if npc_id != "player":
		return
	if not is_instance_valid(_player_visual):
		return
	if is_instance_valid(_em):
		var equip: Dictionary = _em.get_equipment("player")
		_player_visual.call("update_equipment", equip)


func _on_mount_changed(_mount_id: String) -> void:
	_update_mount_visual()


func _update_mount_visual() -> void:
	if not is_instance_valid(_player_visual):
		return
	var tmm: Node = get_node_or_null("/root/TamedMobManager")
	if not is_instance_valid(tmm):
		return
	var mount_data: Dictionary = tmm.get_active_mount() if tmm.has_method("get_active_mount") else {}
	var sprite_id: String = str(mount_data.get("sprite_id", ""))
	if sprite_id.is_empty():
		_player_visual.call("clear_mount_sprite")
	else:
		_player_visual.call("set_mount_sprite", sprite_id)


func _get_mount_speed_mult() -> float:
	var tmm: Node = get_node_or_null("/root/TamedMobManager")
	if is_instance_valid(tmm) and tmm.has_method("get_mount_speed_mult"):
		return tmm.get_mount_speed_mult()
	return 1.0


func _exit_tree() -> void:
	if _network_manager != null:
		_network_manager._cleanup_remote_players()
		_network_manager._disconnect_net_signals()
