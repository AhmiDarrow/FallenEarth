## TurnOrderBar — Horizontal bar at the top of the battle scene showing
## the next 6 units in CT order with their portraits and HP bars.
## Replaces the old right-side TurnOrderPanel.
class_name TurnOrderBar extends Control

const SLOT_SIZE := 56
const SLOT_SPACING := 6
const PANEL_BG_PATH := "res://assets/battle_ui/turn_order_bar.png"
const COLOR_BG := Color(0.05, 0.05, 0.08, 0.88)
const COLOR_BORDER := Color(0.30, 0.50, 0.70, 1.0)
const COLOR_ACTIVE := Color(0.95, 0.80, 0.30, 0.95)
const COLOR_PLAYER := Color(0.30, 0.80, 0.40)
const COLOR_ENEMY := Color(0.92, 0.40, 0.40)
const COLOR_ALLY := Color(0.40, 0.60, 0.95)
const COLOR_BOSS := Color(0.80, 0.40, 0.95)

var _combat: Node = null
var _slots: Array[Control] = []
var _hsep: HSeparator


func _ready() -> void:
	# Top-center, full width minus a 16px margin, 96px tall.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -340
	offset_right = 340
	offset_top = 8
	offset_bottom = 104
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()


func _build_children() -> void:
	# Background panel (use generated asset if available, else fallback).
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = COLOR_BORDER
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	if ResourceLoader.exists(PANEL_BG_PATH):
		var bg_tex := TextureRect.new()
		bg_tex.name = "PanelBg"
		bg_tex.texture = load(PANEL_BG_PATH)
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.anchor_right = 1.0
		bg_tex.anchor_bottom = 1.0
		bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_tex.modulate = Color(1, 1, 1, 0.55)
		panel.add_child(bg_tex)
		panel.move_child(bg_tex, 0)
	panel.add_theme_stylebox_override("panel", sb)
	# Horizontal slot row.
	var hbox := HBoxContainer.new()
	hbox.name = "Slots"
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 12
	hbox.offset_right = -12
	hbox.offset_top = 6
	hbox.offset_bottom = -6
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", SLOT_SPACING)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)
	# Six slots
	for i in range(6):
		var slot := _make_slot()
		hbox.add_child(slot)
		_slots.append(slot)


func _make_slot() -> Control:
	# Slot is just a Control with a Portrait + ActiveGlow. HP and
	# CT bars are intentionally omitted here — CombatFeedback already
	# draws them above the units on the grid, and trying to pack
	# another HP+CT bar into the 56x72 slot was making the layout
	# fight the generated bar backdrop.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Active highlight (hidden by default)
	var active_glow := ColorRect.new()
	active_glow.name = "ActiveGlow"
	active_glow.color = Color(COLOR_ACTIVE.r, COLOR_ACTIVE.g, COLOR_ACTIVE.b, 0.0)
	active_glow.size = Vector2(SLOT_SIZE + 6, SLOT_SIZE + 6)
	active_glow.position = Vector2(-3, -3)
	active_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_glow.z_index = -1
	slot.add_child(active_glow)
	# Portrait texture rect (fills the slot)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	portrait.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	portrait.position = Vector2(2, 2)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(portrait)
	return slot


func setup(combat: Node) -> void:
	_combat = combat
	if _combat == null:
		return
	if _combat.has_signal("active_unit_changed"):
		_combat.active_unit_changed.connect(refresh)
	if _combat.has_signal("unit_updated"):
		_combat.unit_updated.connect(refresh)
	refresh()


func refresh(_arg: Variant = null) -> void:
	if _combat == null:
		return
	# Clear all slots
	for slot in _slots:
		slot.visible = false
		var portrait: TextureRect = slot.get_node("Portrait")
		portrait.texture = null
		var hp_fill: ColorRect = slot.get_node("HPBg/HPFill")
		hp_fill.size = Vector2(0, 4)
		var ct_bar: ColorRect = slot.get_node("CTBar")
		ct_bar.size = Vector2(0, 2)
		var active_glow: ColorRect = slot.get_node("ActiveGlow")
		active_glow.color = Color(COLOR_ACTIVE.r, COLOR_ACTIVE.g, COLOR_ACTIVE.b, 0.0)
	# Sort units by descending CT
	var units_sorted: Array = (_combat.get_units() as Array).duplicate()
	units_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ct_a: int = int(a.get("ct", 0))
		var ct_b: int = int(b.get("ct", 0))
		if ct_a == ct_b:
			return int(a.get("speed", 0)) > int(b.get("speed", 0))
		return ct_a > ct_b
	)
	for i in range(mini(6, units_sorted.size())):
		var unit: Dictionary = units_sorted[i]
		if int(unit.get("hp", 0)) <= 0:
			continue
		_fill_slot(_slots[i], unit)


func _fill_slot(slot: Control, unit: Dictionary) -> void:
	slot.visible = true
	var portrait: TextureRect = slot.get_node("Portrait")
	_set_portrait(portrait, unit)
	# Active highlight
	var active_glow: ColorRect = slot.get_node("ActiveGlow")
	var is_active: bool = str(unit.get("id", "")) == str(_combat.active_unit_id)
	active_glow.color = Color(COLOR_ACTIVE.r, COLOR_ACTIVE.g, COLOR_ACTIVE.b, 0.6 if is_active else 0.0)


func _set_portrait(portrait: TextureRect, unit: Dictionary) -> void:
	var team: String = str(unit.get("team", "enemy"))
	var path: String = ""
	if team == "player":
		var race: String = str(unit.get("race", "human")).to_lower()
		var gender: String = str(unit.get("gender", "male")).to_lower()
		# Folder structure is {race}_{gender}/{race}_{gender}_S.png
		path = "res://assets/characters/%s_%s/%s_%s_S.png" % [race, gender, race, gender]
	else:
		var sprite_id: String = str(unit.get("sprite_id", unit.get("id", "")))
		path = "res://assets/mobs/%s.png" % sprite_id
	if ResourceLoader.exists(path):
		portrait.texture = load(path)
	else:
		portrait.texture = _placeholder_portrait(team)


func _placeholder_portrait(team: String) -> Texture2D:
	var img := Image.create(SLOT_SIZE - 4, SLOT_SIZE - 4, false, Image.FORMAT_RGBA8)
	img.fill(_team_color_str(team).darkened(0.5))
	for i in range(SLOT_SIZE - 4):
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(SLOT_SIZE - 5, i, Color.BLACK)
		img.set_pixel(i, SLOT_SIZE - 5, Color.BLACK)
	return ImageTexture.create_from_image(img)


func _team_color_str(team: String) -> Color:
	if team == "player":
		return COLOR_PLAYER
	if team == "ally":
		return COLOR_ALLY
	return COLOR_ENEMY


func _team_color(unit: Dictionary) -> Color:
	if bool(unit.get("is_boss", false)):
		return COLOR_BOSS
	var team: String = str(unit.get("team", ""))
	if team == "player":
		return COLOR_PLAYER
	if team == "ally":
		return COLOR_ALLY
	return COLOR_ENEMY


static func _character_race_dir(race: String) -> String:
	match race:
		"human", "upworlder":
			return "human"
		"mutant":
			return "mutant"
		"ai", "sentientai":
			return "sentientai"
		"cyborg":
			return "cyborg"
		"chthon":
			return "chthon"
		"vesper", "vesperid":
			return "vesperid"
		"nullborn":
			return "nullborn"
		"revenant":
			return "revenant"
		_:
			return "human"
