## HubWorld — Local 512×512 playfield for the current sphere hex region.
## Walk the local map; cross edges to adjacent hex regions; open World Map for strategic travel.
class_name HubWorld extends Control

signal enter_rift_requested(rift_id: String)
signal back_to_menu_requested()

const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const LocalMapViewScene = preload("res://scenes/LocalMapView.tscn")
const MobVisualScript = preload("res://scripts/MobVisual.gd")
const OverworldMobAIScript = preload("res://scripts/ai/OverworldMobAI.gd")
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

const RIFT_CHECK_INTERVAL := 30.0
const GATHER_RANGE_CELLS := 1  # adjacent cells; player can gather from 1 tile away

@onready var char_label: RichTextLabel = $CharInfoBar/CharLabel as RichTextLabel
@onready var tile_info_label: RichTextLabel = $TileInfoPanel/TileInfoLabel as RichTextLabel
@onready var rift_info_label: RichTextLabel = $TileInfoPanel/RiftInfoLabel as RichTextLabel
@onready var world_grid: Node2D = $WorldGrid as Node2D
@onready var camera: Camera2D = $WorldGrid/Camera2D as Camera2D

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

# Currently equipped MainHand tool (Phase 1 placeholder until
# EquipmentManager lands in Phase 4). Empty dict = no tool.
var _equipped_tool: Dictionary = {}

# Phase 1b: hover tooltip (1s dwell) — shows the name of what's under
# the mouse cursor on the local map.
var _hover_tooltip: Control = null

# Phase 2: full in-game HUD (top bar, HP/MP/XP bars, minimap, hotbar).
var _hud: Control = null
var _hud_minimap_tick: float = 0.0

# Phase 3: settlement enter / exit
var _settlement_label: Label
var _character_menu: Control = null
# Phase 6: base (player-chosen placement, upgrades, leave-base)
var _base_node: Node2D = null
var _base_interior: Control = null

# v0.6.0: currently-open CookingTableUI (null when not open).
var _cooking_table_ui: Control = null
var _base_placement_open: bool = false
var _rift_runner: Node = null
var _game_time: float = 0.0
var _rift_check_timer: float = 0.0
var _enter_btn: Button = null
var _map_btn: Button = null
var _recruit_btn: Button = null
var _mission_btn: Button = null
var _npc_info_label: RichTextLabel = null
var _save_btn: Button = null
var _mission_info_label: RichTextLabel = null
var _npc_manager: Node = null
var _mission_manager: Node = null
var _pause_menu: PauseMenu = null
var _player_visual: Node2D = null
var _transition_screen: CanvasLayer = null

# v0.10.1: Mob AI entries keyed by "lx,ly" — each value is a dictionary
# { node: MobVisual, ai: OverworldMobAI, grid_x, grid_y, moving, tween, data }.
var _overworld_mobs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[HubWorld] Local overworld map loading.")

	_enter_btn = $BottomBar/EnterRift as Button
	var menu_btn: Button = $BottomBar/BackToMenu as Button
	_map_btn = $BottomBar/WorldMap as Button
	if is_instance_valid(_enter_btn):
		_enter_btn.pressed.connect(_on_enter_rift_pressed)
		_enter_btn.disabled = true
	if is_instance_valid(menu_btn):
		menu_btn.pressed.connect(_on_back_to_menu_pressed)
	if is_instance_valid(_map_btn):
		_map_btn.pressed.connect(_on_world_map_pressed)

		# Manual save button
		_save_btn = Button.new()
		_save_btn.name = "SaveGame"
		_save_btn.custom_minimum_size = Vector2(160, 45)
		_save_btn.text = "SAVE"
		_save_btn.disabled = true
		_save_btn.pressed.connect(_on_save_pressed)
		$BottomBar.add_child(_save_btn)

	_rift_runner = get_node_or_null("/root/RiftRunner")
	_npc_manager = get_node_or_null("/root/NPCManager")
	_mission_manager = get_node_or_null("/root/MissionManager")
	_world_gen = WorldGenerator.new()
	add_child(_world_gen)

	# Wire SettlementManager's left_settlement to HubWorld's
	# _leave_settlement so when the Settlement interior calls
	# leave_settlement(), the world view comes back.
	var settlement_mgr: Node = get_node_or_null("/root/SettlementManager")
	if settlement_mgr != null and not settlement_mgr.is_connected("left_settlement", _leave_settlement):
		settlement_mgr.connect("left_settlement", _leave_settlement)

	_setup_npc_ui()
	_setup_mission_ui()

	# Phase F: Transition screen for fade effects
	if TransitionScreenScene != null:
		_transition_screen = TransitionScreenScene.instantiate()
		add_child(_transition_screen)

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var char_data: Dictionary = gs.get_party_character_data()
		if not char_data.is_empty():
			_update_char_info(char_data)
			_save_btn.disabled = false

		_tile_map = gs.get_tile_map()
		if _tile_map.is_empty() and gs.has_world():
			var wd: Dictionary = gs.get_world_data()
			if wd.get("tile_map") is Dictionary:
				_tile_map = wd["tile_map"]

		if not _tile_map.is_empty():
			var seed_str: String = str(gs.get_world_data().get("seed", ""))
			_world_gen.load_from_tile_map(_tile_map, seed_str)

		var pos: Vector2i = gs.get_player_position()
		_player_q = pos.x
		_player_r = pos.y
		var local_pos: Vector2i = gs.get_local_position()
		_local_x = local_pos.x
		_local_y = local_pos.y

		_local_map = gs.ensure_hex_state(_player_q, _player_r)
		gs.set_local_position(_local_x, _local_y)

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

		var start: Dictionary = gs.get_start_tile()
		if not start.is_empty():
			_append_start_info(start)

	_setup_map_view()
	if is_instance_valid(_map_view):
		_map_view.configure(_local_map)
	_setup_player_visual()
	# Wire equipment changes to update player visual overlay
	var em: EquipmentManager = get_node_or_null("/root/EquipmentManager") as EquipmentManager
	if is_instance_valid(em):
		if not em.equipment_changed.is_connected(_on_equipment_changed):
			em.equipment_changed.connect(_on_equipment_changed)
		# Apply current equipment overlay immediately
		if is_instance_valid(_player_visual):
			var equip: Dictionary = em.get_equipment("player")
			_player_visual.call("update_equipment", equip)
	_setup_hover_tooltip()
	_setup_hud()
	_game_time = Time.get_ticks_msec() / 1000.0
	_build_local_view()
	_update_tile_info()
	_update_rift_ui()
	_update_npc_ui()
	_update_mission_ui()
	_spawn_initial_rift_if_needed()
	_ensure_world_npcs()
	_seed_local_mobs()
	# v0.9.1c: Mobs were just seeded — force marker refresh on the
	# next _build_local_view call.
	_mark_world_markers_dirty()
	_build_local_view()
	_save_to_autoslot_if_can()
	# Audio: exploration music + ambient bed for the current biome.
	_start_audio_for_current_region()


var _escape_was_pressed: bool = false


func _process(delta: float) -> void:
	var esc_pressed: bool = Input.is_key_pressed(KEY_ESCAPE)
	if esc_pressed and not _escape_was_pressed and not _is_ui_overlay_open():
		_toggle_pause_menu()
	_escape_was_pressed = esc_pressed

	_game_time = Time.get_ticks_msec() / 1000.0
	_rift_check_timer += delta
	if _rift_check_timer >= RIFT_CHECK_INTERVAL:
		_rift_check_timer = 0.0
		_tick_rifts()
		_tick_missions()

	# Phase 1: gather timer ticks down each frame.
	_tick_gather(delta)

	# Phase 1: HarvestNode respawn timers tick down each frame.
	# v0.9.1c: Only tick nodes that are CURRENTLY respawning. With
	# 16k+ resource nodes, iterating all of them costs ~25ms/frame
	# even though the vast majority return immediately (not depleted).
	# The active list is small (typically 0-5 nodes) — only nodes
	# that the player has depleted and is waiting to respawn.
	_tick_active_respawn_nodes(delta)

	# v0.10.0: Tick overworld mob AI (pathfinding + aggro + combat trigger).
	_tick_overworld_mobs(delta)

	# Phase 1b: hover tooltip — find what's under the mouse and update.
	_tick_hover_tooltip()

	# Phase 2: refresh HUD minimap periodically (cheap; once per second)
	_hud_minimap_tick += delta
	if _hud_minimap_tick >= 1.0 and is_instance_valid(_hud):
		_hud_minimap_tick = 0.0
		if _hud.has_method("notify_cell_changed"):
			_hud.notify_cell_changed()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	# Note: we do NOT early-return on `get_tree().paused` here. The
	# character-menu hotkeys (I/E/C/P/S) must work even while the
	# pause menu is open, so the player can flip between inventory
	# and the pause menu without having to dismiss one first. The
	# game-specific input (movement, interact, world map) is gated
	# separately below by `_is_ui_overlay_open()` and the explicit
	# `get_tree().paused` check in the `Interact` / movement blocks.

	var km: Node = get_node_or_null("/root/KeybindManager")
	if km == null:
		_fallback_unhandled_input(event)
		return

	# Character-menu hotkeys — always allowed (open new or switch tabs)
	# even while the pause menu is open. These don't mutate game state.
	if km.is_action_pressed("inventory", event):
		open_character_tab("inventory")
		return
	if km.is_action_pressed("equipment", event):
		if not _has_adjacent_harvest_node():
			open_character_tab("equipment")
			return
	if km.is_action_pressed("crafting", event):
		open_character_tab("crafting")
		return
	if km.is_action_pressed("party", event):
		open_character_tab("party")
		return
	# S is shared between `move_down` and `stats` (see KeybindManager).
	# Per the original Phase 3 design: S only opens the Stats tab when
	# the CharacterMenu is already open — otherwise S is left to fall
	# through to movement below. Same applies to the fallback handler.
	if km.is_action_pressed("stats", event):
		if _hud != null and is_instance_valid(_hud) and _hud.has_method("is_character_menu_open") and _hud.is_character_menu_open():
			open_character_tab("stats")
			return
		# Menu closed: don't consume the event — let it reach the
		# movement block below so S moves the player south.

	# Block remaining game input when any UI overlay is open OR the
	# game is paused (e.g. pause menu).
	if _is_ui_overlay_open() or get_tree().paused:
		return

	# Interact / gather
	if km.is_action_pressed("interact", event) and not event.echo:
		var sm_inner: Node = get_node_or_null("/root/SettlementManager")
		if sm_inner != null and sm_inner.is_inside_settlement():
			_leave_settlement()
			return
		if is_instance_valid(_base_interior):
			_leave_base()
			return
		var bm_e: Node = get_node_or_null("/root/BaseManager")
		if bm_e != null and bm_e.can_unlock() and bm_e.is_unplaced():
			_open_base_placement()
			return
		if _adjacent_cooking_table() != null:
			_open_cooking_table_ui()
			return
		var adj_bld: Node2D = _adjacent_building()
		if adj_bld != null:
			_interact_building(adj_bld)
			return
		_try_start_gather()
		return

	# World map
	if km.is_action_pressed("world_map", event):
		_on_world_map_pressed()
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
		_try_move_local(dir.x, dir.y)


