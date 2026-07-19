class_name EquipmentDoll
extends Control
## Paper-doll equipment layout. Character sprite in center, equip slots
## arranged orbitally around it. Supports drag-and-drop from inventory
## and right-click to unequip.

const MT = preload("res://assets/ui/MasterTheme.gd")
const EQUIPMENT_PATH := "/root/EquipmentManager"
const INVENTORY_PATH := "/root/InventoryManager"

const PLAYER_ID := "player"

const SLOT_POSITIONS := {
	"head": Vector2(0.5, 0.1),
	"mainhand": Vector2(0.88, 0.4),
	"offhand": Vector2(0.12, 0.4),
	"chest": Vector2(0.5, 0.35),
	"acc1": Vector2(0.82, 0.15),
	"acc2": Vector2(0.18, 0.15),
	"legs": Vector2(0.5, 0.6),
	"boots": Vector2(0.5, 0.85),
	"tool": Vector2(0.12, 0.7),
}

const SLOT_LABELS := {
	"head": "Head", "chest": "Chest", "legs": "Legs", "boots": "Boots",
	"mainhand": "Mainhand", "offhand": "Offhand", "tool": "Tool",
	"acc1": "Acc 1", "acc2": "Acc 2",
}

const SLOT_ORDER := ["head", "chest", "legs", "boots", "mainhand", "offhand", "tool", "acc1", "acc2"]

var _slots: Dictionary = {}
var _character_sprite: TextureRect
var _tooltip: ItemTooltip
var _stats_label: Label

signal equipment_changed(slot: String, item_id: String)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchors_preset = Control.PRESET_FULL_RECT

	_build_layout()

	_tooltip = ItemTooltip.new()
	_tooltip.name = "DollTooltip"
	add_child(_tooltip)

	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	if em != null and em.has_signal("equipment_changed"):
		em.connect("equipment_changed", _on_equipment_changed)

	var dh := get_node_or_null("/root/DragHandler") as DragHandler
	if dh != null and dh.has_signal("drag_ended"):
		dh.connect("drag_ended", _on_drag_ended)

	refresh()


func _build_layout() -> void:
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", MT.panel(MT.BG_DEEP, MT.BORDER_STRONG, MT.RADIUS_LG, 2))
	add_child(bg)

	var inner := Control.new()
	inner.name = "DollArea"
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	bg.add_child(inner)

	# Character sprite center
	_character_sprite = TextureRect.new()
	_character_sprite.name = "CharacterSprite"
	_character_sprite.anchor_left = 0.5
	_character_sprite.anchor_top = 0.5
	_character_sprite.anchor_right = 0.5
	_character_sprite.anchor_bottom = 0.5
	_character_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_character_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_character_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_character_sprite)

	# Stats label at bottom
	_stats_label = Label.new()
	_stats_label.name = "StatsLabel"
	_stats_label.anchor_left = 0.0
	_stats_label.anchor_top = 1.0
	_stats_label.anchor_right = 1.0
	_stats_label.anchor_bottom = 1.0
	_stats_label.offset_top = -80
	_stats_label.add_theme_color_override("font_color", MT.TEXT_SECONDARY)
	_stats_label.add_theme_font_size_override("font_size", MT.FS_SMALL)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_stats_label)

	# Equipment slots
	var doll_area := inner
	doll_area.resized.connect(_reposition_slots)
	for slot_name in SLOT_ORDER:
		var slot := ItemSlot.new(52, SLOT_LABELS.get(slot_name, slot_name))
		slot.name = "EqSlot_%s" % slot_name
		slot.clicked.connect(_on_slot_clicked.bind(slot_name))
		slot.right_clicked.connect(_on_slot_unequip.bind(slot_name))
		slot.mouse_entered.connect(_on_slot_hover.bind(slot_name))
		slot.mouse_exited.connect(_on_slot_unhover)
		slot.add_to_group("drop_target")
		doll_area.add_child(slot)
		_slots[slot_name] = slot

	_reposition_slots()
	_update_character_portrait()


func _reposition_slots() -> void:
	var w := size.x if size.x > 0 else 400.0
	var h := size.y if size.y > 0 else 500.0
	var margin := 60.0
	var usable_w := w - margin * 2
	var usable_h := h - margin * 2 - 60
	for slot_name in SLOT_ORDER:
		var slot: ItemSlot = _slots.get(slot_name)
		if slot == null:
			continue
		var pos_ratio: Vector2 = SLOT_POSITIONS.get(slot_name, Vector2(0.5, 0.5))
		slot.position = Vector2(
			margin + pos_ratio.x * usable_w - slot.custom_minimum_size.x * 0.5,
			pos_ratio.y * usable_h - slot.custom_minimum_size.y * 0.5 + 20
		)


func _set_portrait(texture: Texture2D, size: int) -> void:
	_character_sprite.texture = texture
	var half := size / 2
	_character_sprite.custom_minimum_size = Vector2(size, size)
	_character_sprite.offset_left = -half
	_character_sprite.offset_top = -half
	_character_sprite.offset_right = half
	_character_sprite.offset_bottom = half


