## Settlement — Interior instance for a NPC town (Phase 3 placeholder).
##
## Loaded by SettlementManager when the player presses E adjacent to
## a SettlementNode on the world map. Same pattern as RiftInstance
## (Phase 3) and the player-base (Phase 6).
##
## For Phase 3 the interior is a single room with: a title, an NPC
## list (the party-joinable NPCs that are present in this town), a
## services list, and a "Leave settlement" button. Walking up to the
## entrance tile and pressing E also exits.
##
## NPCs that the player can add to the party spawn in settlements.
## Each settlement shows a subset of `PartyNPCManager.available_npcs`
## (deterministic by town index). Inviting from the settlement
## removes the NPC from `available_npcs` and adds to `party_members`.
##
## Real interiors (multiple buildings, quest boards, traveling NPCs)
## land in a follow-up.
class_name Settlement
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const ENTRANCE_TILE := Vector2i(0, 0)
const SETTLEMENT_PATH := "/root/SettlementManager"
const PARTY_PATH := "/root/PartyNPCManager"

var _town_data: Dictionary = {}
var _hub: Node = null
var _resident_npc_ids: Array = []  # subset of PartyNPCManager.available_npcs that are "in" this town


func _ready() -> void:
	# Use `anchors_preset` (property syntax) instead of `anchor_right = 1.0`
	# to avoid Godot's "size overridden after _ready" warning — see
	# BaseShopUI for the full explanation.
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Sync our size to the parent BEFORE building children — otherwise
	# `_build_ui()` reads `size = (0, 0)` and places the Leave button
	# off-screen. Same anti-pattern as CharacterMenu / BaseShopUI.
	_sync_size_to_parent()
	_build_ui()
	# Stay in lockstep with the parent if it ever resizes.
	var parent := get_parent()
	if parent is Control and not (parent as Control).resized.is_connected(_on_parent_resized):
		(parent as Control).resized.connect(_on_parent_resized)


## Snap our `size` to the parent Control's rect. Required because we
## are added as a child of a non-Container Control and the engine
## doesn't auto-size us from anchors alone in every setup.
func _sync_size_to_parent() -> void:
	var parent := get_parent()
	if parent is Control:
		var p: Control = parent as Control
		if p.size.x > 0 and p.size.y > 0:
			size = p.size
			position = Vector2.ZERO


## Re-sync our size and re-place the Leave button when the parent Control resizes.
func _on_parent_resized() -> void:
	_sync_size_to_parent()
	if has_node("LeaveButton"):
		$LeaveButton.position = Vector2(size.x - 220, size.y - 60)


func setup(town: Dictionary, hub: Node) -> void:
	_town_data = town
	_hub = hub
	# Defer the title population so the UI is built first
	_populate()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Title
	var title := Label.new()
	title.name = "Title"
	title.text = "[ Settlement ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(20, 16)
	add_child(title)
	# Faction
	var faction := Label.new()
	faction.name = "Faction"
	faction.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	faction.add_theme_font_size_override("font_size", 14)
	faction.position = Vector2(20, 52)
	add_child(faction)
	# NPC list
	var npc_label := Label.new()
	npc_label.name = "NpcLabel"
	npc_label.text = "Residents (Phase 3 placeholder list):"
	npc_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	npc_label.add_theme_font_size_override("font_size", 14)
	npc_label.position = Vector2(20, 96)
	add_child(npc_label)
	var npc_vbox := VBoxContainer.new()
	npc_vbox.name = "NpcList"
	npc_vbox.position = Vector2(20, 120)
	add_child(npc_vbox)
	# Services list
	var svc_label := Label.new()
	svc_label.name = "ServicesLabel"
	svc_label.text = "Services available:"
	svc_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.75))
	svc_label.add_theme_font_size_override("font_size", 14)
	svc_label.position = Vector2(20, 280)
	add_child(svc_label)
	var svc_vbox := VBoxContainer.new()
	svc_vbox.name = "ServicesList"
	svc_vbox.position = Vector2(20, 304)
	add_child(svc_vbox)
	# Leave button
	var leave_btn := Button.new()
	leave_btn.name = "LeaveButton"
	leave_btn.text = "Leave settlement"
	leave_btn.position = Vector2(size.x - 220, size.y - 60)
	leave_btn.custom_minimum_size = Vector2(180, 44)
	leave_btn.pressed.connect(_on_leave_pressed)
	add_child(leave_btn)
	ButtonStyleHelper.apply_danger(leave_btn)