## Fallback when KeybindManager is not available (uses hardcoded defaults).
func _fallback_unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	# Character-menu hotkeys — always allowed even while paused
	match event.keycode:
		KEY_I:
			open_character_tab("inventory")
			return
		KEY_E:
			if not _has_adjacent_harvest_node():
				open_character_tab("equipment")
				return
		KEY_C:
			open_character_tab("crafting")
			return
		KEY_P:
			open_character_tab("party")
			return
		KEY_S:
			# S is shared with movement. Only open Stats when the
			# CharacterMenu is already open; otherwise let S fall
			# through to the movement block below.
			if _hud != null and is_instance_valid(_hud) and _hud.has_method("is_character_menu_open") and _hud.is_character_menu_open():
				open_character_tab("stats")
				return
	# Block remaining game input when any UI overlay is open OR the
	# game is paused (e.g. pause menu).
	if _is_ui_overlay_open() or get_tree().paused:
		return
	match event.keycode:
		KEY_M:
			_on_world_map_pressed()
		KEY_UP, KEY_W:
			_try_move_local(0, -1)
		KEY_DOWN, KEY_S:
			_try_move_local(0, 1)
		KEY_LEFT, KEY_A:
			_try_move_local(-1, 0)
		KEY_RIGHT, KEY_D:
			_try_move_local(1, 0)


## True if there's a HarvestNode adjacent to the player that the
## current tool can gather. Used to disambiguate the E key (gather vs
## open Equipment tab).
func _has_adjacent_harvest_node() -> bool:
	if not is_instance_valid(_map_view):
		return false
	var nodes: Array = _map_view.get_resource_nodes_near(
		Vector2i(_local_x, _local_y), GATHER_RANGE_CELLS
	)
	return not nodes.is_empty()


## True if any *game-blocking* UI overlay is open. The pause menu
## and the character menu are deliberately NOT included here — they
## are independent overlays (toggled by Escape and I/E/C/P/S
## respectively) and the player should be able to open either one
## without having to dismiss the other first. Only the cooking table,
## base interior, and settlement interior are "modal" in the sense
## that they take over the world and need to be closed before any
## other UI can be opened.
func _is_ui_overlay_open() -> bool:
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("is_character_menu_open"):
		if _hud.is_character_menu_open():
			return true
	if _cooking_table_ui != null and is_instance_valid(_cooking_table_ui):
		return true
	if _base_interior != null and is_instance_valid(_base_interior):
		return true
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm != null and sm.has_method("is_inside_settlement") and sm.is_inside_settlement():
		return true
	return false


# ---------------------------------------------------------------------------
# Phase 3: settlement entry / exit
# ---------------------------------------------------------------------------

## Returns the settlement hex adjacent to the player, or "" if none.
## Used by the E key (gather → entry) and the world marker.
func _adjacent_settlement_hex() -> String:
	if not is_instance_valid(_map_view):
		return ""
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm != null and sm.is_inside_settlement():
		return ""
	# Walk adjacent cells looking for a SettlementNode
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var cell := Vector2i(_local_x + dx, _local_y + dy)
			# The settlement node may be on the cell the player is on too
			var s_node: Node2D = _map_view.get_settlement_at(cell)
			if s_node != null:
				return s_node.get_cell(24) if s_node.has_method("get_cell") else str(s_node.get_meta("hex", ""))
	return ""


## v0.6.0: Returns the adjacent CookingTable node, or null. Used by
## the E key to open the CookingTableUI.
func _adjacent_cooking_table() -> Node2D:
	if not is_instance_valid(_map_view):
		return null
	# Walk adjacent cells (and the player's own cell) looking for a
	# cooking table. Like the settlement check, the table may be on the
	# cell the player is on.
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var cell := Vector2i(_local_x + dx, _local_y + dy)
			var t_node: Node2D = _map_view.get_cooking_table_at(cell)
			if t_node != null:
				return t_node
	return null


## v0.8.0: Returns the adjacent SettlementBuilding node, or null.
## Checks the player's own cell and all 8 neighbors.
func _adjacent_building() -> Node2D:
	if not is_instance_valid(_map_view):
		return null
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var cell := Vector2i(_local_x + dx, _local_y + dy)
			var bld: Node2D = _map_view.get_building_at(cell)
			if bld != null:
				return bld
	return null


## v0.8.0: Interact with a settlement building. Opens role-specific UI
## or enters the settlement interior focused on this building.
func _interact_building(building: Node2D) -> void:
	if not is_instance_valid(building):
		return
	var bld_role: String = building.get_role() if building.has_method("get_role") else ""
	var bld_id: String = building.get_building_id() if building.has_method("get_building_id") else ""
	match bld_role:
		"trader":
			# Open shop directly
			var sm: Node = get_node_or_null("/root/SettlementManager")
			if sm != null:
				var hex: String = _adjacent_settlement_hex()
				if not hex.is_empty():
					sm.enter_settlement(hex, self, bld_id)
					world_grid.visible = false
					return
			# Fallback: open shop UI directly
			_open_shop_interface()
		"quest_giver":
			_open_mission_board()
		_:
			# Enter settlement interior focused on this building
			var hex: String = _adjacent_settlement_hex()
			if not hex.is_empty():
				_try_enter_settlement(bld_id)
			else:
				print("[HubWorld] Building: %s (%s)" % [bld_id, bld_role])


func _open_shop_interface() -> void:
	if has_node("Shop"):
		return
	var ShopScript: GDScript = load("res://scripts/ui/ShopInterface.gd")
	if ShopScript == null:
		return
	var shop: Control = ShopScript.new()
	shop.name = "Shop"
	add_child(shop)


func _open_mission_board() -> void:
	if has_node("MissionBoard"):
		return
	var MBScript: GDScript = load("res://scripts/ui/MissionBoardInterface.gd")
	if MBScript == null:
		return
	var board: Control = MBScript.new()
	board.name = "MissionBoard"
	add_child(board)


## v0.6.0: Open the CookingTableUI as a modal overlay.
func _open_cooking_table_ui() -> void:
	if _cooking_table_ui != null and is_instance_valid(_cooking_table_ui):
		# Already open — focus it
		return
	var CookingTableUIScene: PackedScene = load("res://scenes/ui/CookingTableUI.tscn") as PackedScene
	if CookingTableUIScene == null:
		push_error("[HubWorld] CookingTableUI scene not found")
		return
	_cooking_table_ui = CookingTableUIScene.instantiate()
	add_child(_cooking_table_ui)
	_cooking_table_ui.set_on_close(_on_cooking_table_closed)
	print("[HubWorld] Opened CookingTableUI")


func _on_cooking_table_closed() -> void:
	if _cooking_table_ui != null and is_instance_valid(_cooking_table_ui):
		_cooking_table_ui.queue_free()
	_cooking_table_ui = null
	print("[HubWorld] Closed CookingTableUI")


## Enter the settlement adjacent to the player (if any). Riftspire
## entry is gated on player level; settlements have no gate.
func _try_enter_settlement(focus_building: String = "") -> void:
	var hex: String = _adjacent_settlement_hex()
	if hex.is_empty():
		return
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm == null:
		return
	# Riftspire is special — gated on level
	if sm.is_riftspire(hex):
		var prog: Node = get_node_or_null("/root/ProgressionManager")
		var level: int = int(prog.level) if prog != null else 1
		if not sm.can_enter_riftspire(level):
			var reason: String = sm.riftspire_block_reason(level)
			print("[HubWorld] Riftspire entry blocked: %s" % reason)
			_show_settlement_message(reason)
			return
	# Phase F: Fade transition
	if is_instance_valid(_transition_screen):
		await _transition_screen.fade_out(0.4)
	if sm.enter_settlement(hex, self, focus_building):
		# Hide the world view (the settlement interior covers the full
		# Control)
		world_grid.visible = false
		# Update minimap
		if is_instance_valid(_hud):
			_hud.notify_cell_changed()
	if is_instance_valid(_transition_screen):
		_transition_screen.fade_in(0.3)


