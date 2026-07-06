## Base — Interior instance for the player's home base (Phase 6).
##
## Loaded by BaseManager when the player presses E adjacent to the
## BaseNode on the world map. The interior is a single room with:
## - a title (base name or "My Base" + level)
## - a capacity bar (residents / capacity)
## - a residents list (dismissed-from-party NPCs)
## - a settlement name field (enabled at 20+ residents)
## - an upgrade section (current level, next cost, Upgrade button)
## - a "Leave base" button
##
## Real interiors (rooms, NPC behaviors, base shops) land in
## Phase 7 (base shops) and follow-ups.
class_name Base
extends Control

const BASE_PATH := "/root/BaseManager"
const PARTY_PATH := "/root/PartyNPCManager"
const EQUIP_PATH := "/root/EquipmentManager"
const BASE_SHOP_PATH := "/root/BaseShopManager"
const BaseShopUIScript = preload("res://scripts/ui/BaseShopUI.gd")

var _town_data: Dictionary = {}
var _hub: Node = null


func _ready() -> void:
	# Use `anchors_preset` (property syntax) instead of `anchor_right = 1.0`
	# to avoid Godot's "size overridden after _ready" warning — see
	# BaseShopUI for the full explanation.
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Sync our size to the parent BEFORE building children — otherwise
	# `_build_ui()` would read `size = (0, 0)` and place status / close
	# buttons off-screen. Same anti-pattern as CharacterMenu / BaseShopUI.
	_sync_size_to_parent()
	_build_ui()
	_refresh()
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


## Re-sync our size and re-place any children whose position depends on `size`.
func _on_parent_resized() -> void:
	_sync_size_to_parent()
	if has_node("StatusLabel"):
		$StatusLabel.position = Vector2(20, size.y - 70)
	# Close button has no name set; find by text
	for c in get_children():
		if c is Button and (c.text == "Leave base" or c.text == "Close"):
			c.position = Vector2(size.x - 140, size.y - 50)
			break


func setup(base_state: Dictionary, hub: Node) -> void:
	# base_state is a dict from BaseManager.get_snapshot()
	_town_data = base_state
	_hub = hub
	_populate()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.95)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Title
	var title := Label.new()
	title.name = "Title"
	title.text = "[ Base ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(20, 16)
	add_child(title)
	# Level / capacity
	var cap := Label.new()
	cap.name = "CapLabel"
	cap.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	cap.add_theme_font_size_override("font_size", 16)
	cap.position = Vector2(20, 56)
	add_child(cap)
	# Residents
	var res_label := Label.new()
	res_label.name = "ResLabel"
	res_label.text = "Residents:"
	res_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	res_label.add_theme_font_size_override("font_size", 14)
	res_label.position = Vector2(20, 96)
	add_child(res_label)
	var res_scroll := ScrollContainer.new()
	res_scroll.name = "ResScroll"
	res_scroll.position = Vector2(20, 120)
	res_scroll.size = Vector2(360, 280)
	res_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(res_scroll)
	var res_vbox := VBoxContainer.new()
	res_vbox.name = "ResList"
	res_scroll.add_child(res_vbox)
	# Settlement name field
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Settlement name (unlocks at 20 residents):"
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.position = Vector2(20, 420)
	add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.placeholder_text = "Type a name..."
	name_edit.position = Vector2(20, 446)
	name_edit.custom_minimum_size = Vector2(360, 32)
	name_edit.editable = false
	add_child(name_edit)
	var name_btn := Button.new()
	name_btn.name = "NameButton"
	name_btn.text = "Set name"
	name_btn.position = Vector2(20, 484)
	name_btn.custom_minimum_size = Vector2(100, 32)
	name_btn.pressed.connect(_on_name_button_pressed)
	add_child(name_btn)
	# Upgrade section
	var upg_label := Label.new()
	upg_label.name = "UpgLabel"
	upg_label.text = "Upgrade:"
	upg_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.75))
	upg_label.add_theme_font_size_override("font_size", 14)
	upg_label.position = Vector2(400, 96)
	add_child(upg_label)
	var upg_info := Label.new()
	upg_info.name = "UpgInfo"
	upg_info.add_theme_color_override("font_color", Color.WHITE)
	upg_info.add_theme_font_size_override("font_size", 13)
	upg_info.position = Vector2(400, 120)
	upg_info.custom_minimum_size = Vector2(360, 200)
	upg_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(upg_info)
	var upg_btn := Button.new()
	upg_btn.name = "UpgButton"
	upg_btn.text = "Upgrade"
	upg_btn.position = Vector2(400, 340)
	upg_btn.custom_minimum_size = Vector2(140, 40)
	upg_btn.pressed.connect(_on_upgrade_pressed)
	add_child(upg_btn)
	# Status line
	var status := Label.new()
	status.name = "StatusLabel"
	status.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	status.add_theme_font_size_override("font_size", 14)
	status.position = Vector2(20, size.y - 70)
	status.custom_minimum_size = Vector2(740, 30)
	add_child(status)
	# Close
	var close := Button.new()
	close.text = "Leave base"
	close.position = Vector2(size.x - 140, size.y - 50)
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(_on_close_pressed)
	add_child(close)
	# Shop section (Phase 7)
	var shop_label := Label.new()
	shop_label.name = "ShopLabel"
	shop_label.text = "Base shops (offered by residents):"
	shop_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.95))
	shop_label.add_theme_font_size_override("font_size", 14)
	shop_label.position = Vector2(400, 420)
	add_child(shop_label)
	var shop_scroll := ScrollContainer.new()
	shop_scroll.name = "ShopScroll"
	shop_scroll.position = Vector2(400, 446)
	shop_scroll.size = Vector2(360, 200)
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(shop_scroll)
	var shop_vbox := VBoxContainer.new()
	shop_vbox.name = "ShopList"
	shop_scroll.add_child(shop_vbox)


