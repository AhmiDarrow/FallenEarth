## OverworldInteractionManager — Player interaction functions extracted from HubWorld.
## Handles: gathering, tool management, settlements, base placement, cooking tables,
## floor pickups, loot popups, and UI overlay checks.
class_name OverworldInteractionManager extends Node

const GATHER_RANGE_CELLS := 1

const LocalMapGen = preload("res://scripts/LocalMapGenerator.gd")
const HarvestNodeScript = preload("res://scripts/HarvestNode.gd")
const LootPopupScript = preload("res://scripts/ui/LootPopup.gd")
const LootPopupScene = preload("res://scenes/ui/LootPopup.tscn")
const BaseNodeScene = preload("res://scenes/BaseNode.tscn")
const BaseScene = preload("res://scenes/Base.tscn")

var _hw: HubWorld


# ---------------------------------------------------------------------------
# Phase 1: Resource node gathering
# ---------------------------------------------------------------------------

## True if there's a HarvestNode adjacent to the player that the
## current tool can gather. Used to disambiguate the E key (gather vs
## open Equipment tab).
func _has_adjacent_harvest_node() -> bool:
	if not is_instance_valid(_hw._map_view):
		return false
	var nodes: Array = _hw._map_view.get_resource_nodes_near(
		Vector2i(_hw._local_x, _hw._local_y), GATHER_RANGE_CELLS
	)
	return not nodes.is_empty()


func _try_start_gather() -> void:
	if is_instance_valid(_hw._gathering_node) and _hw._gathering_node != null:
		# Already gathering — E is a no-op (or could cancel; we no-op for now)
		return
	if not is_instance_valid(_hw._map_view):
		return

	var player_cell := Vector2i(_hw._local_x, _hw._local_y)
	# Look for any HarvestNode within GATHER_RANGE_CELLS (adjacent).
	var candidates: Array = _hw._map_view.get_resource_nodes_near(player_cell, GATHER_RANGE_CELLS)
	if candidates.is_empty():
		# Nothing to gather; show a brief message
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
		_notify_gather_failure(node, result)
		return

	_begin_gather(node, result)


func _tick_gather(delta: float) -> void:
	if not is_instance_valid(_hw._gathering_node):
		return
	_hw._gather_timer -= delta
	if _hw._gather_timer > 0.0:
		return
	# Award yield and deplete node.
	var node: Node2D = _hw._gathering_node
	_hw._gathering_node = null
	_hw._gather_timer = 0.0
	if not is_instance_valid(node):
		return
	var item_id: String = str(_hw._gather_yield_preview.get("yield_item", ""))
	var qty: int = int(_hw._gather_yield_preview.get("yield_qty", 0))
	if item_id.is_empty() or qty <= 0:
		return
	var inv: Node = get_node_or_null("/root/InventoryHandler")
	if inv == null:
		push_warning("[HubWorld] No InventoryHandler; gather dropped on the floor.")
		return
	inv.add_item(item_id, qty)
	node.deplete()
	# v0.10.0: dim the MultiMesh visual for this node.
	if is_instance_valid(_hw._map_view):
		var cell: Vector2i = node.get_cell(_hw._map_view.get_cell_size())
		_hw._map_view.dim_resource_node(cell, true)
		# Allow walking through depleted nodes until they respawn.
		LocalMapGen.set_entity_blocked(_hw._local_map, cell.x, cell.y, false)
	_show_gather_toast("+%d %s" % [qty, item_id])
	# v0.9.1c: track this node for active respawn ticking.
	# The deferred_remove trick below handles the case where the node
	# was queue_freed during the same frame (e.g. the player reloads).
	if is_instance_valid(node) and not _hw._active_respawn_nodes.has(node):
		_hw._active_respawn_nodes.append(node)


