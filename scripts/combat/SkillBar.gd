## SkillBar — Bottom-center bar showing the player's 3 active skills
## with numbered hotkeys (1, 2, 3), icons, names, and MP cost.
## Replaces the old "Skill" button + popup menu with explicit quick-action
## buttons matching the reference layout.
class_name SkillBar extends Control

const SLOT_COUNT := 3
const PANEL_BG_PATH := "res://assets/battle_ui/skill_bar.png"
const COLOR_LABEL := Color(0.75, 0.85, 1.0)
const COLOR_TEXT := Color.WHITE
const COLOR_BG := Color(0.05, 0.05, 0.08, 0.0)  # panel asset provides the bg
const COLOR_BORDER := Color(0.30, 0.50, 0.70, 1.0)
const COLOR_DISABLED := Color(0.40, 0.40, 0.45)
const COLOR_MP_OK := Color(0.40, 0.65, 0.95)
const COLOR_MP_LOW := Color(0.55, 0.30, 0.30)
const COLOR_HOTKEY := Color(0.95, 0.85, 0.40)

const ICON_BY_TYPE := {
	"physical": "res://assets/battle_ui/icon_attack.png",
	"magical": "res://assets/battle_ui/icon_magical.png",
	"heal_self": "res://assets/battle_ui/icon_heal.png",
	"heal_self_pct": "res://assets/battle_ui/icon_heal.png",
	"buff_self": "res://assets/battle_ui/icon_buff.png",
	"ranged": "res://assets/battle_ui/icon_ranged.png",
}
const FALLBACK_ICON := "res://assets/battle_ui/icon_skill.png"

var _combat: Node = null
var _slots: Array[Control] = []
var _slot_icons: Array[TextureRect] = []
var _slot_names: Array[Label] = []
var _slot_mp_labels: Array[Label] = []
var _slot_hotkey_labels: Array[Label] = []
# index -> enabled state at the time the slot was clicked. Used by
# _on_slot_pressed so we don't try to cast a disabled skill.
var _slot_enabled: Array[bool] = []


func _ready() -> void:
	# Bottom-center, full width, 96px tall, 16px from bottom.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -288
	offset_right = 288
	offset_top = -112
	offset_bottom = -16
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()


func _build_children() -> void:
	# Background panel container with the generated asset as backdrop.
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	if not ResourceLoader.exists(PANEL_BG_PATH):
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
		panel.add_child(bg_tex)
		panel.move_child(bg_tex, 0)
	panel.add_theme_stylebox_override("panel", sb)
	# Slot HBox
	var hbox := HBoxContainer.new()
	hbox.name = "Slots"
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 16
	hbox.offset_right = -16
	hbox.offset_top = 8
	hbox.offset_bottom = -8
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)
	# Three skill slots
	for i in range(SLOT_COUNT):
		var slot := _make_slot(i + 1)
		hbox.add_child(slot)
		_slots.append(slot)


func _make_slot(hotkey: int) -> Control:
	# Slot is a plain Control. The visual children (icon, hotkey,
	# name, MP) are added directly. Click handling goes through
	# the slot's gui_input signal — no Button child, so nothing
	# can occlude the visuals.
	var slot := Control.new()
	slot.name = "Slot_%d" % hotkey
	slot.custom_minimum_size = Vector2(160, 80)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	# Icon (top-center)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size = Vector2(40, 40)
	icon.position = Vector2(60, 6)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	_slot_icons.append(icon)
	# Hotkey badge (top-left)
	var hotkey_lbl := Label.new()
	hotkey_lbl.name = "Hotkey"
	hotkey_lbl.text = "%d" % hotkey
	hotkey_lbl.position = Vector2(6, 4)
	hotkey_lbl.add_theme_color_override("font_color", COLOR_HOTKEY)
	hotkey_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hotkey_lbl.add_theme_constant_override("outline_size", 3)
	hotkey_lbl.add_theme_font_size_override("font_size", 14)
	hotkey_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(hotkey_lbl)
	_slot_hotkey_labels.append(hotkey_lbl)
	# Skill name (center, below icon)
	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.text = ""
	name_lbl.position = Vector2(8, 48)
	name_lbl.size = Vector2(144, 16)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_lbl)
	_slot_names.append(name_lbl)
	# MP cost (bottom-right)
	var mp_lbl := Label.new()
	mp_lbl.name = "MP"
	mp_lbl.text = ""
	mp_lbl.position = Vector2(96, 60)
	mp_lbl.size = Vector2(60, 14)
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_lbl.add_theme_color_override("font_color", COLOR_MP_OK)
	mp_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	mp_lbl.add_theme_constant_override("outline_size", 2)
	mp_lbl.add_theme_font_size_override("font_size", 10)
	mp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(mp_lbl)
	_slot_mp_labels.append(mp_lbl)
	# Click handling — no Button child needed.
	slot.gui_input.connect(_on_slot_gui_input.bind(_slots.size()))
	_slot_enabled.append(true)
	return slot


func setup(combat: Node) -> void:
	_combat = combat
	if _combat == null:
		return
	if _combat.has_signal("active_unit_changed"):
		_combat.active_unit_changed.connect(refresh)
	if _combat.has_signal("unit_updated"):
		_combat.unit_updated.connect(refresh)
	if _combat.has_signal("subphase_changed"):
		_combat.subphase_changed.connect(refresh)
	refresh()


func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _slot_enabled[idx]:
		if _combat == null:
			return
		var abilities: Array[Dictionary] = _combat.get_player_abilities()
		if idx >= abilities.size():
			return
		var ab: Dictionary = abilities[idx]
		_combat.begin_skill_action(str(ab.get("id", "")))


func refresh(_arg: Variant = null) -> void:
	if _combat == null:
		return
	var abilities: Array[Dictionary] = _combat.get_player_abilities()
	var mp_info: Dictionary = _combat.get_player_mp()
	var current_mp: int = int(mp_info.get("current", 0))
	var player_turn: bool = _combat.is_player_active() and _combat.battle_phase == 0  # ACTIVE
	var targeting: bool = _combat.turn_subphase in [2, 3]  # TARGET_ATTACK, TARGET_SKILL
	# Reset all slots
	for i in range(SLOT_COUNT):
		var empty: bool = i >= abilities.size()
		_slots[i].visible = not empty
		_slot_enabled[i] = false
		if empty:
			continue
		var ab: Dictionary = abilities[i]
		var mp_cost: int = int(ab.get("mp_cost", 0))
		var can_afford: bool = current_mp >= mp_cost
		var enabled: bool = player_turn and can_afford and not targeting
		_slot_enabled[i] = enabled
		_slot_icons[i].texture = _load_icon(str(ab.get("type", "physical")))
		_slot_names[i].text = str(ab.get("name", "?"))
		_slot_names[i].modulate = COLOR_TEXT if enabled else COLOR_DISABLED
		_slot_mp_labels[i].text = "%d MP" % mp_cost
		_slot_mp_labels[i].modulate = COLOR_MP_OK if can_afford else COLOR_MP_LOW
		_slot_icons[i].modulate = COLOR_TEXT if enabled else COLOR_DISABLED
		_slot_hotkey_labels[i].modulate = COLOR_HOTKEY if enabled else COLOR_DISABLED


func _load_icon(skill_type: String) -> Texture2D:
	var path: String = ICON_BY_TYPE.get(skill_type, FALLBACK_ICON)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# Build a tiny placeholder if the icon is missing.
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.4, 0.5, 1.0))
	for i in range(32):
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(31, i, Color.BLACK)
		img.set_pixel(i, 31, Color.BLACK)
	return ImageTexture.create_from_image(img)
