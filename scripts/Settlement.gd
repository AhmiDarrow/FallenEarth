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

const ENTRANCE_TILE := Vector2i(0, 0)
const SETTLEMENT_PATH := "/root/SettlementManager"
const PARTY_PATH := "/root/PartyNPCManager"

var _town_data: Dictionary = {}
var _hub: Node = null
var _resident_npc_ids: Array = []  # subset of PartyNPCManager.available_npcs that are "in" this town


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func setup(town: Dictionary, hub: Node) -> void:
	_town_data = town
	_hub = hub
	# Defer the title population so the UI is built first
	_populate()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.06, 0.95)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
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
## this settlement. For Phase 3 the selection is deterministic by
## the town's index (so the same settlement shows the same NPCs across
## runs). Phase 5 will replace this with a real spawn system tied to
## the world_data.
func _resolve_resident_npcs() -> void:
	_resident_npc_ids = []
	var pm: Node = get_node_or_null(PARTY_PATH)
	if pm == null:
		return
	var all_available: Array = pm.available_npcs
	if all_available.is_empty():
		return
	# Pick by town index modulo available count
	var town_index: int = _get_town_index()
	# Number of NPCs to show depends on the template size
	var max_residents: int = 1
	var size_str: String = str(_town_data.get("size", "medium"))
	match size_str:
		"small": max_residents = 1
		"medium": max_residents = 2
		"large": max_residents = 3
		_: max_residents = 2
	for i in max_residents:
		var idx: int = (town_index + i) % all_available.size()
		var npc: Dictionary = all_available[idx]
		_resident_npc_ids.append(str(npc.get("id", "")))


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