## v0.9.1c: Tick only the small list of currently-depleted HarvestNodes.
## Replaces the previous full scan of all 16k+ resource nodes per frame.
## When a depleted node finishes its respawn timer, remove it from the list.
func _tick_active_respawn_nodes(delta: float) -> void:
	if _hw._active_respawn_nodes.is_empty():
		return
	# Iterate backwards so we can remove in-place
	for i in range(_hw._active_respawn_nodes.size() - 1, -1, -1):
		var node: Node = _hw._active_respawn_nodes[i]
		if not is_instance_valid(node):
			_hw._active_respawn_nodes.remove_at(i)
			continue
		# HarvestNode._process decrements _respawn_remaining and sets
		# _depleted = false when it hits 0. The node itself stays in
		# the scene tree the whole time.
		node._process(delta)
		if not is_instance_valid(node):
			_hw._active_respawn_nodes.remove_at(i)
			continue
		# Check the depleted flag — if it flipped to false, respawn done.
		# (We access _depleted via a duck-typed check because HarvestNode
		# has it as a private var; Godot allows it via get()).
		if bool(node.get("_depleted")) == false:
			# v0.10.0: restore the MultiMesh visual + collision.
			if is_instance_valid(_hw._map_view) and is_instance_valid(node):
				var cell: Vector2i = node.get_cell(_hw._map_view.get_cell_size())
				_hw._map_view.dim_resource_node(cell, false)
				var nd: Dictionary = node.node_data if "node_data" in node else {}
				if not bool(nd.get("passable", false)):
					LocalMapGen.set_entity_blocked(_hw._local_map, cell.x, cell.y, true)
			_hw._active_respawn_nodes.remove_at(i)


# ---------------------------------------------------------------------------
# Phase 1: Tool management
# ---------------------------------------------------------------------------

# Currently equipped MainHand tool. Phase 1 placeholder; real tool
# tracking lands in Phase 4 with EquipmentManager.
func set_equipped_tool(tool_data: Dictionary) -> void:
	_hw._equipped_tool = tool_data


func get_equipped_tool() -> Dictionary:
	return _resolve_hotbar_tool()


## Read the hotbar's currently selected item_id, look it up in
## data/tools.json, and return the tool's data dict. Returns empty
## dict if no item is selected or the item isn't a known tool.
func _resolve_hotbar_tool() -> Dictionary:
	if not is_instance_valid(_hw._hud):
		return _hw._equipped_tool
	var hb: Hotbar = _hw._hud.get_hotbar() if _hw._hud.has_method("get_hotbar") else null
	if hb == null or not is_instance_valid(hb):
		return _hw._equipped_tool
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


## v0.4.0 polish: When the player presses F (interact) the FIRST step is
## to check whether the SELECTED hotbar slot holds a special "place/use"
## item — currently just `sleeping_bag`. If so, run the place/use action
## and short-circuit the rest of the interact cascade. This makes the
## hotbar the "use selected item" key (1-9 to select, F to use) and keeps
## the F key focused on world interactions (gather, settle, rift, etc.).
##
## Returns true if a hotbar-driven action was executed (caller should
## consume the F press). Returns false if the selected slot has a tool —
## meaning the standard cascade (gather / adjacent interactable) should
## proceed.
func _try_use_hotbar_selected_item() -> bool:
	if not is_instance_valid(_hw._hud):
		return false
	var hb: Hotbar = _hw._hud.get_hotbar() if _hw._hud.has_method("get_hotbar") else null
	if hb == null or not is_instance_valid(hb):
		return false
	var item_id: String = str(hb.get_slot(hb.get_selected_index()))
	if item_id.is_empty():
		return false
	# Currently the only "place on F" item is the sleeping bag. New
	# placeable items drop a case here without changing the cascade.
	match item_id:
		"sleeping_bag":
			# Place the bag only on walkable ground (so we don't bury it
			# in a wall or a river). _place_sleeping_bag() returns false
			# if the cell isn't walkable or the player lacks a bag.
			return _place_sleeping_bag()
	return false


# ---------------------------------------------------------------------------
# Phase 1: Floor pickups (sticks, stones)
# ---------------------------------------------------------------------------

