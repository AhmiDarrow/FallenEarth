## EquipmentScreen — Interactive 9-slot equipment grid + inventory
## drag-to-equip.
##
## Phase 4 real version (was a placeholder in Phase 3). Layout:
##   - Left: 9-slot equipment grid (3x3) showing what's equipped per
##     slot. Each slot has a "Unequip" button if something is in it.
##   - Right: scrollable inventory list. Each item has an "Equip"
##     button. Clicking auto-equips to the first valid slot for the
##     item's category (weapon → mainhand, armor_helmet → head, etc.).
##   - Bottom: stats panel (HP, MP, attack, defense + speed bonus).
##
## Item-category detection:
##   - id starts with "weapon_" → mainhand
##   - id starts with "armor_" → parse slot from id (head / chest /
##     legs / boots)
##   - id in accessories data → acc1 (or acc2 if acc1 is taken)
##   - anything else (e.g. tools, consumables) → "tool" slot
class_name EquipmentScreen
extends Control

const INVENTORY_PATH := "/root/InventoryManager"
const EQUIPMENT_PATH := "/root/EquipmentManager"

const EQUIP_SLOTS := ["head", "chest", "legs", "boots", "mainhand", "offhand", "tool", "acc1", "acc2"]
const SLOT_LABELS := {
	"head": "Head", "chest": "Chest", "legs": "Legs", "boots": "Boots",
	"mainhand": "Mainhand", "offhand": "Offhand", "tool": "Tool",
	"acc1": "Acc 1", "acc2": "Acc 2",
}

const PLAYER_ID := "player"

var _slot_panels: Dictionary = {}  # slot -> PanelContainer
var _inventory_vbox: VBoxContainer
var _stats_label: Label
var _equipment_changed: bool = false  # dirty flag


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_refresh()


func _build_ui() -> void:
	# Layout: HBoxContainer splits into slots (left) and inventory (right).
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)
	# Left: equipment grid
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(360, 0)
	hbox.add_child(left_panel)
	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)
	var title := Label.new()
	title.text = "[ Equipment ]"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	title.add_theme_font_size_override("font_size", 24)
	left_vbox.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	left_vbox.add_child(grid)
	for slot in EQUIP_SLOTS:
		var slot_box := PanelContainer.new()
		slot_box.name = "Slot_%s" % slot
		slot_box.custom_minimum_size = Vector2(110, 96)
		grid.add_child(slot_box)
		_slot_panels[slot] = slot_box
	# Right: inventory list
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)
	var right_vbox := VBoxContainer.new()
	right_panel.add_child(right_vbox)
	var inv_title := Label.new()
	inv_title.text = "Inventory (click Equip to auto-slot)"
	inv_title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	right_vbox.add_child(inv_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)
	_inventory_vbox = VBoxContainer.new()
	_inventory_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_inventory_vbox)
	# Bottom: stats label
	_stats_label = Label.new()
	_stats_label.text = ""
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	_stats_label.add_theme_font_size_override("font_size", 14)
	left_vbox.add_child(_stats_label)


func _refresh() -> void:
	_refresh_slots()
	_refresh_inventory()
	_refresh_stats()


func _refresh_slots() -> void:
	var em: Node = get_node_or_null(EQUIPMENT_PATH)
	if em == null:
		return
	var eq: Dictionary = em.get_equipment(PLAYER_ID)
	for slot in EQUIP_SLOTS:
		var slot_box: PanelContainer = _slot_panels.get(slot)
		if slot_box == null:
			continue
		for child in slot_box.get_children():
			child.queue_free()
		var item_id: String = str(eq.get(slot, ""))
		var slot_vbox := VBoxContainer.new()
		slot_box.add_child(slot_vbox)
		var label := Label.new()
		label.text = "%s" % SLOT_LABELS.get(slot, slot)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		slot_vbox.add_child(label)
		if not item_id.is_empty():
			var item_label := Label.new()
			item_label.text = _short_id(item_id)
			item_label.add_theme_color_override("font_color", Color.WHITE)
			item_label.add_theme_font_size_override("font_size", 11)
			item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item_label.custom_minimum_size = Vector2(96, 32)
			slot_vbox.add_child(item_label)
			var unequip_btn := Button.new()
			unequip_btn.text = "Unequip"
			unequip_btn.custom_minimum_size = Vector2(96, 24)
			unequip_btn.pressed.connect(_on_unequip_pressed.bind(slot))
			slot_vbox.add_child(unequip_btn)
		else:
			var empty := Label.new()
			empty.text = "(empty)"
			empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			slot_vbox.add_child(empty)


func _refresh_inventory() -> void:
	if _inventory_vbox == null:
		return
	for child in _inventory_vbox.get_children():
		child.queue_free()
	var inv: Node = get_node_or_null(INVENTORY_PATH)
	if inv == null:
		return
	var snapshot: Array = inv.get_inventory_snapshot()
	# Filter to equippable items only
	for slot in snapshot:
		if not (slot is Dictionary):
			continue
		var item_id: String = str(slot.get("item_id", ""))
		if not _is_equippable(item_id):
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		_inventory_vbox.add_child(row)
		var info := Label.new()
		info.text = "%s x%d" % [item_id, int(slot.get("qty", 0))]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var equip_btn := Button.new()
		equip_btn.text = "Equip"
		equip_btn.pressed.connect(_on_equip_pressed.bind(item_id))
		row.add_child(equip_btn)


