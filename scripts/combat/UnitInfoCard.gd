## UnitInfoCard — Bottom-left panel showing the active player's
## portrait, name, class, level, HP/MP bars, and core stats
## (ATK, DEF, SPD, MOVE). Mirrors the reference's bottom-left card.
class_name UnitInfoCard extends Control

const PORTRAIT_SIZE := 64
const PANEL_BG_PATH := "res://assets/battle_ui/unit_card.png"
const PANEL_WIDTH := 288
const PANEL_HEIGHT := 192
const COLOR_BG := Color(0.05, 0.05, 0.08, 0.88)
const COLOR_BORDER := Color(0.30, 0.50, 0.70, 1.0)
const COLOR_LABEL := Color(0.75, 0.85, 1.0)
const COLOR_TEXT := Color.WHITE
const COLOR_HP := Color(0.30, 0.80, 0.35)
const COLOR_HP_LOW := Color(0.90, 0.30, 0.20)
const COLOR_MP := Color(0.40, 0.65, 0.95)

var _combat: Node = null
var _portrait: TextureRect
var _name_label: Label
var _class_label: Label
var _hp_bar_bg: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _mp_bar_bg: ColorRect
var _mp_fill: ColorRect
var _mp_label: Label
var _stat_labels: Dictionary = {}


func _ready() -> void:
	# Bottom-left, fixed size
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16
	offset_right = 16 + PANEL_WIDTH
	offset_top = -(PANEL_HEIGHT + 16)
	offset_bottom = -16
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()


func _build_children() -> void:
	# Background panel container with optional asset backdrop.
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
	# Inner HBox: portrait (left) + info column (right)
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	panel.add_child(hbox)
	hbox.add_theme_constant_override("separation", 10)
	# Portrait
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_portrait)
	# Right column: name, class, bars, stats
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)
	# Name + class row
	var name_row := HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)
	_name_label = _mk_label("Name", 13, COLOR_TEXT)
	name_row.add_child(_name_label)
	_class_label = _mk_label("Lv. 1", 10, COLOR_LABEL)
	name_row.add_child(_class_label)
	# HP row
	var hp_row := _add_bar_row(vbox, "HP", COLOR_HP, "_hp_bar_bg", "_hp_fill", "_hp_label")
	_hp_bar_bg = hp_row["bg"]
	_hp_fill = hp_row["fill"]
	_hp_label = hp_row["label"]
	# MP row
	var mp_row := _add_bar_row(vbox, "MP", COLOR_MP, "_mp_bar_bg", "_mp_fill", "_mp_label")
	_mp_bar_bg = mp_row["bg"]
	_mp_fill = mp_row["fill"]
	_mp_label = mp_row["label"]
	# Stats row (ATK | DEF | SPD | MOVE)
	var stats := GridContainer.new()
	stats.name = "Stats"
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 6)
	stats.add_theme_constant_override("v_separation", 2)
	vbox.add_child(stats)
	for stat in ["ATK", "DEF", "SPD", "MOVE"]:
		var lbl := _mk_label("%s %d" % [stat, 0], 9, COLOR_LABEL)
		stats.add_child(lbl)
		_stat_labels[stat] = lbl


func _add_bar_row(parent: Container, prefix: String, fill_color: Color, bg_name: String, fill_name: String, label_name: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = prefix + "Row"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var prefix_lbl := _mk_label(prefix, 9, COLOR_LABEL)
	prefix_lbl.custom_minimum_size = Vector2(18, 10)
	row.add_child(prefix_lbl)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.05, 0.05, 0.95)
	bg.custom_minimum_size = Vector2(0, 6)
	bg.size = Vector2(0, 6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set(bg_name, bg)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.size = Vector2(0, 6)
	fill.position = Vector2(0, 0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	set(fill_name, fill)
	var lbl := _mk_label("", 9, COLOR_TEXT)
	row.add_child(lbl)
	set(label_name, lbl)
	return {"bg": bg, "fill": fill, "label": lbl}


func _mk_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


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
	# Show the active unit's stats; fall back to first player unit
	# during enemy turns so the panel never goes empty.
	var active: Dictionary = _combat.get_active_unit()
	var unit: Dictionary = active
	if unit.is_empty() or str(unit.get("team", "")) != "player":
		for u in _combat.get_units():
			if str(u.get("team", "")) == "player" and int(u.get("hp", 0)) > 0:
				unit = u
				break
	if unit.is_empty():
		_clear()
		return
	_set_portrait(unit)
	_name_label.text = str(unit.get("name", "Recruit"))
	_class_label.text = "Lv. %d  %s" % [int(unit.get("level", 1)), str(unit.get("class", "?"))]
	# HP
	var hp: int = int(unit.get("hp", 0))
	var max_hp: int = int(unit.get("max_hp", hp))
	var hp_ratio: float = float(hp) / float(maxi(1, max_hp))
	var hp_width: float = _hp_bar_bg.size.x
	_hp_fill.size = Vector2(hp_width * hp_ratio, 6)
	_hp_fill.color = COLOR_HP if hp_ratio > 0.3 else COLOR_HP_LOW
	_hp_label.text = "%d/%d" % [hp, max_hp]
	# MP
	var mp: int = int(unit.get("mp", 0))
	var max_mp: int = int(unit.get("mp_max", mp))
	var mp_ratio: float = float(mp) / float(maxi(1, max_mp))
	var mp_width: float = _mp_bar_bg.size.x
	_mp_fill.size = Vector2(mp_width * mp_ratio, 6)
	_mp_label.text = "%d/%d" % [mp, max_mp]
	# Stats
	_stat_labels["ATK"].text = "ATK %d" % int(unit.get("attack_bonus", 0))
	_stat_labels["DEF"].text = "DEF %d" % int(unit.get("armor_bonus", 0))
	_stat_labels["SPD"].text = "SPD %d" % int(unit.get("speed", 0))
	_stat_labels["MOVE"].text = "MOVE %d" % int(unit.get("move", 0))


func _clear() -> void:
	_name_label.text = "—"
	_class_label.text = ""
	_hp_label.text = ""
	_mp_label.text = ""
	_hp_fill.size = Vector2.ZERO
	_mp_fill.size = Vector2.ZERO
	_portrait.texture = null
	for stat in _stat_labels:
		(_stat_labels[stat] as Label).text = "%s —" % stat


func _set_portrait(unit: Dictionary) -> void:
	var team: String = str(unit.get("team", "enemy"))
	var path: String = ""
	if team == "player":
		var race: String = str(unit.get("race", "human")).to_lower()
		var gender: String = str(unit.get("gender", "male")).to_lower()
		var race_dir := _character_race_dir(race)
		path = "res://assets/characters/%s/%s_%s_S.png" % [race_dir, race_dir, gender]
	else:
		var sprite_id: String = str(unit.get("sprite_id", unit.get("id", "")))
		path = "res://assets/mobs/%s.png" % sprite_id
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
	else:
		_portrait.texture = _placeholder_portrait()


func _placeholder_portrait() -> Texture2D:
	var img := Image.create(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.4, 1.0))
	for i in range(PORTRAIT_SIZE):
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(PORTRAIT_SIZE - 1, i, Color.BLACK)
		img.set_pixel(i, PORTRAIT_SIZE - 1, Color.BLACK)
	return ImageTexture.create_from_image(img)


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