## Show a transient message in the bottom bar (Phase 3 stub: just print).
func _show_settlement_message(msg: String) -> void:
	# In Phase 8 we'd add a proper toast. For now, surface via the
	# tile info label or print.
	print("[HubWorld] %s" % msg)


# Phase 8: spawn a floating loot popup at the given world position
# (typically the pickup / gather cell). The popup rises and fades
# over ~1.5 seconds.
func _spawn_loot_popup(text: String, world_pos: Vector2) -> void:
	if LootPopupScript == null:
		return
	var popup: Control = LootPopupScene.instantiate()
	popup.text = text
	# Position at the player's current cell in world space
	var px: float = float(_local_x) * 24.0 + 12.0
	var py: float = float(_local_y) * 24.0 + 12.0
	if world_pos == Vector2.ZERO:
		popup.global_position = Vector2(px - 30, py - 12)
	else:
		popup.global_position = world_pos
	add_child(popup)


## Leave the active settlement (called by Settlement interior's
## "Leave" button or Esc/E).
func _leave_settlement() -> void:
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm == null or not sm.is_inside_settlement():
		return
	# Phase F: Fade transition
	if is_instance_valid(_transition_screen):
		await _transition_screen.fade_out(0.3)
	sm.leave_settlement()
	# Restore the world view
	world_grid.visible = true
	if is_instance_valid(_hud):
		_hud.notify_cell_changed()
	if is_instance_valid(_transition_screen):
		_transition_screen.fade_in(0.3)


# ---------------------------------------------------------------------------
# Phase 6: base (player-chosen placement, upgrades, leave-base)
# ---------------------------------------------------------------------------

## E-key disambiguation now also checks for a base. Priority order:
## settlement > base > harvest > equipment tab.
func _has_adjacent_base() -> bool:
	if _base_node != null and is_instance_valid(_base_node):
		var cell: Vector2i = _base_node.get_cell(24) if _base_node.has_method("get_cell") else Vector2i.ZERO
		# Base is "adjacent" if the player is on the same cell (base is
		# the player's home; they spawn on top of it) or on an
		# immediate-neighbor cell.
		if cell == Vector2i(_local_x, _local_y):
			return true
		var dx: int = abs(cell.x - _local_x)
		var dy: int = abs(cell.y - _local_y)
		if dx <= 1 and dy <= 1:
			return true
	return false


## Open the base-placement UI overlay (player picks a cell with the
## 50-tile buffer). For Phase 6 this is a minimal overlay: a label +
## arrows (WASD moves a ghost preview; E confirms). Confirming checks
## is_valid_placement_cell and calls BaseManager.place.
func _open_base_placement() -> void:
	_base_placement_open = true
	_show_settlement_message("Pick a base location: 50-tile buffer from map edges. (Phase 6: auto-places at the local center; full placement UI in Phase 8.)")
	# Minimal placeholder: auto-place at the center of the local map.
	var cx: int = 256
	var cy: int = 256
	var bm: Node = get_node_or_null("/root/BaseManager")
	if bm != null and bm.can_unlock() and bm.is_unplaced():
		var hex_key: String = "%d,%d" % [_player_q, _player_r]
		if bm.place(hex_key, cx, cy):
			_spawn_base_node(hex_key, cx, cy)
			_show_settlement_message("Base placed at (%d, %d) — level 1, capacity 5." % [cx, cy])
	_base_placement_open = false


func _spawn_base_node(hex_key: String, lx: int, ly: int) -> void:
	if _base_node != null and is_instance_valid(_base_node):
		_base_node.queue_free()
	_base_node = BaseNodeScene.instantiate()
	_base_node.name = "BaseNode"
	# Pull the latest snapshot
	var bm: Node = get_node_or_null("/root/BaseManager")
	var snap: Dictionary = bm.get_snapshot() if bm != null else {}
	_base_node.setup({"placement": snap.get("placement", {}), "level": int(snap.get("level", 1))})
	_base_node.position = Vector2(lx * 24 + 12, ly * 24 + 12)
	if has_node("WorldGrid"):
		# Place on the world_grid so it renders with the world
		var wg: Node = get_node("WorldGrid")
		wg.add_child(_base_node)
	# Add to map_view's settlement layer for hit-test parity
	if is_instance_valid(_map_view) and _map_view.has_method("get_settlement_layer"):
		pass  # settlements are towns; the base has its own rendering


## Open the base interior (called when player presses E on the base).
func _try_enter_base() -> void:
	var bm: Node = get_node_or_null("/root/BaseManager")
	if bm == null or bm.is_unplaced():
		return
	# Spawn the interior
	_base_interior = BaseScene.instantiate()
	_base_interior.name = "Base"
	_base_interior.setup(bm.get_snapshot(), self)
	add_child(_base_interior)
	world_grid.visible = false
	if is_instance_valid(_hud):
		_hud.notify_cell_changed()


## Leave the base interior.
func _leave_base() -> void:
	if is_instance_valid(_base_interior):
		_base_interior.queue_free()
	_base_interior = null
	world_grid.visible = true
	if is_instance_valid(_hud):
		_hud.notify_cell_changed()


# ---------------------------------------------------------------------------
# Phase 2: full Character HUD
# ---------------------------------------------------------------------------

func _setup_hud() -> void:
	_hud = HUDScript.new()
	_hud.name = "HUD"
	_hud.menu_requested.connect(_open_character_menu)
	add_child(_hud)
	# The new HUD has its own top bar / HP/MP/XP / minimap / hotbar. Hide
	# the old CharInfoBar so we don't show the same info twice.
	if has_node("CharInfoBar"):
		var old_bar := get_node("CharInfoBar") as CanvasItem
		if old_bar != null:
			old_bar.visible = false


## Called by the HUD's menu button. Opens the CharacterMenu (tabbed
## shell) with the Inventory tab as default. Always available — the
## character menu is independent of the pause menu and other overlays
## (e.g. pressing the menu button or the I/E/C/P/S hotkeys should
## work even while the pause menu is open).
func _open_character_menu() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	_hud.open_character_menu("inventory")


## Open the CharacterMenu to a specific tab. Called by keyboard
## hotkeys (I/E/C/P/S). Always available — see _open_character_menu.
func open_character_tab(tab_id: String) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	_hud.open_character_menu(tab_id)


# ---------------------------------------------------------------------------
# Phase 1b: hover tooltip
# ---------------------------------------------------------------------------

func _setup_hover_tooltip() -> void:
	# The tooltip is a Control that renders a small Label. It's added to
	# the HubWorld tree (Control) so it renders on top of the world.
	_hover_tooltip = HoverTooltipScript.new()
	_hover_tooltip.name = "HoverTooltip"
	_hover_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hover_tooltip.position = Vector2.ZERO
	_hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_tooltip)


func _tick_hover_tooltip() -> void:
	if not is_instance_valid(_hover_tooltip):
		return
	if not is_instance_valid(_map_view):
		return
	# Convert mouse position (in screen coords) to local coords of the
	# HubWorld Control. The _map_view sits at world_grid; for the cursor
	# hit-test we want the position inside the map view's coordinate space.
	# The world_grid is at (0, 0) within HubWorld (Control), and the
	# map_view sits at (0, 0) within world_grid. So the mouse position
	# relative to the map_view equals the local mouse position.
	var mouse_local: Vector2 = get_local_mouse_position()
	var target_text: String = _hit_test_at_world(mouse_local)
	_hover_tooltip.update(mouse_local, target_text)


# Hit-test the world at a local position (HubWorld's coordinate space).
# Returns the display name of the topmost entity at that cell, or "" if
# nothing notable. Priority: resource node > floor pickup > mob > rift
# marker > NPC marker > terrain label.
func _hit_test_at_world(world_pos: Vector2) -> String:
	if not is_instance_valid(_map_view):
		return ""
	var cell_size: int = _map_view.get_cell_size()
	var cell := Vector2i(
		int(floor(world_pos.x / cell_size)),
		int(floor(world_pos.y / cell_size)),
	)
	# Skip the player's own cell (no point showing "Player" all the time)
	if cell == Vector2i(_local_x, _local_y):
		return ""

	# 1. Resource node at this cell
	for entry in _map_view.get_resource_nodes_near(cell, 0):
		var n: Node = entry.get("node")
		if n != null and is_instance_valid(n):
			var d: Dictionary = n.node_data
			return str(d.get("name", d.get("id", "Resource")))

	# 2. Floor pickup
	var pickup: Node2D = _map_view.get_floor_pickup_at(cell)
	if pickup != null and is_instance_valid(pickup):
		var item_id: String = pickup.get_item_id()
		var inv: Node = get_node_or_null("/root/InventoryManager")
		if inv != null and inv.has_method("get_item_name"):
			return String(inv.get_item_name(item_id))
		return item_id

	# 3. Mobs and rift / NPC markers (search _marker_nodes for this cell)
	var cell_key := "%d,%d" % [cell.x, cell.y]
	for kind in ["mob", "rift", "npc", "mission"]:
		var key: String = "%s|%s" % [kind, cell_key]
		if _marker_nodes.has(key):
			match kind:
				"mob":
					return _mob_name_at_cell(cell)
				"rift":
					return "Rift"
				"npc":
					return _npc_name_at_hex()
				"mission":
					return "Mission"

	# 4. Terrain label (always present)
	return _terrain_label_at_cell(cell)