func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var em: Node = get_node_or_null(EQUIPMENT_PATH)
	if em == null:
		_stats_label.text = "(EquipmentManager unavailable)"
		return
	var mods: Dictionary = em.get_stat_mods(PLAYER_ID)
	var eq: Dictionary = em.get_equipment(PLAYER_ID)
	var armor_total: int = 0
	for slot in ["head", "chest", "legs", "boots"]:
		var item_id: String = str(eq.get(slot, ""))
		if item_id.is_empty():
			continue
		var entry: Dictionary = em._resolve_item(item_id)
		armor_total += int(entry.get("armor", 0))
	var atk: int = em.get_attack(PLAYER_ID)
	var defn: int = em.get_defense(PLAYER_ID)
	var hp: int = em.get_max_hp("", 1, mods)
	var mp: int = em.get_max_mp("", 1, mods)
	_stats_label.text = "HP %d   MP %d   ATK %d   DEF %d   STR %d   INT %d   CON %d" % [
		hp, mp, atk, defn,
		int(mods.get("str", 0)),
		int(mods.get("int", 0)),
		int(mods.get("con", 0)),
	]


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_equip_pressed(item_id: String) -> void:
	var em: Node = get_node_or_null(EQUIPMENT_PATH)
	if em == null:
		return
	var target_slot: String = _resolve_target_slot(item_id)
	if target_slot.is_empty():
		return
	if em.equip(PLAYER_ID, item_id, target_slot):
		_refresh()
		_equipment_changed = true


func _on_unequip_pressed(slot: String) -> void:
	var em: Node = get_node_or_null(EQUIPMENT_PATH)
	if em == null:
		return
	em.unequip(PLAYER_ID, slot)
	_refresh()
	_equipment_changed = true


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _is_equippable(item_id: String) -> bool:
	# Weapons, armor, accessories, and tools can be equipped
	if item_id.begins_with("weapon_") or item_id.begins_with("armor_"):
		return true
	# Accessories: looked up via the equipment manager
	var em: Node = get_node_or_null(EQUIPMENT_PATH)
	if em != null and em.get_accessory(item_id) != null and not em.get_accessory(item_id).is_empty():
		return true
	# Tools: any item in data/tools.json
	var tools_path := "res://data/tools.json"
	if ResourceLoader.exists(tools_path):
		var raw = load(tools_path)
		if raw != null:
			var data = raw.data if "data" in raw else raw
			if data is Dictionary:
				for t in data.get("tools", []):
					if t is Dictionary and str(t.get("id", "")) == item_id:
						return true
	return false


func _resolve_target_slot(item_id: String) -> String:
	# Weapon → mainhand; if mainhand taken, offhand.
	if item_id.begins_with("weapon_"):
		var eq: Dictionary = _get_equipment()
		if str(eq.get("mainhand", "")).is_empty():
			return "mainhand"
		if str(eq.get("offhand", "")).is_empty():
			return "offhand"
		return "mainhand"  # replace
	# Armor → parse slot from id (e.g. "armor_scavenger_head_t1" → "head")
	if item_id.begins_with("armor_"):
		var rest: String = item_id.substr("armor_".length())
		var parts: PackedStringArray = rest.split("_")
		# parts: [class, slot, tN]
		if parts.size() >= 2:
			var slot: String = parts[1]
			if slot in ["head", "chest", "legs", "boots"]:
				return slot
	# Accessory → acc1 (or acc2 if acc1 is taken)
	var em: Node = get_node_or_null(EQUIPMENT_PATH)
	if em != null and not em.get_accessory(item_id).is_empty():
		var eq2: Dictionary = _get_equipment()
		if str(eq2.get("acc1", "")).is_empty():
			return "acc1"
		if str(eq2.get("acc2", "")).is_empty():
			return "acc2"
		return "acc1"  # replace
	# Tool → tool slot
	if _is_tool(item_id):
		var eq3: Dictionary = _get_equipment()
		if str(eq3.get("tool", "")).is_empty():
			return "tool"
		return "tool"  # replace
	return ""


func _is_tool(item_id: String) -> bool:
	var path := "res://data/tools.json"
	if not ResourceLoader.exists(path):
		return false
	var raw = load(path)
	if raw == null:
		return false
	var data = raw.data if "data" in raw else raw
	if not (data is Dictionary):
		return false
	for t in data.get("tools", []):
		if t is Dictionary and str(t.get("id", "")) == item_id:
			return true
	return false


func _get_equipment() -> Dictionary:
	var em: Node = get_node_or_null(EQUIPMENT_PATH)
	if em == null:
		return {}
	return em.get_equipment(PLAYER_ID)


func _short_id(item_id: String) -> String:
	# Trim the id for the slot label
	var s: String = item_id
	if s.begins_with("weapon_"):
		s = s.substr("weapon_".length())
	elif s.begins_with("armor_"):
		s = s.substr("armor_".length())
	# Take last 16 chars
	if s.length() > 20:
		s = s.substr(s.length() - 20)
	return s