func _try_collect_floor_pickup_at(x: int, y: int) -> Dictionary:
	if not is_instance_valid(_hw._map_view):
		return {}
	var pickup: Node2D = _hw._map_view.get_floor_pickup_at(Vector2i(x, y))
	if pickup == null:
		return {}
	var item_id: String = pickup.get_item_id()
	var qty: int = pickup.get_item_qty()
	if item_id.is_empty() or qty <= 0:
		return {}
	var inv: Node = get_node_or_null("/root/InventoryHandler")
	if inv == null:
		push_warning("[HubWorld] No InventoryHandler; pickup dropped on the floor.")
		return {}
	inv.add_item(item_id, qty)
	# v0.10.0: hide the MultiMesh visual for this pickup.
	var cell: Vector2i = Vector2i(x, y)
	_hw._map_view.hide_pickup_visual(cell)
	return {"item_id": item_id, "qty": qty}


# ---------------------------------------------------------------------------
# Phase 8: Loot popups
# ---------------------------------------------------------------------------

# spawn a floating loot popup at the given world position
# (typically the pickup / gather cell). The popup rises and fades
# over ~1.5 seconds.
func _spawn_loot_popup(text: String, world_pos: Vector2) -> void:
	if LootPopupScript == null:
		return
	var popup: Control = LootPopupScene.instantiate()
	popup.text = text
	# Position at the player's current cell in world space
	var px: float = float(_hw._local_x) * 24.0 + 12.0
	var py: float = float(_hw._local_y) * 24.0 + 12.0
	if world_pos == Vector2.ZERO:
		popup.global_position = Vector2(px - 30, py - 12)
	else:
		popup.global_position = world_pos
	add_child(popup)


# ---------------------------------------------------------------------------
# Phase 3: settlement entry / exit
# ---------------------------------------------------------------------------

## Returns the settlement hex adjacent to the player, or "" if none.
## Used by the E key (gather → entry) and the world marker.
func _adjacent_settlement_hex() -> String:
	if not is_instance_valid(_hw._map_view):
		return ""
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm != null and sm.is_inside_settlement():
		return ""
	# Walk adjacent cells looking for a SettlementNode
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var cell := Vector2i(_hw._local_x + dx, _hw._local_y + dy)
			# The settlement node may be on the cell the player is on too
			var s_node: Node2D = _hw._map_view.get_settlement_at(cell)
			if s_node != null:
				return s_node.get_cell(32) if s_node.has_method("get_cell") else str(s_node.get_meta("hex", ""))
	return ""


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
			_show_settlement_message(reason)
			return
	# Phase F: Fade transition
	if is_instance_valid(_hw._transition_screen):
		await _hw._transition_screen.fade_out(0.4)
	if sm.enter_settlement(hex, _hw, focus_building):
		# Hide the world view (the settlement interior covers the full
		# Control)
		_hw.world_grid.visible = false
		# Update minimap
		if is_instance_valid(_hw._hud):
			_hw._hud.notify_cell_changed()
	if is_instance_valid(_hw._transition_screen):
		_hw._transition_screen.fade_in(0.3)


## Show a transient message in the bottom bar (Phase 3 stub: just print).
func _show_settlement_message(_msg: String) -> void:
	pass


## Leave the active settlement (called by Settlement interior's
## "Leave" button or Esc/E).
func _leave_settlement() -> void:
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm == null or not sm.is_inside_settlement():
		return
	# Phase F: Fade transition
	if is_instance_valid(_hw._transition_screen):
		await _hw._transition_screen.fade_out(0.3)
	sm.leave_settlement()
	# Restore the world view
	_hw.world_grid.visible = true
	if is_instance_valid(_hw._hud):
		_hw._hud.notify_cell_changed()
	if is_instance_valid(_hw._transition_screen):
		_hw._transition_screen.fade_in(0.3)


# ---------------------------------------------------------------------------
# v0.8.0: Settlement buildings
# ---------------------------------------------------------------------------

## v0.8.0: Returns the adjacent SettlementBuilding node, or null.
## Checks the player's own cell and all 8 neighbors.
func _adjacent_building() -> Node2D:
	if not is_instance_valid(_hw._map_view):
		return null
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var cell := Vector2i(_hw._local_x + dx, _hw._local_y + dy)
			var bld: Node2D = _hw._map_view.get_building_at(cell)
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
					sm.enter_settlement(hex, _hw, bld_id)
					_hw.world_grid.visible = false
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