func _terrain_label_at_cell(cell: Vector2i) -> String:
	if not is_instance_valid(_map_view):
		return ""
	var t: int = _map_view.get_ground_layer().get_cell_source_id(Vector2i(cell.x, cell.y))
	# We use the layer's cell atlas coord to read the terrain enum back
	var atlas: Vector2i = _map_view.get_ground_layer().get_cell_atlas_coords(Vector2i(cell.x, cell.y))
	var t_id: int = atlas.y
	if t_id == LocalMapGen.TERRAIN_GROUND:
		return "Ground"
	if t_id == LocalMapGen.TERRAIN_DEBRIS:
		return "Debris"
	if t_id == LocalMapGen.TERRAIN_VEGETATION:
		return "Vegetation"
	if t_id == LocalMapGen.TERRAIN_BLOCKED:
		return "Blocked"
	return ""


func _mob_name_at_cell(cell: Vector2i) -> String:
	# Look up the mob data in GameState by cell, return its sprite_id
	# (placeholder; Phase 3 will look up display names in mobs.json).
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return "Mob"
	var key: String = gs.mob_key(_player_q, _player_r, cell.x, cell.y)
	var mob: Dictionary = gs.get_overworld_mob(key)
	if mob.is_empty():
		return "Mob"
	var sprite_id: String = str(mob.get("sprite_id", mob.get("id", "mob")))
	# Try to load the mob's display name from data/mobs.json
	return _resolve_mob_display_name(sprite_id) + " (Lv.%d)" % int(mob.get("level", 1))


func _resolve_mob_display_name(sprite_id: String) -> String:
	var path := "res://data/mobs.json"
	if not ResourceLoader.exists(path):
		return sprite_id
	var raw = load(path)
	if raw == null:
		return sprite_id
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return sprite_id
	# Search overworld (neutral + aggressive) and rift_only for the sprite_id
	for section in ["overworld", "rift_only"]:
		var bucket = data.get(section, {})
		if bucket is Dictionary:
			for cat in ["neutral", "aggressive"]:
				for m in bucket.get(cat, []):
					if str(m.get("sprite_id", m.get("id", ""))) == sprite_id:
						return str(m.get("name", sprite_id))
		elif bucket is Array:
			for m in bucket:
				if str(m.get("sprite_id", m.get("id", ""))) == sprite_id:
					return str(m.get("name", sprite_id))
	return sprite_id


func _npc_name_at_hex() -> String:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty():
		return "NPC"
	return str(npc.get("name", "NPC"))


func set_character_data(data: Dictionary) -> void:
	_update_char_info(data)


func _setup_map_view() -> void:
	if is_instance_valid(_map_view):
		_map_view.queue_free()
	_map_view = LocalMapViewScene.instantiate()
	_map_view.name = "LocalMapView"
	world_grid.add_child(_map_view)
	if world_grid.get_child_count() > 0:
		world_grid.move_child(_map_view, 0)

	_marker_layer = _map_view.get_marker_layer()
	_mob_layer = _map_view.get_mob_layer()
	_node_layer = _map_view.get_node_layer()
	_pickup_layer = _map_view.get_pickup_layer()


func _setup_player_visual() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var char_data: Dictionary = gs.get_character_data()
	if char_data.is_empty():
		return

	_player_visual = CharacterVisualScript.new() as Node2D
	_player_visual.name = "PlayerVisual"
	world_grid.add_child(_player_visual)

	var race: String = str(char_data.get("race", "human"))
	var gender: String = str(char_data.get("gender", "male"))
	_player_visual.call("set_base_sprite", race, gender)
	_player_visual.position = Vector2(
		_local_x * _map_view.get_cell_size() + _map_view.get_cell_size() * 0.5,
		_local_y * _map_view.get_cell_size() + _map_view.get_cell_size() * 0.5
	)
	_player_visual.z_index = 10
	print("[HubWorld] Player visual set: race=%s gender=%s" % [race, gender])


func _build_local_view() -> void:
	if is_instance_valid(_player_visual):
		var cell_size: int = _map_view.get_cell_size() if is_instance_valid(_map_view) else 24
		_player_visual.position = Vector2(
			_local_x * cell_size + cell_size * 0.5,
			_local_y * cell_size + cell_size * 0.5
		)
	# v0.9.1c: Only refresh markers when the underlying world state
	# actually changed. Walking the player does NOT change which mobs,
	# rifts, or NPCs are on the map. Mobs change when combat ends (in
	# _start_local_combat) or after _seed_local_mobs. Rifts change on
	# the 30s timer in _tick_rifts. NPCs change rarely. Without this
	# guard, every move cost ~25ms to clear-and-rebuild 12 mob sprites
	# + 1-2 rift markers + 1 NPC marker. Now it's free.
	if _world_markers_dirty:
		_refresh_markers()
		_world_markers_dirty = false
	_update_camera()


func _refresh_markers() -> void:
	if is_instance_valid(_marker_layer):
		for child in _marker_layer.get_children():
			child.queue_free()
	_marker_nodes.clear()
	# Clear old mob sprites from world_grid
	for key in _overworld_mobs:
		var entry: Dictionary = _overworld_mobs[key]
		var mob_node: Node2D = entry.get("node") as Node2D
		if is_instance_valid(mob_node):
			mob_node.queue_free()
	_overworld_mobs.clear()
	# Also clear any leftover mob entries in _marker_nodes
	for mkey in _marker_nodes:
		if mkey.begins_with("mob|"):
			var mn: Node2D = _marker_nodes[mkey] as Node2D
			if is_instance_valid(mn):
				mn.queue_free()
			_marker_nodes.erase(mkey)
	var cell_size: int = _map_view.get_cell_size() if is_instance_valid(_map_view) else 24

	# Player visual is handled by _player_visual node — skip circle marker
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	if is_instance_valid(_mission_manager) and _mission_manager.has_method("get_mission_at_tile"):
		var active_mission: Dictionary = _mission_manager.call("get_mission_at_tile", _player_q, _player_r) as Dictionary
		if not active_mission.is_empty():
			var mobj: Dictionary = active_mission.get("objective", {}) as Dictionary
			var mx: int = int(mobj.get("target_local_x", -1))
			var my: int = int(mobj.get("target_local_y", -1))
			if mx >= 0 and my >= 0:
				_add_marker(mx, my, Color(0.5, 0.85, 0.95), "!", "mission", cell_size)

	var all_mobs: Dictionary = gs.get_overworld_mobs()
	var mob_count := 0
	print("[HubWorld] _refresh_markers: %d total mobs in GameState, mob_layer valid=%s" % [all_mobs.size(), is_instance_valid(_mob_layer)])
	for mob_key in all_mobs:
		if not str(mob_key).begins_with("%d,%d|" % [_player_q, _player_r]):
			continue
		var parts: PackedStringArray = str(mob_key).split("|")
		if parts.size() < 2:
			continue
		var local_parts: PackedStringArray = parts[1].split(",")
		if local_parts.size() < 2:
			continue
		var mx := int(local_parts[0])
		var my := int(local_parts[1])
		var mob_data: Dictionary = all_mobs[mob_key] as Dictionary
		var sprite_id: String = str(mob_data.get("sprite_id", mob_data.get("type", "")))
		_add_mob_sprite(mx, my, sprite_id, cell_size, mob_data)
		mob_count += 1

	if is_instance_valid(_rift_runner) and _rift_runner.has_method("get_rifts_in_hex"):
		for rift in _rift_runner.get_rifts_in_hex(_player_q, _player_r, _game_time):
			if not rift is Dictionary:
				continue
			var rd: Dictionary = rift as Dictionary
			_add_marker(
				int(rd.get("local_x", 0)), int(rd.get("local_y", 0)),
				Color(0.75, 0.4, 0.95), "⚡", "rift", cell_size
			)

	var npc: Dictionary = _get_npc_at_hex()
	if not npc.is_empty():
		var npos := _npc_local_position(npc)
		_add_marker(npos.x, npos.y, Color(1.0, 0.85, 0.4), "★", "npc", cell_size)


func _dir_from_dx_dy(dx: int, dy: int) -> int:
	# S=0, SE=1, E=2, NE=3, N=4, NW=5, W=6, SW=7
	if dx == 0 and dy > 0: return 0   # S
	if dx > 0 and dy > 0: return 1    # SE
	if dx > 0 and dy == 0: return 2   # E
	if dx > 0 and dy < 0: return 3    # NE
	if dx == 0 and dy < 0: return 4   # N
	if dx < 0 and dy < 0: return 5    # NW
	if dx < 0 and dy == 0: return 6   # W
	if dx < 0 and dy > 0: return 7    # SW
	return 0


func _reset_to_idle(dir_idx: int) -> void:
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(_player_visual):
		_player_visual.call("play_animation", "idle", dir_idx)


func _add_marker(x: int, y: int, color: Color, symbol: String, kind: String, cell_size: int = 24) -> void:
	if not is_instance_valid(_map_view):
		return
	var node: Node2D = _map_view.call("add_marker", Vector2i(x, y), color, symbol, kind) as Node2D
	if node != null:
		_marker_nodes["%s|%s" % [kind, LocalMapGen.local_key(x, y)]] = node


