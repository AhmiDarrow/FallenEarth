## MissionBoardInterface — Browse + accept missions from a settlement.
##
## Phase 3. Opened from the Settlement interior via the quest_board
## building's button. Lists the active offers for the current player
## (uses MissionManager.get_offers_for_npc + the player's party
## member ids). Phase 3 ships a minimal list + accept; real mission
## types (combat, gather, escort) land in a follow-up.
class_name MissionBoardInterface
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const MISSION_PATH := "/root/MissionManager"
const PARTY_PATH := "/root/PartyNPCManager"
const HUB_PATH := "/root/HubWorld"

signal closed

var _offers: Array = []


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 8)
	add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "[ Mission Board ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 22)
	root_vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Available offers:"
	sub.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	sub.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(sub)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "OfferList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Bottom bar: status + close
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 32)
	root_vbox.add_child(bottom)
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(status_label)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(80, 32)
	close.pressed.connect(_on_close_pressed)
	bottom.add_child(close)
	ButtonStyleHelper.apply_secondary(close)


func _refresh() -> void:
	_offers = []
	# Pull offers for the player's party members
	var mm: Node = get_node_or_null(MISSION_PATH)
	var pm: Node = get_node_or_null(PARTY_PATH)
	if mm == null:
		_set_status("MissionManager not available")
		return
	# If no party, fall back to a generic "solo" id so the board
	# still shows something.
	var ids: Array = []
	if pm != null:
		for n in pm.party_members:
			ids.append(str(n.get("id", "")))
	if ids.is_empty():
		ids = ["solo_player"]
	for npc_id in ids:
		if mm.has_method("get_offers_for_npc"):
			for offer in mm.get_offers_for_npc(npc_id):
				_offers.append(offer)
	_populate()


func _populate() -> void:
	var list: VBoxContainer = get_node_or_null("OfferList")
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	if _offers.is_empty():
		var ph := Label.new()
		ph.text = "(no offers available right now)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		list.add_child(ph)
		return
	for offer in _offers:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 36)
		list.add_child(row)
		var info := Label.new()
		info.text = "%s — %s" % [
			str(offer.get("title", "Mission")),
			str(offer.get("description", "no description"))
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		var accept_btn := Button.new()
		accept_btn.text = "Accept"
		accept_btn.pressed.connect(_on_accept_pressed.bind(offer))
		row.add_child(accept_btn)


func _on_accept_pressed(offer: Dictionary) -> void:
	var mm: Node = get_node_or_null(MISSION_PATH)
	if mm == null or not mm.has_method("accept_mission"):
		_set_status("MissionManager not available")
		return
	var mission_id: String = str(offer.get("mission_id", ""))
	if mission_id.is_empty():
		_set_status("Offer has no mission id")
		return
	var result: Dictionary = mm.accept_mission(mission_id, 0.0)
	if bool(result.get("ok", false)):
		_set_status("Accepted: %s" % mission_id)
		_refresh()
	else:
		_set_status("Could not accept: %s" % str(result.get("reason", "?")))


func _set_status(msg: String) -> void:
	if has_node("StatusLabel"):
		$StatusLabel.text = msg
	print("[MissionBoard] %s" % msg)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