# ---------------------------------------------------------------------------
# Phase 6: base (player-chosen placement, upgrades, leave-base)
# ---------------------------------------------------------------------------

## E-key disambiguation now also checks for a base. Priority order:
## settlement > base > harvest > equipment tab.
func _has_adjacent_base() -> bool:
	if _hw._base_node != null and is_instance_valid(_hw._base_node):
		var cell: Vector2i = _hw._base_node.get_cell(32) if _hw._base_node.has_method("get_cell") else Vector2i.ZERO
		# Base is "adjacent" if the player is on the same cell (base is
		# the player's home; they spawn on top of it) or on an
		# immediate-neighbor cell.
		if cell == Vector2i(_hw._local_x, _hw._local_y):
			return true
		var dx: int = abs(cell.x - _hw._local_x)
		var dy: int = abs(cell.y - _hw._local_y)
		if dx <= 1 and dy <= 1:
			return true
	return false


## Open the base-placement UI overlay (player picks a cell with the
## 50-tile buffer). For Phase 6 this is a minimal overlay: a label +
## arrows (WASD moves a ghost preview; E confirms). Confirming checks
## is_valid_placement_cell and calls BaseManager.place.
func _open_base_placement() -> void:
	_show_settlement_message("Pick a base location: 50-tile buffer from map edges. (Phase 6: auto-places at the local center; full placement UI in Phase 8.)")
	# Minimal placeholder: auto-place at the center of the local map.
	var cx: int = 256
	var cy: int = 256
	var bm: Node = get_node_or_null("/root/BaseManager")
	if bm != null and bm.can_unlock() and bm.is_unplaced():
		var hex_key: String = "%d,%d" % [_hw._player_q, _hw._player_r]
		if bm.place(hex_key, cx, cy):
			_spawn_base_node(hex_key, cx, cy)
			_show_settlement_message("Base placed at (%d, %d) — level 1, capacity 5." % [cx, cy])


func _spawn_base_node(hex_key: String, lx: int, ly: int) -> void:
	if _hw._base_node != null and is_instance_valid(_hw._base_node):
		_hw._base_node.queue_free()
	_hw._base_node = BaseNodeScene.instantiate()
	_hw._base_node.name = "BaseNode"
	# Pull the latest snapshot
	var bm: Node = get_node_or_null("/root/BaseManager")
	var snap: Dictionary = bm.get_snapshot() if bm != null else {}
	_hw._base_node.setup({"placement": snap.get("placement", {}), "level": int(snap.get("level", 1))})
	_hw._base_node.position = Vector2(lx * 24 + 12, ly * 24 + 12)
	if _hw.has_node("World"):
		# Place on the world_grid so it renders with the world
		var wg: Node = _hw.get_node("World")
		wg.add_child(_hw._base_node)
	# Add to map_view's settlement layer for hit-test parity
	if is_instance_valid(_hw._map_view) and _hw._map_view.has_method("get_settlement_layer"):
		pass  # settlements are towns; the base has its own rendering


## Open the base interior (called when player presses E on the base).
func _try_enter_base() -> void:
	var bm: Node = get_node_or_null("/root/BaseManager")
	if bm == null or bm.is_unplaced():
		return
	# Spawn the interior
	_hw._base_interior = BaseScene.instantiate()
	_hw._base_interior.name = "Base"
	_hw._base_interior.setup(bm.get_snapshot(), _hw)
	add_child(_hw._base_interior)
	_hw.world_grid.visible = false
	if is_instance_valid(_hw._hud):
		_hw._hud.notify_cell_changed()


## Leave the base interior.
func _leave_base() -> void:
	if is_instance_valid(_hw._base_interior):
		_hw._base_interior.queue_free()
	_hw._base_interior = null
	_hw.world_grid.visible = true
	if is_instance_valid(_hw._hud):
		_hw._hud.notify_cell_changed()