func _add_mob_sprite(x: int, y: int, sprite_id: String, cell_size: int = 24, mob_data: Dictionary = {}) -> void:
	if sprite_id.is_empty():
		return
	# v0.10.1: Always use MobVisual (proven visible). Store AI state
	# in a plain dictionary alongside the node — avoids OverworldMob
	# tree-entry issues.
	var mob_node: Node2D = MobVisualScript.new()
	mob_node.position = Vector2(x * cell_size + cell_size * 0.5, y * cell_size + cell_size * 0.5)
	mob_node.z_index = 50
	mob_node.set_mob_sprite(sprite_id)
	# Add to mob_layer (y-sorted) so mobs render on top of terrain and
	# stack correctly with the player and each other. Previously this
	# added to world_grid directly which bypassed the y-sort layer.
	if is_instance_valid(_mob_layer):
		_mob_layer.add_child(mob_node)
	else:
		world_grid.add_child(mob_node)
	print("[HubWorld] _add_mob_sprite: id=%s cell=(%d,%d) pos=%s parent=%s visible=%s z=%d" % [
		sprite_id, x, y, str(mob_node.position),
		str(mob_node.get_parent().name) if mob_node.get_parent() else "null",
		str(mob_node.visible), mob_node.z_index
	])

	# Create AI state entry
	var ai: OverworldMobAI = OverworldMobAIScript.new()
	ai.set_grid_pos(x, y)
	ai.seed_from_pos(x, y)
	var mob_type: String = str(mob_data.get("mob_type", "aggressive"))
	ai.aggro_range = int(mob_data.get("aggro_range", 5 if mob_type == "aggressive" else 3))
	ai.mob_type = mob_type

	var entry: Dictionary = {
		"node": mob_node,
		"ai": ai,
		"grid_x": x,
		"grid_y": y,
		"moving": false,
		"tween": null,
		"data": mob_data,
	}
	_overworld_mobs["%d,%d" % [x, y]] = entry
	_marker_nodes["mob|%s" % LocalMapGen.local_key(x, y)] = mob_node


## v0.10.1: Tick all mob AI instances. Each entry is a dictionary with
## node (MobVisual), ai (OverworldMobAI), grid position, movement state.
## When the mob reaches the player's cell, combat starts.
func _tick_overworld_mobs(delta: float) -> void:
	if _overworld_mobs.is_empty():
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var cell_size: int = _map_view.get_cell_size() if is_instance_valid(_map_view) else 24

	var to_remove: Array[String] = []
	for pos_key in _overworld_mobs:
		var entry: Dictionary = _overworld_mobs[pos_key]
		var ai: OverworldMobAI = entry.get("ai") as OverworldMobAI
		var mob_node: Node2D = entry.get("node") as Node2D
		if ai == null or not is_instance_valid(mob_node):
			to_remove.append(pos_key)
			continue
		if entry.get("moving", false):
			continue

		var old_x: int = entry["grid_x"]
		var old_y: int = entry["grid_y"]
		ai.tick(delta, _local_map, _local_x, _local_y, Callable(self, "_is_cell_walkable"))

		match ai.state:
			OverworldMobAI.State.WANDER, OverworldMobAI.State.AGGRO:
				var target: Vector2i = ai._wander_target
				if target.x != old_x or target.y != old_y:
					if _is_cell_walkable(target.x, target.y):
						_start_mob_move(entry, target, cell_size, gs, _player_q, _player_r, old_x, old_y)
					else:
						ai.cancel_movement()
			OverworldMobAI.State.ATTACK:
				if ai.is_at_player(_local_x, _local_y):
					_on_overworld_mob_reached_player(entry.get("data", {}))

	# Clean up invalid entries
	for key in to_remove:
		_overworld_mobs.erase(key)


## Tween a MobVisual node from its current position to a target cell.
func _start_mob_move(entry: Dictionary, target: Vector2i, cell_size: int,
		gs: GameState, hex_q: int, hex_r: int, old_x: int, old_y: int) -> void:
	entry["moving"] = true
	var mob_node: Node2D = entry["node"]
	var target_pos: Vector2 = Vector2(
		target.x * cell_size + cell_size * 0.5,
		target.y * cell_size + cell_size * 0.5
	)

	# Kill old tween
	var old_tween: Tween = entry.get("tween") as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	var tw: Tween = create_tween()
	tw.tween_property(mob_node, "position", target_pos, 0.22).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		entry["moving"] = false
		entry["grid_x"] = target.x
		entry["grid_y"] = target.y
		var ai: OverworldMobAI = entry.get("ai") as OverworldMobAI
		if ai != null:
			if ai.state == OverworldMobAI.State.WANDER:
				ai.confirm_arrival()
			elif ai.state == OverworldMobAI.State.AGGRO:
				ai.set_grid_pos(target.x, target.y)
		# Update GameState
		var new_key: String = gs.mob_key(hex_q, hex_r, target.x, target.y)
		var old_key: String = gs.mob_key(hex_q, hex_r, old_x, old_y)
		if old_key != new_key:
			gs.remove_overworld_mob(old_key)
			var updated: Dictionary = entry["data"].duplicate(true)
			updated["local_x"] = target.x
			updated["local_y"] = target.y
			gs.set_overworld_mob(new_key, updated)
			entry["data"] = updated
	)
	entry["tween"] = tw


## v0.10.0: Called when an OverworldMob reaches the player's cell.
## Starts tactical combat with that mob.
func _on_overworld_mob_reached_player(mob_data: Dictionary) -> void:
	# Prevent combat while a UI overlay is open or already in combat
	if _is_ui_overlay_open() or get_tree().paused:
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	var lx: int = int(mob_data.get("local_x", _local_x))
	var ly: int = int(mob_data.get("local_y", _local_y))
	var tile_key := "%d,%d|%d,%d" % [_player_q, _player_r, lx, ly]
	var char_data: Dictionary = gs.get_party_character_data()
	var em: EquipmentManager = get_node_or_null("/root/EquipmentManager") as EquipmentManager
	var equip_stats: Dictionary = em.get_combat_stats("player") if is_instance_valid(em) else {}
	var biome: String = str(_tile_map.get("%d,%d" % [_player_q, _player_r], {}).get("name", "Ash Wastes"))

	var encounter: Dictionary = EncounterBuilder.build_overworld(char_data, mob_data, tile_key, biome, equip_stats)
	if encounter.is_empty():
		return

	# Remove mob from GameState (combat consumes it)
	gs.remove_overworld_mob(gs.mob_key(_player_q, _player_r, lx, ly))
	_mark_world_markers_dirty()

	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_tactical_combat(encounter)


func _update_camera() -> void:
	if is_instance_valid(camera) and is_instance_valid(_map_view):
		var cell_size: int = _map_view.get_cell_size()
		camera.position = Vector2(
			_local_x * cell_size + cell_size * 0.5,
			_local_y * cell_size + cell_size * 0.5,
		)


func _try_move_local(dx: int, dy: int) -> void:
	var nx := _local_x + dx
	var ny := _local_y + dy
	var map_size: int = int(_local_map.get("size", LocalMapGen.MAP_SIZE))

	if nx < 0 or ny < 0 or nx >= map_size or ny >= map_size:
		_try_cross_edge(dx, dy)
		return

	if not _is_cell_walkable(nx, ny):
		return

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var mob: Dictionary = gs.get_local_mob(_player_q, _player_r, nx, ny)
		if not mob.is_empty():
			var mission: Dictionary = {}
			if is_instance_valid(_mission_manager) and _mission_manager.has_method("should_block_move_for_mission"):
				mission = _mission_manager.call(
					"should_block_move_for_mission", "%d,%d" % [_player_q, _player_r], nx, ny
				) as Dictionary
			_start_local_combat(nx, ny, mob, mission)
			return

	_local_x = nx
	_local_y = ny
	if is_instance_valid(gs):
		gs.set_local_position(_local_x, _local_y)
		_mark_explored(gs)

	if is_instance_valid(_player_visual):
		var dir_idx: int = _dir_from_dx_dy(dx, dy)
		_player_visual.call("play_animation", "walk", dir_idx)
		# Return to idle after brief walk frame cycle
		_reset_to_idle(dir_idx)

	# Phase 1: auto-collect any floor pickup at the new cell.
	var pickup_info: Dictionary = _try_collect_floor_pickup_at(_local_x, _local_y)
	# Phase 8: spawn a loot popup at the pickup location
	if not pickup_info.is_empty():
		_spawn_loot_popup("+%d x %s" % [pickup_info.get("qty", 1), pickup_info.get("item_id", "?")], Vector2.ZERO)

	_build_local_view()
	_update_tile_info()
	_update_rift_ui()
	_update_npc_ui()
	_update_mission_ui()


func _is_cell_walkable(x: int, y: int) -> bool:
	return LocalMapGen.is_walkable(_local_map, x, y)


# ---------------------------------------------------------------------------
# Phase 1: Floor pickups (sticks, stones)
# ---------------------------------------------------------------------------

func _try_collect_floor_pickup_at(x: int, y: int) -> Dictionary:
	if not is_instance_valid(_map_view):
		return {}
	var pickup: Node2D = _map_view.get_floor_pickup_at(Vector2i(x, y))
	if pickup == null:
		return {}
	var item_id: String = pickup.get_item_id()
	var qty: int = pickup.get_item_qty()
	if item_id.is_empty() or qty <= 0:
		return {}
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv == null:
		push_warning("[HubWorld] No InventoryManager; pickup dropped on the floor.")
		return {}
	inv.add_item(item_id, qty)
	# v0.10.0: hide the MultiMesh visual for this pickup.
	var cell: Vector2i = Vector2i(x, y)
	_map_view.hide_pickup_visual(cell)
	print("[HubWorld] Picked up %d x %s" % [qty, item_id])
	return {"item_id": item_id, "qty": qty}