func _refresh() -> void:
	_populate()


func _populate() -> void:
	var bm: Node = get_node_or_null(BASE_PATH)
	if bm == null:
		_set_status("BaseManager unavailable")
		return
	var snap: Dictionary = bm.get_snapshot()
	# Title
	if has_node("Title"):
		var base_name: String = str(snap.get("settlement_name", ""))
		var title_text: String = "[ Base — Level %d" % int(snap.get("level", 0))
		if not base_name.is_empty():
			title_text = "[ %s — Level %d" % [base_name, int(snap.get("level", 0))]
		$Title.text = title_text + " ]"
	# Capacity
	if has_node("CapLabel"):
		var residents: Array = snap.get("residents", [])
		$CapLabel.text = "Capacity: %d / %d   |   Residents: %d" % [
			residents.size(), bm.get_capacity(), residents.size()
		]
	# Residents
	var res_vbox: VBoxContainer = get_node_or_null("ResList")
	if res_vbox != null:
		for child in res_vbox.get_children():
			child.queue_free()
		for r in snap.get("residents", []):
			var row := Label.new()
			row.text = "• %s" % str(r)
			row.add_theme_color_override("font_color", Color.WHITE)
			res_vbox.add_child(row)
		if res_vbox.get_child_count() == 0:
			var empty := Label.new()
			empty.text = "(no residents — dismiss party members to send them here)"
			empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
			res_vbox.add_child(empty)
	# Settlement name field
	if has_node("NameEdit"):
		var can_name: bool = snap.get("residents", []).size() >= 20
		$NameEdit.editable = can_name
		$NameEdit.text = str(snap.get("settlement_name", ""))
		if not can_name:
			$NameEdit.placeholder_text = "(unlocks at 20 residents)"
		else:
			$NameEdit.placeholder_text = "Type a name..."
	# Upgrade info
	if has_node("UpgInfo"):
		var next_upg: Dictionary = bm.get_next_upgrade()
		if next_upg.is_empty():
			$UpgInfo.text = "Base is at max level (L%d)." % int(snap.get("level", 0))
		else:
			var ing_text: String = ""
			for ing in next_upg.get("cost_items", []):
				if not (ing is Dictionary):
					continue
				if ing_text != "":
					ing_text += "\n  "
				ing_text += "%dx %s" % [int(ing.get("qty", 1)), ing.get("item", "?")]
			$UpgInfo.text = "Next: %s (L%d required, %d EC, items below)\n\nItems:\n  %s" % [
				str(next_upg.get("name", "?")),
				int(next_upg.get("level_required", 0)),
				int(next_upg.get("cost_ec", 0)),
				ing_text
			]
	# Upgrade button enabled state
	if has_node("UpgButton"):
		var check: Dictionary = bm.can_upgrade()
		$UpgButton.disabled = not bool(check.get("ok", false))
		$UpgButton.text = "Upgrade" if not bool(check.get("ok", false)) else "Upgrade!"
		if not bool(check.get("ok", false)):
			_set_status(str(check.get("reason", "")))
	# Phase 7: shops
	_populate_shops(snap.get("residents", []))