# ---------------------------------------------------------------------------
# v0.6.0: Cooking table
# ---------------------------------------------------------------------------

## v0.6.0: Returns the adjacent CookingTable node, or null. Used by
## the E key to open the CookingTableUI.
func _adjacent_cooking_table() -> Node2D:
	if not is_instance_valid(_hw._map_view):
		return null
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var cell := Vector2i(_hw._local_x + dx, _hw._local_y + dy)
			var t_node: Node2D = _hw._map_view.get_cooking_table_at(cell)
			if t_node != null:
				return t_node
	return null


## v0.6.0: Open the CookingTableUI as a modal overlay.
func _open_cooking_table_ui() -> void:
	if _hw._cooking_table_ui != null and is_instance_valid(_hw._cooking_table_ui):
		return
	var CookingTableUIScene: PackedScene = load("res://scenes/ui/CookingTableUI.tscn") as PackedScene
	if CookingTableUIScene == null:
		push_error("[HubWorld] CookingTableUI scene not found")
		return
	_hw._cooking_table_ui = CookingTableUIScene.instantiate()
	add_child(_hw._cooking_table_ui)
	_hw._cooking_table_ui.set_on_close(_on_cooking_table_closed)


func _on_cooking_table_closed() -> void:
	if _hw._cooking_table_ui != null and is_instance_valid(_hw._cooking_table_ui):
		_hw._cooking_table_ui.queue_free()
	_hw._cooking_table_ui = null


# ---------------------------------------------------------------------------
# Sleeping bag (respawn point)
# ---------------------------------------------------------------------------

## Returns the adjacent SleepingBag node, or null.
func _adjacent_sleeping_bag() -> Node2D:
	if not is_instance_valid(_hw._map_view):
		return null
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var cell := Vector2i(_hw._local_x + dx, _hw._local_y + dy)
			var bag: Node2D = _hw._map_view.get_sleeping_bag_at(cell)
			if bag != null:
				return bag
	return null


## Interact with an adjacent sleeping bag: set respawn point.
func _interact_sleeping_bag(bag: Node2D) -> void:
	if not is_instance_valid(bag):
		return
	var cell: Vector2i = bag.get_cell(32) if bag.has_method("get_cell") else Vector2i(_hw._local_x, _hw._local_y)
	var rm: Node = get_node_or_null("/root/RespawnManager")
	if is_instance_valid(rm) and rm.has_method("set_respawn_point"):
		rm.set_respawn_point("sleeping_bag", cell.x, cell.y)
		print("[HubWorld] Respawn point set to sleeping bag at (%d, %d)" % [cell.x, cell.y])


## Place a sleeping bag from inventory at the player's current position.
func _place_sleeping_bag() -> bool:
	if not is_instance_valid(_hw._map_view):
		return false
	var inv: Node = get_node_or_null("/root/InventoryHandler")
	if inv == null or not inv.has_method("has_item") or not inv.has_method("remove_item"):
		return false
	if not inv.has_item("sleeping_bag", 1):
		return false
	# Check if there's already a sleeping bag on this hex
	var hex_key: String = "%d,%d" % [_hw._player_q, _hw._player_r]
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var hex_state: Dictionary = gs.get_hex_state(_hw._player_q, _hw._player_r)
		if hex_state.get("placed_sleeping_bag", {}) is Dictionary and not hex_state.get("placed_sleeping_bag", {}).is_empty():
			print("[HubWorld] Already have a sleeping bag on this hex")
			return false
	inv.remove_item("sleeping_bag", 1)
	# Create sleeping bag node
	var bag := SleepingBag.new()
	var cell_size: int = _hw._map_view.get_cell_size() if _hw._map_view.has_method("get_cell_size") else 32
	bag.position = Vector2(_hw._local_x * cell_size + cell_size * 0.5, _hw._local_y * cell_size + cell_size * 0.5)
	var world_node: Node2D = _hw.get_node_or_null("World")
	if world_node != null:
		world_node.add_child(bag)
	# Register with map view
	if _hw._map_view.has_method("add_sleeping_bag"):
		_hw._map_view.add_sleeping_bag(Vector2i(_hw._local_x, _hw._local_y), bag)
	# Persist in hex state
	if is_instance_valid(gs):
		var state: Dictionary = gs.ensure_hex_state(_hw._player_q, _hw._player_r)
		state["placed_sleeping_bag"] = {"local_x": _hw._local_x, "local_y": _hw._local_y}
		gs.save_hex_state(_hw._player_q, _hw._player_r, state)
	print("[HubWorld] Sleeping bag placed!")
	return true