# ---------------------------------------------------------------------------
# Phase 1: Resource node gathering (E key)
# ---------------------------------------------------------------------------

# Currently equipped MainHand tool. Phase 1 placeholder; real tool
# tracking lands in Phase 4 with EquipmentManager.
func set_equipped_tool(tool_data: Dictionary) -> void:
	_equipped_tool = tool_data


func get_equipped_tool() -> Dictionary:
	return _resolve_hotbar_tool()


## Read the hotbar's currently selected item_id, look it up in
## data/tools.json, and return the tool's data dict. Returns empty
## dict if no item is selected or the item isn't a known tool.
func _resolve_hotbar_tool() -> Dictionary:
	if not is_instance_valid(_hud):
		return _equipped_tool
	var hb: Hotbar = _hud.get_hotbar() if _hud.has_method("get_hotbar") else null
	if hb == null or not is_instance_valid(hb):
		return _equipped_tool
	var item_id: String = str(hb.get_slot(hb.get_selected_index()))
	if item_id.is_empty():
		return {}
	# Look up the tool definition in data/tools.json
	var path := "res://data/tools.json"
	if not ResourceLoader.exists(path):
		return {}
	var raw = load(path)
	if raw == null:
		return {}
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return {}
	for t in data.get("tools", []):
		if str(t.get("id", "")) == item_id:
			return t
	return {}


func _try_start_gather() -> void:
	if is_instance_valid(_gathering_node) and _gathering_node != null:
		# Already gathering — E is a no-op (or could cancel; we no-op for now)
		return
	if not is_instance_valid(_map_view):
		return

	var player_cell := Vector2i(_local_x, _local_y)
	# Look for any HarvestNode within GATHER_RANGE_CELLS (adjacent).
	var candidates: Array = _map_view.get_resource_nodes_near(player_cell, GATHER_RANGE_CELLS)
	if candidates.is_empty():
		# Nothing to gather; show a brief message
		print("[HubWorld] No resource nodes adjacent to gather.")
		return
	# Pick the closest one
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var entry: Dictionary = candidates[0]
	var node: Node2D = entry["node"]

	# Try to gather. Pull the equipped tool from the hotbar if any.
	# Phase 1 (no EquipmentManager): the hotbar's selected slot holds an
	# item_id; we look it up in data/tools.json for the actual tool data.
	# If no tool is in the hotbar (or it's not a known tool), fall back
	# to bare hands (Phase 1 permissiveness — Phase 4 will gate this).
	var tool: Dictionary = _resolve_hotbar_tool()
	if tool.is_empty():
		# Bare hands cannot harvest resource nodes. Only sticks and stones
		# (FloorPickups) are gatherable without a tool — those auto-collect
		# on walk. E on a HarvestNode with no tool shows "wrong tool".
		tool = {"speed_mult": 1.0, "harvests": [], "name": "(bare hands)"}

	var result: Dictionary = node.try_gather(tool)
	if not bool(result.get("ok", false)):
		# Reason codes: "no_tool" / "wrong_tool" / "depleted" / "decoration"
		var reason: String = str(result.get("reason", ""))
		print("[HubWorld] Cannot gather %s: %s" % [node.get_node_id(), reason])
		return

	_gathering_node = node
	_gather_total = float(result.get("secs", 1.0))
	_gather_timer = _gather_total
	_gather_yield_preview = {
		"yield_item": str(result.get("yield_item", "")),
		"yield_qty": int(result.get("yield_qty", 0)),
	}
	print("[HubWorld] Gathering %s... (%.1fs, will yield %d x %s)" % [
		node.get_node_id(), _gather_total,
		int(_gather_yield_preview.get("yield_qty", 0)),
		str(_gather_yield_preview.get("yield_item", "")),
	])


func _tick_gather(delta: float) -> void:
	if not is_instance_valid(_gathering_node):
		return
	_gather_timer -= delta
	if _gather_timer > 0.0:
		return
	# Award yield and deplete node.
	var node: Node2D = _gathering_node
	_gathering_node = null
	_gather_timer = 0.0
	if not is_instance_valid(node):
		return
	var item_id: String = str(_gather_yield_preview.get("yield_item", ""))
	var qty: int = int(_gather_yield_preview.get("yield_qty", 0))
	if item_id.is_empty() or qty <= 0:
		return
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv == null:
		push_warning("[HubWorld] No InventoryManager; gather dropped on the floor.")
		return
	inv.add_item(item_id, qty)
	node.deplete()
	# v0.10.0: dim the MultiMesh visual for this node.
	if is_instance_valid(_map_view):
		var cell: Vector2i = node.get_cell(_map_view.get_cell_size())
		_map_view.dim_resource_node(cell, true)
	# v0.9.1c: track this node for active respawn ticking.
	# The deferred_remove trick below handles the case where the node
	# was queue_freed during the same frame (e.g. the player reloads).
	if is_instance_valid(node) and not _active_respawn_nodes.has(node):
		_active_respawn_nodes.append(node)
	print("[HubWorld] Gathered %d x %s from %s" % [qty, item_id, node.get_node_id()])


## v0.9.1c: Tick only the small list of currently-depleted HarvestNodes.
## Replaces the previous full scan of all 16k+ resource nodes per frame.
## When a depleted node finishes its respawn timer, remove it from the list.
func _tick_active_respawn_nodes(delta: float) -> void:
	if _active_respawn_nodes.is_empty():
		return
	# Iterate backwards so we can remove in-place
	for i in range(_active_respawn_nodes.size() - 1, -1, -1):
		var node: Node = _active_respawn_nodes[i]
		if not is_instance_valid(node):
			_active_respawn_nodes.remove_at(i)
			continue
		# HarvestNode._process decrements _respawn_remaining and sets
		# _depleted = false when it hits 0. The node itself stays in
		# the scene tree the whole time.
		node._process(delta)
		if not is_instance_valid(node):
			_active_respawn_nodes.remove_at(i)
			continue
		# Check the depleted flag — if it flipped to false, respawn done.
		# (We access _depleted via a duck-typed check because HarvestNode
		# has it as a private var; Godot allows it via get()).
		if bool(node.get("_depleted")) == false:
			# v0.10.0: restore the MultiMesh visual.
			if is_instance_valid(_map_view) and is_instance_valid(node):
				var cell: Vector2i = node.get_cell(_map_view.get_cell_size())
				_map_view.dim_resource_node(cell, false)
			_active_respawn_nodes.remove_at(i)


func _try_cross_edge(dx: int, dy: int) -> void:
	var edge := LocalMapGen.edge_from_delta(dx, dy)
	if edge < 0:
		return
	var neighbor: Vector2i = LocalMapGen.get_neighbor_hex(_player_q, _player_r, edge)
	var nkey := LocalMapGen.hex_key(neighbor.x, neighbor.y)
	if not _tile_map.has(nkey):
		print("[HubWorld] No adjacent region at edge.")
		return

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return

	var opposite_edge := -1
	match edge:
		LocalMapGen.EDGE_NORTH:
			opposite_edge = LocalMapGen.EDGE_SOUTH
		LocalMapGen.EDGE_SOUTH:
			opposite_edge = LocalMapGen.EDGE_NORTH
		LocalMapGen.EDGE_EAST:
			opposite_edge = LocalMapGen.EDGE_WEST
		LocalMapGen.EDGE_WEST:
			opposite_edge = LocalMapGen.EDGE_EAST

	gs.travel_to_hex(neighbor.x, neighbor.y, opposite_edge)
	_player_q = neighbor.x
	_player_r = neighbor.y
	_local_map = gs.get_current_hex_state()
	var local_pos: Vector2i = gs.get_local_position()
	_local_x = local_pos.x
	_local_y = local_pos.y

	if is_instance_valid(_mission_manager) and _mission_manager.has_method("report_tile_visit"):
		_mission_manager.call("report_tile_visit", _player_q, _player_r)

	_local_map = gs.get_current_hex_state()
	_seed_local_mobs()
	# v0.9.1c: Force marker refresh — new hex has new mobs.
	_mark_world_markers_dirty()
	_build_local_view()
	_update_tile_info()
	_update_rift_ui()
	_update_npc_ui()
	_update_mission_ui()
	# Audio: re-evaluate ambient bed for the new biome.
	_start_audio_for_current_region()
	print("[HubWorld] Crossed to region (%d, %d) at local (%d, %d)" % [_player_q, _player_r, _local_x, _local_y])


func _mark_explored(gs: GameState) -> void:
	var state: Dictionary = gs.get_current_hex_state()
	if state.is_empty():
		return
	var explored: float = float(state.get("explored_pct", 0.0))
	state["explored_pct"] = minf(explored + 0.02, 1.0)
	gs.save_hex_state(_player_q, _player_r, state)
	_local_map = state