func _populate_shops(residents: Array) -> void:
	var shop_vbox: VBoxContainer = get_node_or_null("ShopList")
	if shop_vbox == null:
		return
	for child in shop_vbox.get_children():
		child.queue_free()
	var bsm: Node = get_node_or_null(BASE_SHOP_PATH)
	if bsm == null:
		var ph := Label.new()
		ph.text = "(BaseShopManager unavailable)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		shop_vbox.add_child(ph)
		return
	var pm: Node = get_node_or_null(PARTY_PATH)
	if residents.is_empty():
		var ph := Label.new()
		ph.text = "(dismiss party members to send them here, then they may offer a shop)"
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		shop_vbox.add_child(ph)
		return
	for resident_id in residents:
		# Look up the NPC's archetype from PartyNPCManager
		var archetype: String = ""
		if pm != null and pm.has_method("get_npc"):
			var npc: Dictionary = pm.get_npc(resident_id)
			if not npc.is_empty():
				archetype = str(npc.get("role", ""))
		if archetype.is_empty():
			continue  # can't determine the offer
		var offer: Dictionary = bsm.get_offer(archetype)
		if offer.is_empty():
			continue  # no offer for this archetype
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		shop_vbox.add_child(row)
		var info := Label.new()
		var shop_type: String = str(offer.get("shop_type", ""))
		var open_now: bool = bsm.is_shop_open(shop_type)
		if open_now:
			info.text = "• %s (%s) — open!" % [archetype, shop_type]
		else:
			info.text = "• %s (%s) — %d EC + items" % [
				archetype, shop_type, int(offer.get("cost_ec", 0))
			]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var action_btn := Button.new()
		if open_now:
			action_btn.text = "Visit"
			action_btn.pressed.connect(_on_visit_shop_pressed.bind(shop_type, resident_id))
		else:
			action_btn.text = "Open"
			action_btn.pressed.connect(_on_open_shop_pressed.bind(resident_id, archetype))
		row.add_child(action_btn)


func _on_open_shop_pressed(resident_id: String, archetype: String) -> void:
	var bsm: Node = get_node_or_null(BASE_SHOP_PATH)
	if bsm == null:
		return
	var check: Dictionary = bsm.can_afford_offer(archetype)
	if not bool(check.get("ok", false)):
		_set_status("Can't afford: %s" % str(check.get("reason", "?")))
		return
	if bsm.open_shop_for_npc(resident_id, archetype):
		_set_status("Shop opened by %s" % resident_id)
		_refresh()
	else:
		_set_status("Could not open shop")


func _on_visit_shop_pressed(shop_type: String, npc_id: String) -> void:
	if BaseShopUIScript == null:
		return
	var ui: Control = BaseShopUIScript.new()
	ui.name = "BaseShopUI"
	ui.setup(shop_type, npc_id)
	ui.closed.connect(_on_shop_ui_closed)
	add_child(ui)


func _on_shop_ui_closed() -> void:
	pass


func _on_upgrade_pressed() -> void:
	var bm: Node = get_node_or_null(BASE_PATH)
	if bm == null:
		return
	if bm.upgrade():
		_set_status("Upgraded!")
		_refresh()
	else:
		var check: Dictionary = bm.can_upgrade()
		_set_status("Upgrade failed: %s" % str(check.get("reason", "?")))


func _on_name_button_pressed() -> void:
	if not has_node("NameEdit"):
		return
	var name: String = $NameEdit.text
	if name.is_empty():
		_set_status("Type a name first")
		return
	var bm: Node = get_node_or_null(BASE_PATH)
	if bm == null:
		return
	if bm.set_settlement_name(name):
		_set_status("Settlement named: %s" % name)
		_refresh()
	else:
		_set_status("Could not name settlement (need 20+ residents)")


func _on_close_pressed() -> void:
	if _hub != null and is_instance_valid(_hub) and _hub.has_method("leave_base"):
		_hub.leave_base()
	elif _hub != null and is_instance_valid(_hub) and _hub.has_method("_leave_base"):
		_hub._leave_base()
	else:
		queue_free()


func _set_status(msg: String) -> void:
	if has_node("StatusLabel"):
		$StatusLabel.text = msg
	print("[Base] %s" % msg)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