# ---------------------------------------------------------------------------
# Context menu (double-click)
# ---------------------------------------------------------------------------

const ContextMenuScript = preload("res://scripts/ui/ContextMenu.gd")

## Entry point for left-click on the world. Opens context box for
## harvestables and other interactables under the cursor.
func _on_world_click(world_pos: Vector2, screen_pos: Vector2) -> bool:
	return _on_double_click(world_pos, screen_pos)


## Back-compat alias (double-click used to be the only entry).
func _on_double_click(world_pos: Vector2, screen_pos: Vector2) -> bool:
	if not is_instance_valid(_hw._map_view):
		return false
	_dismiss_context_menu()
	var cell_size: int = _hw._map_view.get_cell_size()
	var cell := Vector2i(
		int(floor(world_pos.x / cell_size)),
		int(floor(world_pos.y / cell_size)),
	)
	var built: Dictionary = _build_context_box(cell)
	var options: Array = built.get("options", [])
	var info_lines: Array = built.get("info", [])
	if options.is_empty() and info_lines.is_empty():
		return false
	_show_context_menu(screen_pos, options, cell, info_lines)
	return true


## Build options + info tip lines for the context box at a cell.
func _build_context_box(cell: Vector2i) -> Dictionary:
	var options: Array = []
	var info: Array = []
	var px: int = _hw._local_x
	var py: int = _hw._local_y
	var dist: int = max(abs(cell.x - px), abs(cell.y - py))

	var node_info: Dictionary = _get_resource_node_at(cell)
	if not node_info.is_empty():
		var node: Node2D = node_info.get("node")
		if is_instance_valid(node):
			var nd: Dictionary = node.node_data if "node_data" in node else {}
			var cat: String = str(nd.get("category", ""))
			var tool_type: String = HarvestNodeScript.required_tool_type(cat, str(nd.get("id", "")))
			info.append("Requires: %s" % tool_type)
			if dist > GATHER_RANGE_CELLS:
				info.append("Move closer to harvest")
			else:
				var tool: Dictionary = _resolve_hotbar_tool()
				if tool.is_empty():
					tool = {"speed_mult": 1.0, "harvests": [], "name": "(bare hands)"}
				var result: Dictionary = node.try_gather(tool)
				if bool(result.get("ok", false)):
					var yitem: String = str(result.get("yield_item", ""))
					var yqty: int = int(result.get("yield_qty", 1))
					var secs: float = float(result.get("secs", 1.0))
					info.append("Yield ~%s ×%d  (%.1fs)" % [yitem, yqty, secs])
					var verb := "Chop" if tool_type == "Axe" else "Mine"
					options.append({
						"label": "%s %s" % [verb, str(node_info.get("name", "Resource"))],
						"action": "gather",
					})
				else:
					match str(result.get("reason", "")):
						"wrong_tool", "no_tool":
							info.append(_nearest_tool_hint(node))
							options.append({"label": _nearest_tool_hint(node), "action": ""})
						"depleted":
							info.append("Depleted — regenerating")
							options.append({"label": "Depleted", "action": ""})
						"decoration":
							info.append("Not harvestable")
						_:
							info.append("Cannot harvest")

	if dist <= GATHER_RANGE_CELLS:
		var bld: Node2D = _hw._map_view.get_building_at(cell)
		if is_instance_valid(bld):
			var role: String = bld.get_role() if bld.has_method("get_role") else ""
			match role:
				"trader":
					options.append({"label": "Shop", "action": "shop"})
				"quest_giver":
					options.append({"label": "Quest Board", "action": "quest_board"})
				_:
					options.append({"label": "Enter", "action": "enter_building"})

	if dist == 0:
		if not _hw._rift_manager.get_rift_at_player().is_empty():
			options.append({"label": "Enter Rift", "action": "enter_rift"})

	if dist <= GATHER_RANGE_CELLS:
		var bag: Node2D = _hw._map_view.get_sleeping_bag_at(cell)
		if is_instance_valid(bag):
			options.append({"label": "Set Respawn Point", "action": "set_respawn"})
		var ct: Node2D = _hw._map_view.get_cooking_table_at(cell)
		if is_instance_valid(ct):
			options.append({"label": "Cook", "action": "cook"})

	return {"options": options, "info": info}