func _populate() -> void:
	if not _town_data.is_empty():
		if has_node("Title"):
			$Title.text = "[ %s ]" % _town_data.get("template_name", "Settlement")
		if has_node("Faction"):
			$Faction.text = "Faction: %s" % _town_data.get("faction", "?")
	_resolve_resident_npcs()
	_populate_npc_list()
	_populate_services_list()


## Pick the subset of PartyNPCManager.available_npcs that "live in"
## this settlement. v0.7.0: replace the Phase 3 placeholder (pick from
## a global pool) with a per-settlement procedural spawn. The
## spawn is deterministic: same hex_key + same biome + same faction +
## same town_size always produces the same NPCs.
func _resolve_resident_npcs() -> void:
	_resident_npc_ids = []
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	# Clear any previously-spawned residents for THIS hex so a re-enter
	# doesn't accumulate duplicates. (Phase 3 test NPCs and procedurally
	# spawned hex NPCs are left alone — they don't have settlement_resident=true.)
	var hex: String = str(_town_data.get("hex", ""))
	pm.clear_settlement_residents(hex)
	# Spawn biome- AND faction-appropriate residents for this settlement.
	# The faction is critical: settlements belong to a specific faction,
	# and the NPC pool should reflect that (Iron Accord towns spawn
	# Iron-Accord-themed NPCs, Hollow Covenant towns spawn Hollow-themed
	# NPCs, etc.). This is how the world "balances weights between
	# settlements to faction ratio" — every faction gets a proportional
	# share of NPCs proportional to its settlement count.
	var biome: String = str(_town_data.get("biome", ""))
	if biome.is_empty():
		biome = "Ash Wastes"  # fallback if world_data didn't record a biome
	var faction: String = str(_town_data.get("faction", ""))
	var size_str: String = str(_town_data.get("size", "medium"))
	var spawned: Array = pm.spawn_for_settlement(hex, biome, faction, size_str)
	for n in spawned:
		_resident_npc_ids.append(str(n.get("id", "")))


func _get_town_index() -> int:
	# Find this town's index in the world_data.towns_seeded list so
	# the same town always shows the same residents.
	var sm: Node = get_node_or_null("/root/SettlementManager")
	if sm == null:
		return 0
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_world():
		return 0
	var wd: Dictionary = gs.get_world_data()
	var towns: Array = wd.get("towns_seeded", [])
	for i in towns.size():
		if str(towns[i].get("hex", "")) == str(_town_data.get("hex", "")):
			return i
	return 0