func _update_tile_info() -> void:
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	var biome: String = str(tile.get("name", _local_map.get("biome", "?")))
	var terrain: int = LocalMapGen.get_terrain(_local_map, _local_x, _local_y)
	var explored: float = float(_local_map.get("explored_pct", 0.0)) * 100.0
	# v0.9.1: surface mob count + nearby-mob hint so the player knows
	# where to walk to find a fight. The minimap now shows mob dots
	# but the tile info label is the in-world overlay.
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	var mob_count: int = 0
	var nearest_mob_dist: int = -1
	if is_instance_valid(gs):
		var all_mobs: Dictionary = gs.get_overworld_mobs()
		var prefix: String = "%d,%d|" % [_player_q, _player_r]
		for mob_key in all_mobs.keys():
			if not str(mob_key).begins_with(prefix):
				continue
			mob_count += 1
			var rest: String = str(mob_key).substr(prefix.length())
			var parts: PackedStringArray = rest.split(",")
			if parts.size() < 2:
				continue
			var d: int = abs(int(parts[0]) - _local_x) + abs(int(parts[1]) - _local_y)
			if nearest_mob_dist < 0 or d < nearest_mob_dist:
				nearest_mob_dist = d
	var mob_line: String = ""
	if mob_count > 0:
		var dist_str: String = str(nearest_mob_dist) + " cells away" if nearest_mob_dist > 0 else "ADJACENT — walk into one"
		mob_line = "\n[color=#ff8a65][b]%d mob(s)[/b][/color] in this region. Nearest: %s." % [mob_count, dist_str]
	tile_info_label.text = (
		"[b]Region (%d,%d)[/b] — [color=#c8e6c9]%s[/color]\n" % [_player_q, _player_r, biome] +
		"Local pos: (%d, %d) | Terrain: %s | Explored: %.0f%%%s\n" % [
			_local_x, _local_y, LocalMapGen.terrain_label(terrain), explored, mob_line,
		] +
		"[i]WASD to walk. Step onto a mob to fight. ⚡ = rift entrance. [b]M[/b] = World Map.[/i]"
	)


## Start the audio bed for the current hex. Safe to call from
## `_ready` (no-op if the player isn't in a region yet) and from
## `_try_cross_edge` after the local map swaps.
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


func _tick_rifts() -> void:
	if not is_instance_valid(_rift_runner):
		return
	if _rift_runner.has_method("prune_expired_rifts"):
		var removed: int = _rift_runner.prune_expired_rifts(_game_time)
		if removed > 0:
			print("[HubWorld] %d rift(s) collapsed." % removed)

	if _rift_runner.has_method("try_spawn_local_rift"):
		var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
		var spawned: Dictionary = _rift_runner.try_spawn_local_rift(
			_player_q, _player_r, str(tile.get("name", "Ash Wastes")), _local_map, _game_time
		)
		if not spawned.is_empty():
			print("[HubWorld] Rift spawned at local (%d,%d)" % [spawned.get("local_x", 0), spawned.get("local_y", 0)])
			_mark_world_markers_dirty()

	_build_local_view()
	_update_rift_ui()


func _spawn_initial_rift_if_needed() -> void:
	if not is_instance_valid(_rift_runner):
		return
	if _rift_runner.has_method("get_rifts_in_hex"):
		var existing: Array = _rift_runner.get_rifts_in_hex(_player_q, _player_r, _game_time)
		if not existing.is_empty():
			return
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	if _rift_runner.has_method("add_rift_entrance"):
		var rng := RandomNumberGenerator.new()
		var gs_rift: GameState = get_node_or_null("/root/GameState") as GameState
		var seed_for_rift: String = str(gs_rift.get_world_data().get("seed", "start")) if is_instance_valid(gs_rift) else "start"
		rng.seed = LocalMapGen.hash_seed(LocalMapGen.make_local_seed(seed_for_rift, _player_q, _player_r))
		# v0.9.1: Spawn the rift 4-12 cells from the player (was 8-20)
		# so the ⚡ glyph is reliably visible from spawn in the camera
		# view (which is ~26 cells wide). The player doesn't have to
		# walk blindly hoping to find the entrance.
		var lx := rng.randi_range(_local_x + 4, _local_x + 12)
		var ly := rng.randi_range(_local_y - 5, _local_y + 5)
		# Clamp to map bounds
		lx = clampi(lx, 4, LocalMapGen.MAP_SIZE - 4)
		ly = clampi(ly, 4, LocalMapGen.MAP_SIZE - 4)
		_rift_runner.add_rift_entrance(
			_player_q, _player_r,
			str(tile.get("name", "Ash Wastes")),
			600.0, "", null, lx, ly
		)
	_build_local_view()
	_update_rift_ui()


func _get_rift_at_player() -> Dictionary:
	if not is_instance_valid(_rift_runner) or not _rift_runner.has_method("get_rift_at_local"):
		return {}
	return _rift_runner.get_rift_at_local(_player_q, _player_r, _local_x, _local_y, _game_time)


func _update_rift_ui() -> void:
	var rift: Dictionary = _get_rift_at_player()
	var on_rift := not rift.is_empty()

	if is_instance_valid(_enter_btn):
		_enter_btn.disabled = not on_rift
		_enter_btn.text = "▶ ENTER RIFT" if on_rift else "▶ NO RIFT HERE"

	if on_rift:
		var remaining: float = float(rift.get("duration", 0.0)) - (_game_time - float(rift.get("spawn_time", 0.0)))
		rift_info_label.text = (
			"[color=#e1bee7][b]RIFT TUNNEL ACTIVE[/b][/color] — %s\n" % rift.get("rift_id", "?") +
			"Local (%d,%d) | ~%d min left" % [
				int(rift.get("local_x", 0)), int(rift.get("local_y", 0)),
				maxi(0, int(remaining / 60.0)),
			]
		)
	else:
		var count := 0
		if is_instance_valid(_rift_runner) and _rift_runner.has_method("get_rifts_in_hex"):
			count = (_rift_runner.get_rifts_in_hex(_player_q, _player_r, _game_time) as Array).size()
		rift_info_label.text = "[i]%d rift(s) in this region. Walk onto ⚡ to enter.[/i]" % count


func _update_char_info(data: Dictionary) -> void:
	var char_name: String = str(data.get("name", data.get("id", "???")))
	var race: String = str(data.get("race", "???"))
	var cls: String = str(data.get("class", "???"))
	var lvl: int = int(data.get("level", 1))
	var xp: int = int(data.get("xp", 0))
	char_label.text = "[b]%s[/b] — %s / %s  [color=#fff59d]Lv.%d[/color] (%d XP)  [color=#90caf9]Local Map[/color]" % [
		char_name, race, cls, lvl, xp,
	]


func _append_start_info(start: Dictionary) -> void:
	var biome: String = str(start.get("name", "Unknown"))
	var extra := RichTextLabel.new()
	extra.name = "StartInfoLabel"
	extra.bbcode_enabled = true
	extra.fit_content = true
	extra.text = "[i]Homestead region: %s (%s) — 512×512 local playfield[/i]" % [biome, start.get("key", "?")]
	$CharInfoBar.add_child(extra)


func _on_enter_rift_pressed() -> void:
	var rift: Dictionary = _get_rift_at_player()
	if rift.is_empty():
		return
	var rift_id: String = str(rift.get("rift_id", "rift_0001"))
	var biome: String = str(rift.get("biome_key", "Ash Wastes"))
	enter_rift_requested.emit(rift_id)
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		rift["entry_q"] = _player_q
		rift["entry_r"] = _player_r
		rift["entry_local_x"] = _local_x
		rift["entry_local_y"] = _local_y
		# Phase F: Fade transition
		if is_instance_valid(_transition_screen):
			await _transition_screen.fade_out(0.4)
		gm.go_to_rift(rift_id, biome, rift)
	# v0.9.1c: leaving for the rift scene — markers will be rebuilt
	# when we return. No dirty flag needed here since we're swapping
	# scenes, but we clear the dirty bit to keep state clean.
	_world_markers_dirty = false


func _on_world_map_pressed() -> void:
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		# Phase F: Fade transition
		if is_instance_valid(_transition_screen):
			await _transition_screen.fade_out(0.4)
		gm.go_to_world_map()


func _setup_mission_ui() -> void:
	var panel: VBoxContainer = $TileInfoPanel as VBoxContainer
	if not is_instance_valid(panel):
		return
	_mission_info_label = RichTextLabel.new()
	_mission_info_label.name = "MissionInfoLabel"
	_mission_info_label.bbcode_enabled = true
	_mission_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_info_label.fit_content = true
	_mission_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_mission_info_label)

	var bottom: HBoxContainer = $BottomBar as HBoxContainer
	if is_instance_valid(bottom):
		_mission_btn = Button.new()
		_mission_btn.name = "AcceptMission"
		_mission_btn.custom_minimum_size = Vector2(170, 45)
		_mission_btn.text = "◆ ACCEPT JOB"
		_mission_btn.disabled = true
		_mission_btn.pressed.connect(_on_accept_mission_pressed)
		bottom.add_child(_mission_btn)
		bottom.move_child(_mission_btn, 0)


func _setup_npc_ui() -> void:
	var panel: VBoxContainer = $TileInfoPanel as VBoxContainer
	if not is_instance_valid(panel):
		return
	_npc_info_label = RichTextLabel.new()
	_npc_info_label.name = "NpcInfoLabel"
	_npc_info_label.bbcode_enabled = true
	_npc_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npc_info_label.fit_content = true
	_npc_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_npc_info_label)

	var bottom: HBoxContainer = $BottomBar as HBoxContainer
	if is_instance_valid(bottom):
		_recruit_btn = Button.new()
		_recruit_btn.name = "RecruitNpc"
		_recruit_btn.custom_minimum_size = Vector2(160, 45)
		_recruit_btn.text = "★ RECRUIT"
		_recruit_btn.disabled = true
		_recruit_btn.pressed.connect(_on_recruit_pressed)
		bottom.add_child(_recruit_btn)
		bottom.move_child(_recruit_btn, 0)