func _build_context_options(cell: Vector2i) -> Array:
	return _build_context_box(cell).get("options", [])


func _get_resource_node_at(cell: Vector2i) -> Dictionary:
	if not is_instance_valid(_hw._map_view):
		return {}
	var entries: Array = _hw._map_view.get_resource_nodes_near(cell, 0)
	if entries.is_empty():
		return {}
	var entry: Dictionary = entries[0]
	var node: Node2D = entry.get("node")
	if not is_instance_valid(node):
		return {}
	var nd: Dictionary = node.node_data if "node_data" in node else {}
	return {
		"node": node,
		"name": str(nd.get("name", nd.get("id", "Resource"))),
		"id": str(nd.get("id", "")),
		"category": str(nd.get("category", "")),
	}


func _show_context_menu(screen_pos: Vector2, options: Array, cell: Vector2i, info_lines: Array = []) -> void:
	_dismiss_context_menu()
	if ContextMenuScript == null:
		return
	var menu: Control = ContextMenuScript.new()
	menu.name = "ContextMenu"
	var title: String = _context_menu_title(cell)
	menu.action_selected.connect(_on_context_action)
	var ui_canvas: CanvasLayer = _hw.get_node_or_null("UI_Canvas") as CanvasLayer
	if is_instance_valid(ui_canvas):
		ui_canvas.add_child(menu)
	else:
		_hw.add_child(menu)
	menu.tree_exited.connect(_on_context_menu_closed)
	menu.show_at(screen_pos, title, options, cell, info_lines)
	_hw._context_menu = menu


func _on_context_menu_closed() -> void:
	_hw._context_menu = null


func _context_menu_title(cell: Vector2i) -> String:
	var node_info: Dictionary = _get_resource_node_at(cell)
	if not node_info.is_empty():
		return str(node_info.get("name", "Resource"))
	var bld: Node2D = _hw._map_view.get_building_at(cell)
	if is_instance_valid(bld):
		return bld.get_label() if bld.has_method("get_label") else "Building"
	var bag: Node2D = _hw._map_view.get_sleeping_bag_at(cell)
	if is_instance_valid(bag):
		return "Sleeping Bag"
	var ct: Node2D = _hw._map_view.get_cooking_table_at(cell)
	if is_instance_valid(ct):
		return ct.get_label() if ct.has_method("get_label") else "Cooking Table"
	return "Interact"


func _on_context_action(action: String, target_cell: Vector2i) -> void:
	_hw._context_menu = null
	match action:
		"gather":
			_start_gather_at_cell(target_cell)
		"shop", "quest_board", "enter_building":
			var bld: Node2D = _hw._map_view.get_building_at(target_cell)
			if is_instance_valid(bld):
				_interact_building(bld)
		"enter_rift":
			if not _hw._rift_manager.get_rift_at_player().is_empty():
				_hw._rift_manager.open_rift_entry_ui()
		"set_respawn":
			var bag: Node2D = _hw._map_view.get_sleeping_bag_at(target_cell)
			if is_instance_valid(bag):
				_interact_sleeping_bag(bag)
		"cook":
			var ct: Node2D = _hw._map_view.get_cooking_table_at(target_cell)
			if is_instance_valid(ct):
				_open_cooking_table_ui()