func _populate_npc_list() -> void:
	var npc_vbox: VBoxContainer = get_node_or_null("NpcList") as VBoxContainer
	if npc_vbox == null:
		return
	for child in npc_vbox.get_children():
		child.queue_free()
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		var ph := Label.new()
		ph.text = "(PartyNPCManager not available)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		npc_vbox.add_child(ph)
		return
	if _resident_npc_ids.is_empty():
		var ph := Label.new()
		ph.text = "(no residents to recruit right now)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		npc_vbox.add_child(ph)
		return
	# Render each resident as a row with Invite button
	for rid in _resident_npc_ids:
		var npc: Dictionary = pm.get_npc(rid)
		if npc.is_empty():
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		npc_vbox.add_child(row)
		var info := Label.new()
		info.text = "%s (%s · Lv.%d)" % [
			npc.get("name", "?"), npc.get("class", "?"), int(npc.get("level", 1))
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var invite_btn := Button.new()
		invite_btn.text = "Invite"
		invite_btn.pressed.connect(_on_invite_pressed.bind(rid))
		row.add_child(invite_btn)
		ButtonStyleHelper.apply_primary(invite_btn)


func _on_invite_pressed(npc_id: String) -> void:
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	if not pm.invite(npc_id):
		return
	# Refresh the NPC list (the invited one is no longer in available)
	_resolve_resident_npcs()
	_populate_npc_list()


func _populate_services_list() -> void:
	var svc_vbox: VBoxContainer = get_node_or_null("ServicesList")
	if svc_vbox == null:
		return
	for child in svc_vbox.get_children():
		child.queue_free()
	var buildings: Array = _town_data.get("buildings", [])
	# Group buildings into logical NPC types for the interior.
	# Each building gets its own interactive row.
	var npc_index: int = 0
	for b in buildings:
		var building_name: String = str(b)
		var npc_role: String = _building_to_role(building_name)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		svc_vbox.add_child(row)
		var info := Label.new()
		info.text = "• %s (%s)" % [building_name, npc_role]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var talk_btn := Button.new()
		talk_btn.text = "Talk"
		talk_btn.pressed.connect(_on_service_talk.bind(building_name, npc_role, npc_index))
		row.add_child(talk_btn)
		ButtonStyleHelper.apply_secondary(talk_btn)
		npc_index += 1


## Map a building name to a rough role for the placeholder NPC.
func _building_to_role(building: String) -> String:
	match building:
		"tavern": return "innkeeper"
		"trader": return "trader"
		"worktable": return "crafter"
		"armor_table": return "armorer"
		"blacksmith": return "smith"
		"quest_board": return "quest_giver"
		"faction_hq": return "faction_rep"
		"auction_house": return "auctioneer"
		"arena": return "trainer"
		_: return "vendor"


## Talk to a service. Real interactions: trader → Shop, quest_board →
## MissionBoard, faction_hq → faction rep dialog. Phase 3 ships:
## trader → ShopInterface, quest_board → MissionBoardInterface,
## everything else → stub greeting.
func _on_service_talk(building: String, role: String, idx: int) -> void:
	match role:
		"trader":
			_open_shop()
		"quest_giver":
			_open_mission_board()
		_:
			_show_greeting(building, role)


func _open_shop() -> void:
	if _find_child_by_name("Shop") != null:
		return
	var ShopScript: GDScript = load("res://scripts/ui/ShopInterface.gd")
	if ShopScript == null:
		_set_status("ShopInterface.gd missing")
		return
	var shop: Control = ShopScript.new()
	shop.name = "Shop"
	add_child(shop)


func _open_mission_board() -> void:
	if _find_child_by_name("MissionBoard") != null:
		return
	var MBScript: GDScript = load("res://scripts/ui/MissionBoardInterface.gd")
	if MBScript == null:
		_set_status("MissionBoardInterface.gd missing")
		return
	var board: Control = MBScript.new()
	board.name = "MissionBoard"
	add_child(board)


func _show_greeting(building: String, role: String) -> void:
	_set_status("%s (%s): \"Welcome, traveler. Make yourself at home.\"  (full dialog lands in Phase 8)" % [building, role])


func _find_child_by_name(n: String) -> Node:
	for c in get_children():
		if c.name == n:
			return c
	return null


func _set_status(msg: String) -> void:
	# Phase 3 settlement has no status label; print + push a small
	# overlay label.
	print("[Settlement] %s" % msg)


func _on_leave_pressed() -> void:
	var sm: Node = get_node_or_null(SETTLEMENT_PATH)
	if sm != null and sm.has_method("leave_settlement"):
		sm.leave_settlement()
	else:
		queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
		_on_leave_pressed()
		get_viewport().set_input_as_handled()