func _update_character_portrait() -> void:
	var gs := get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var char_data: Dictionary = gs.get_party_character_data() if gs.has_method("get_party_character_data") else {}
	var race: String = char_data.get("race", "human")
	var gender: String = char_data.get("gender", "male")
	var base := "res://assets/characters/%s_%s/%s_%s" % [race, gender, race, gender]
	# Try _south.tres (animated sprite frames)
	for tres_path in [base + "_south.tres", base + ".tres"]:
		var frames := load(tres_path) as SpriteFrames
		if frames != null and frames.has_animation("idle"):
			var frames_tex := frames.get_frame_texture("idle", 0) as Texture2D
			if frames_tex != null:
				_set_portrait(frames_tex, 160)
				return
	# Last fallback: try loading a frame PNG directly
	for dir_name in ["idle_south", "idle", "idle_s"]:
		var tex := SpriteLoader.load_texture(base + "/" + dir_name + "/frame_00.png")
		if tex != null:
			_set_portrait(tex, 160)
			return
	# No sprites available
	_character_sprite.texture = null


func refresh() -> void:
	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	if em == null:
		return
	var eq := em.get_equipment(PLAYER_ID) as Dictionary
	for slot_name in SLOT_ORDER:
		var slot: ItemSlot = _slots.get(slot_name)
		if slot == null:
			continue
		var item_id := str(eq.get(slot_name, ""))
		slot.item_id = item_id
		slot.count = 1 if item_id != "" else 0
	_refresh_stats()


func _refresh_stats() -> void:
	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	if em == null:
		_stats_label.text = ""
		return
	var gs := get_node_or_null("/root/GameState") as GameState
	var player_class: String = str(gs.get_character_data().get("class", "Survivor")) if is_instance_valid(gs) else "Survivor"
	var pm := get_node_or_null("/root/ProgressionManager") as ProgressionManager
	var player_level: int = pm.level if is_instance_valid(pm) else 1
	var mods: Dictionary = em.get_stat_mods(PLAYER_ID) if em.has_method("get_stat_mods") else {}
	var eq: Dictionary = em.get_equipment(PLAYER_ID)
	var armor_total := 0
	for s in ["head", "chest", "legs", "boots"]:
		var id_str := str(eq.get(s, ""))
		if id_str == "":
			continue
		var entry: Dictionary = em.resolve_item(id_str) if em.has_method("resolve_item") else {}
		armor_total += int(entry.get("armor", 0))
	var atk: int = em.get_attack(PLAYER_ID) if em.has_method("get_attack") else 0
	var defn: int = em.get_defense(PLAYER_ID) if em.has_method("get_defense") else 0
	_stats_label.text = "HP %d   MP %d   ATK %d   DEF %d   STR %d   INT %d   CON %d" % [
		em.get_max_hp(player_class, player_level, mods) if em.has_method("get_max_hp") else 0,
		em.get_max_mp(player_class, player_level, mods) if em.has_method("get_max_mp") else 0,
		atk, defn,
		int(mods.get("str", 0)),
		int(mods.get("int", 0)),
		int(mods.get("con", 0)),
	]


func _on_slot_clicked(_slot_name: String, _item_id: String) -> void:
	pass


func _on_slot_unequip(slot_name: String, item_id: String) -> void:
	if item_id == "":
		return
	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	var inv := get_node_or_null(INVENTORY_PATH) as InventoryManager
	if em == null:
		return
	em.unequip(PLAYER_ID, slot_name)
	if inv != null and inv.has_method("add_item"):
		inv.add_item(item_id, 1)
	refresh()
	equipment_changed.emit(slot_name, "")


func _on_slot_hover(slot_name: String) -> void:
	var slot: ItemSlot = _slots.get(slot_name)
	if slot == null or slot.item_id == "":
		return
	var pos := get_global_mouse_position() + Vector2(16, 16)
	_tooltip.show_for_item(slot.item_id, pos)


func _on_slot_unhover() -> void:
	_tooltip.hide_tooltip()


func _on_equipment_changed(_npc_id: String, _slot: String) -> void:
	refresh()


func _on_drag_ended(target: Node, item_id: String, _count: int) -> void:
	if target == null or item_id == "":
		return
	for slot_name in SLOT_ORDER:
		var slot: ItemSlot = _slots.get(slot_name)
		if slot != null and slot == target:
			try_equip_to_slot(item_id, slot_name)
			return


func get_slot(slot_name: String) -> ItemSlot:
	return _slots.get(slot_name)


func try_equip_to_slot(item_id: String, slot_name: String) -> bool:
	var em := get_node_or_null(EQUIPMENT_PATH) as EquipmentManager
	var inv := get_node_or_null(INVENTORY_PATH) as InventoryManager
	if em == null or inv == null:
		return false
	if em.equip(PLAYER_ID, item_id, slot_name):
		if inv.has_method("remove_item"):
			inv.remove_item(item_id, 1)
		refresh()
		return true
	return false