func _start_gather_at_cell(cell: Vector2i) -> void:
	if is_instance_valid(_hw._gathering_node):
		return
	var candidates: Array = _hw._map_view.get_resource_nodes_near(cell, 0)
	if candidates.is_empty():
		return
	var entry: Dictionary = candidates[0]
	var node: Node2D = entry["node"]
	if not is_instance_valid(node):
		return
	var tool: Dictionary = _resolve_hotbar_tool()
	if tool.is_empty():
		tool = {"speed_mult": 1.0, "harvests": [], "name": "(bare hands)"}
	var result: Dictionary = node.try_gather(tool)
	if not bool(result.get("ok", false)):
		_notify_gather_failure(node, result)
		return
	_begin_gather(node, result)


func _begin_gather(node: Node2D, result: Dictionary) -> void:
	_hw._gathering_node = node
	_hw._gather_total = float(result.get("secs", 1.0))
	_hw._gather_timer = _hw._gather_total
	_hw._gather_yield_preview = {
		"yield_item": str(result.get("yield_item", "")),
		"yield_qty": int(result.get("yield_qty", 0)),
	}


func _notify_gather_failure(node: Node2D, result: Dictionary) -> void:
	var reason: String = str(result.get("reason", ""))
	var msg := ""
	match reason:
		"no_tool", "wrong_tool":
			msg = _nearest_tool_hint(node)
		"depleted":
			msg = "Resource depleted"
		"decoration":
			msg = "Cannot harvest this"
		_:
			msg = "Cannot harvest"
	_show_gather_toast(msg)


func _show_gather_toast(msg: String) -> void:
	if msg.is_empty():
		return
	if is_instance_valid(_hw._hud_manager) and _hw._hud_manager.has_method("_show_notification"):
		_hw._hud_manager.call("_show_notification", msg)


func _dismiss_context_menu() -> void:
	if _hw._context_menu != null and is_instance_valid(_hw._context_menu):
		_hw._context_menu.queue_free()
	_hw._context_menu = null


## Suggest what tool is needed for a node (from tools.json harvests).
func _nearest_tool_hint(node: Node2D) -> String:
	var nd: Dictionary = node.node_data if "node_data" in node else {}
	var node_id: String = str(nd.get("id", ""))
	var category: String = str(nd.get("category", ""))
	var tool_type: String = HarvestNodeScript.required_tool_type(category, node_id)
	var path := "res://data/tools.json"
	if not ResourceLoader.exists(path):
		return "Requires: %s" % tool_type
	var raw = load(path)
	if raw == null:
		return "Requires: %s" % tool_type
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return "Requires: %s" % tool_type
	var names: Array = []
	for t in data.get("tools", []):
		if HarvestNodeScript.tool_can_harvest(t, node_id, category):
			names.append(str(t.get("name", t.get("id", "?"))))
	if names.is_empty():
		return "Requires: %s" % tool_type
	return "Requires: %s (%s)" % [tool_type, names[0]]


# ---------------------------------------------------------------------------
# UI overlay check
# ---------------------------------------------------------------------------

## True if any *game-blocking* UI overlay is open. The pause menu
## and the character menu are deliberately NOT included here — they
## are independent overlays (toggled by Escape and I/E/C/P/S
## respectively) and the player should be able to open either one
## without having to dismiss the other first. Only the cooking table,
## base interior, and settlement interior are "modal" in the sense
## that they take over the world and need to be closed before any
## other UI can be opened.
func _is_ui_overlay_open() -> bool:
	if _hw._hud != null and is_instance_valid(_hw._hud) and _hw._hud.has_method("is_character_menu_open"):
		if _hw._hud.is_character_menu_open():
			return true
	if _hw._cooking_table_ui != null and is_instance_valid(_hw._cooking_table_ui):
		return true
	if _hw._base_interior != null and is_instance_valid(_hw._base_interior):
		return true
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm != null and sm.has_method("is_inside_settlement") and sm.is_inside_settlement():
		return true
	return false


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

func _save_to_autoslot_if_can() -> void:
	var gs := _hw._gs
	if not is_instance_valid(gs) or gs.get_character_data().is_empty():
		return
	# Trigger a save to autoslot (slot 0)
	gs.save_game(0)