func _ensure_world_npcs() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs) or not gs.get_world_npcs().is_empty():
		return
	if not is_instance_valid(_npc_manager) or not _npc_manager.has_method("generate_for_world"):
		return
	var wd: Dictionary = gs.get_world_data()
	var seed_str: String = str(wd.get("seed", ""))
	var start: Dictionary = gs.get_start_tile()
	var start_key: String = str(start.get("key", "%d,%d" % [_player_q, _player_r]))
	if seed_str.is_empty() or _tile_map.is_empty():
		return
	_npc_manager.call("generate_for_world", seed_str, _tile_map, start_key)


func _npc_local_position(npc: Dictionary) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(str(npc.get("id", "npc")).hash())
	var base := Vector2i(int(LocalMapGen.MAP_SIZE / 2.0), int(LocalMapGen.MAP_SIZE / 2.0))
	return Vector2i(
		clampi(base.x + rng.randi_range(-40, 40), 8, LocalMapGen.MAP_SIZE - 8),
		clampi(base.y + rng.randi_range(-40, 40), 8, LocalMapGen.MAP_SIZE - 8),
	)


func _get_npc_at_hex() -> Dictionary:
	if not is_instance_valid(_npc_manager) or not _npc_manager.has_method("get_npc_at_tile"):
		return {}
	return _npc_manager.call("get_npc_at_tile", "%d,%d" % [_player_q, _player_r]) as Dictionary


func _is_near_npc() -> bool:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty():
		return false
	var npos := _npc_local_position(npc)
	return abs(npos.x - _local_x) <= 2 and abs(npos.y - _local_y) <= 2


func _update_npc_ui() -> void:
	if not is_instance_valid(_npc_info_label):
		return
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty() or not _is_near_npc():
		_npc_info_label.text = ""
		if is_instance_valid(_recruit_btn):
			_recruit_btn.disabled = true
		if is_instance_valid(_mission_btn):
			_mission_btn.disabled = true
			_mission_btn.text = "◆ NO JOBS"
		return

	_refresh_npc_mission_offers(npc)
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	var char_data: Dictionary = gs.get_character_data() if is_instance_valid(gs) else {}
	var check: Dictionary = {}
	if is_instance_valid(_npc_manager) and _npc_manager.has_method("can_recruit"):
		check = _npc_manager.call("can_recruit", str(npc.get("id", "")), char_data) as Dictionary

	_npc_info_label.text = (
		"[color=#ffe082][b]★ %s[/b][/color] — %s (%s)\n[i]%s[/i]" % [
			npc.get("name", "?"), npc.get("role", "?"), npc.get("faction", "?"),
			npc.get("personality_summary", ""),
		]
	)
	if is_instance_valid(_recruit_btn):
		_recruit_btn.disabled = not bool(check.get("ok", false))
		_recruit_btn.text = "★ RECRUIT" if bool(check.get("ok", false)) else "★ LOCKED"
	_update_mission_offer_button(npc)


func _on_recruit_pressed() -> void:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty() or not is_instance_valid(_npc_manager):
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(_npc_manager) and _npc_manager.has_method("recruit_npc"):
		if _npc_manager.call("recruit_npc", str(npc.get("id", "")), gs.get_character_data()):
			if is_instance_valid(gs):
				gs.sync_party_companions()
			_build_local_view()
			_update_npc_ui()
			_update_char_info(gs.get_party_character_data())


# v0.9.1c: Helper called whenever the mob/rift/NPC set changes.
# Skips the per-move marker rebuild unless something actually moved.
func _mark_world_markers_dirty() -> void:
	_world_markers_dirty = true


func _seed_local_mobs() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
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

	print("[HubWorld] Mob seed: biome=%s tier=%d danger=%.2f total_attempts=%d seeded=%d (blocked=%d near=%d dup=%d no_enemy=%d) at q,r=%d,%d" % [
		biome, int(tile.get("difficulty_tier", 0)), danger, count + 2, seeded, skipped_blocked, skipped_near, skipped_duplicate, skipped_no_enemy,
		_player_q, _player_r
	])


func _start_local_combat(lx: int, ly: int, mob: Dictionary, mission: Dictionary = {}) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var tile: Dictionary = _tile_map.get("%d,%d" % [_player_q, _player_r], {})
	var biome: String = str(tile.get("name", "Ash Wastes"))
	var tile_key := "%d,%d|%d,%d" % [_player_q, _player_r, lx, ly]
	var char_data: Dictionary = gs.get_party_character_data()
	# Compute equipment-derived combat stats for the encounter
	var em: EquipmentManager = get_node_or_null("/root/EquipmentManager") as EquipmentManager
	var equip_stats: Dictionary = em.get_combat_stats("player") if is_instance_valid(em) else {}
	var encounter: Dictionary = {}
	var mission_id: String = str(mob.get("mission_id", mission.get("mission_id", "")))
	if not mission_id.is_empty() and is_instance_valid(_mission_manager) and _mission_manager.has_method("build_mission_encounter"):
		encounter = _mission_manager.call("build_mission_encounter", mission_id, char_data, equip_stats) as Dictionary
	if encounter.is_empty():
		encounter = EncounterBuilder.build_overworld(char_data, mob, tile_key, biome, equip_stats)
	# v0.9.1c: mark markers dirty so the mob we just walked into is
	# removed from the overworld view (combat consumes the mob).
	_mark_world_markers_dirty()
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_tactical_combat(encounter)


func _refresh_npc_mission_offers(npc: Dictionary) -> void:
	if not is_instance_valid(_mission_manager) or not _mission_manager.has_method("refresh_npc_offers"):
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	_mission_manager.call(
		"refresh_npc_offers",
		str(npc.get("id", "")), npc,
		str(gs.get_world_data().get("seed", "")),
		_tile_map, _player_q, _player_r, gs.get_party_character_data()
	)


func _update_mission_offer_button(npc: Dictionary) -> void:
	if not is_instance_valid(_mission_btn) or not is_instance_valid(_mission_manager):
		return
	var offers: Array = _mission_manager.call("get_offers_for_npc", str(npc.get("id", ""))) if _mission_manager.has_method("get_offers_for_npc") else []
	var can_accept: bool = _mission_manager.call("has_active_capacity") if _mission_manager.has_method("has_active_capacity") else false
	_mission_btn.disabled = offers.is_empty() or not can_accept or not _is_near_npc()
	_mission_btn.text = "◆ ACCEPT JOB" if not offers.is_empty() else "◆ NO JOBS"


func _update_mission_ui() -> void:
	if not is_instance_valid(_mission_info_label) or not is_instance_valid(_mission_manager):
		return
	var active: Array = _mission_manager.call("get_active_missions") if _mission_manager.has_method("get_active_missions") else []
	if active.is_empty():
		_mission_info_label.text = "[i]No active missions. Visit ★ settlements on the World Map.[/i]"
		return
	var lines: PackedStringArray = ["[color=#80cbc4][b]ACTIVE MISSIONS[/b][/color]"]
	for mission in active:
		if mission is Dictionary:
			var m: Dictionary = mission as Dictionary
			lines.append("• %s" % m.get("title", "?"))
	_mission_info_label.text = "\n".join(lines)


func _on_accept_mission_pressed() -> void:
	var npc: Dictionary = _get_npc_at_hex()
	if npc.is_empty() or not is_instance_valid(_mission_manager):
		return
	var offers: Array = _mission_manager.call("get_offers_for_npc", str(npc.get("id", ""))) if _mission_manager.has_method("get_offers_for_npc") else []
	if offers.is_empty():
		return
	var offer: Dictionary = offers[0] as Dictionary
	var mid: String = str(offer.get("mission_id", ""))
	if _mission_manager.has_method("accept_mission"):
		_mission_manager.call("accept_mission", mid, _game_time)
	_update_mission_ui()


func _tick_missions() -> void:
	if is_instance_valid(_mission_manager) and _mission_manager.has_method("tick_expired"):
		if int(_mission_manager.call("tick_expired", _game_time)) > 0:
			_update_mission_ui()


func _on_back_to_menu_pressed() -> void:
	back_to_menu_requested.emit()
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_menu()



func _save_to_autoslot_if_can() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs) or gs.get_character_data().is_empty():
		return
	# Trigger a save to autoslot (slot 0)
	gs.save_game(0)
	print("[HubWorld] Saved to autoslot on entry.")


func _on_equipment_changed(npc_id: String, slot: String) -> void:
	if npc_id != "player":
		return
	if not is_instance_valid(_player_visual):
		return
	var em: EquipmentManager = get_node_or_null("/root/EquipmentManager") as EquipmentManager
	if is_instance_valid(em):
		var equip: Dictionary = em.get_equipment("player")
		_player_visual.call("update_equipment", equip)


func _on_save_pressed() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs) or not _save_btn:
		return
	var success: bool = gs.save_game(0)
	_save_btn.text = "SAVED!" if success else "FAILED"
	_save_btn.disabled = true
	await get_tree().create_timer(1.5).timeout
	if _save_btn:
		_save_btn.text = "SAVE"
		_save_btn.disabled = false


func _toggle_pause_menu() -> void:
	if is_instance_valid(_pause_menu) and _pause_menu.visible:
		_pause_menu.close()
		return
	if not is_instance_valid(_pause_menu):
		var scene: PackedScene = load("res://scenes/ui/PauseMenu.tscn") as PackedScene
		if is_instance_valid(scene):
			_pause_menu = scene.instantiate() as PauseMenu
			var layer := CanvasLayer.new()
			layer.name = "PauseMenuLayer"
			layer.layer = 100
			add_child(layer)
			layer.add_child(_pause_menu)
	if is_instance_valid(_pause_menu):
		_pause_menu.open()
