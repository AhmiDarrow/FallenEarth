## MissionBoardInterface — Browse + accept missions from a settlement.
##
## Phase 3. Opened from the Settlement interior via the quest_board
## building's button. Lists the active offers for the current player
## (uses MissionManager.get_offers_for_npc + the player's party
## member ids). Phase 3 ships a minimal list + accept; real mission
## types (combat, gather, escort) land in a follow-up.
class_name MissionBoardInterface
extends Control

const UIBackgrounds = preload("res://scripts/UIBackgrounds.gd")
const MISSION_PATH := "/root/MissionManager"
const PARTY_PATH := "/root/PartyNPCManager"
const HUB_PATH := "/root/HubWorld"

signal closed

var _offers: Array = []


func _ready() -> void:
	# Use `anchors_preset` (property syntax) instead of `anchor_right = 1.0`
	# to avoid Godot's "size overridden after _ready" warning — see
	# BaseShopUI for the full explanation.
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Sync our size to the parent BEFORE building children — otherwise
	# `_build_ui()` reads `size = (0, 0)` and places the status label
	# and close button off-screen.
	_sync_size_to_parent()
	_build_ui()
	_refresh()
	# Stay in lockstep with the parent if it ever resizes.
	var parent := get_parent()
	if parent is Control and not (parent as Control).resized.is_connected(_on_parent_resized):
		(parent as Control).resized.connect(_on_parent_resized)


## Snap our `size` to the parent Control's rect. Required because we
## are added as a child of a non-Container Control and the engine
## doesn't auto-size us from anchors alone.
func _sync_size_to_parent() -> void:
	var parent := get_parent()
	if parent is Control:
		var p: Control = parent as Control
		if p.size.x > 0 and p.size.y > 0:
			size = p.size
			position = Vector2.ZERO


## Re-sync our size and re-layout when the parent Control is resized.
func _on_parent_resized() -> void:
	_sync_size_to_parent()
	if has_node("StatusLabel"):
		$StatusLabel.position = Vector2(20, size.y - 70)
	if has_node("Close"):
		$Close.position = Vector2(size.x - 100, size.y - 50)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	UIBackgrounds.apply_modal_bg(bg)
	# Title
	var title := Label.new()
	title.text = "[ Mission Board ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(20, 12)
	add_child(title)
	# Subtitle
	var sub := Label.new()
	sub.text = "Available offers:"
	sub.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	sub.add_theme_font_size_override("font_size", 16)
	sub.position = Vector2(20, 60)
	add_child(sub)
	# List
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 90)
	scroll.size = Vector2(740, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "OfferList"
	scroll.add_child(list)
	# Status
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.position = Vector2(20, size.y - 70)
	status_label.size = Vector2(740, 30)
	add_child(status_label)
	# Close
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(size.x - 100, size.y - 50)
	close.custom_minimum_size = Vector2(80, 36)
	close.pressed.connect(_on_close_pressed)
	add_child(close)


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
	emit_signal("closed")
	queue_free()
