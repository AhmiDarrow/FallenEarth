## BattleHUD — Top status bar showing the active unit's portrait,
## name, HP/MP bars, and CT progress. Updates whenever
## CombatManager.active_unit_changed fires.
class_name BattleHUD extends Control

const PORTRAIT_SIZE := 56
const BAR_WIDTH := 220
const BAR_HEIGHT := 12
const MP_BAR_HEIGHT := 8
const CT_BAR_HEIGHT := 4

const COLOR_HP := Color(0.30, 0.80, 0.35)
const COLOR_HP_LOW := Color(0.90, 0.25, 0.20)
const COLOR_MP := Color(0.35, 0.55, 0.95)
const COLOR_CT := Color(0.95, 0.80, 0.30)
const COLOR_BG := Color(0.05, 0.05, 0.08, 0.88)
const COLOR_BORDER := Color(0.30, 0.30, 0.40, 1.0)
const PANEL_BG_PATH := "res://assets/battle_ui/battle_hud_panel.png"

var _combat: Node = null
var _portrait: TextureRect
var _name_label: Label
var _class_label: Label
var _hp_bar: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _mp_bar: ColorRect
var _mp_fill: ColorRect
var _mp_label: Label
var _ct_bar: ColorRect
var _ct_fill: ColorRect
var _ct_label: Label
var _active_glow: ColorRect


func _ready() -> void:
	# The HUD itself needs full-rect anchors so children that anchor
	# to 0.5 (centered) or 1.0 (right) have a real parent size to
	# anchor against. Without this, panel.anchor_left=0.5 collapses
	# to 0 (parent is 0x0) and the panel ends up at the top-left.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_children()


func _build_children() -> void:
	# Background panel — try the asset, fall back to styled rect.
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = 8
	panel.offset_bottom = 96
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
	# If we have a generated panel texture, use it as a NinePatchRect
	# behind the panel content; otherwise fall back to the flat style.
	if ResourceLoader.exists(PANEL_BG_PATH):
		# Use the asset as a centered texture behind the panel content.
		var bg_tex := TextureRect.new()
		bg_tex.name = "PanelBg"
		bg_tex.texture = load(PANEL_BG_PATH)
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.anchor_right = 1.0
		bg_tex.anchor_bottom = 1.0
		bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_tex.modulate = Color(1, 1, 1, 0.55)
		# Add it BEHIND the panel by inserting it at index 0.
		panel.add_child(bg_tex)
		panel.move_child(bg_tex, 0)
	panel.add_theme_stylebox_override("panel", sb)
	# Inner HBox
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	panel.add_child(hbox)
	hbox.add_theme_constant_override("separation", 12)
	# Portrait
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_portrait)
	# Active glow ring
	_active_glow = ColorRect.new()
	_active_glow.color = Color(0.95, 0.80, 0.30, 0.0)
	_active_glow.size = Vector2(PORTRAIT_SIZE + 8, PORTRAIT_SIZE + 8)
	_active_glow.position = Vector2(-4, -4)
	_active_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(_active_glow)
	# Right column (name, class, bars)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	# Name + class row
	var name_row := HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)
	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.add_theme_font_size_override("font_size", 16)
	name_row.add_child(_name_label)
	_class_label = Label.new()
	_class_label.name = "Class"
	_class_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_class_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_class_label.add_theme_constant_override("outline_size", 2)
	_class_label.add_theme_font_size_override("font_size", 11)
	_class_label.text = "Lv. 1"
	name_row.add_child(_class_label)
	# HP bar
	_hp_bar = _add_bar(vbox, "HP", BAR_WIDTH, BAR_HEIGHT, COLOR_HP, "_hp_bar", "_hp_fill", "_hp_label")
	# MP bar
	_mp_bar = _add_bar(vbox, "MP", BAR_WIDTH, MP_BAR_HEIGHT, COLOR_MP, "_mp_bar", "_mp_fill", "_mp_label")
	# CT bar (narrow)
	_ct_bar = _add_bar(vbox, "CT", BAR_WIDTH, CT_BAR_HEIGHT, COLOR_CT, "_ct_bar", "_ct_fill", "_ct_label")


func _add_bar(parent: Container, prefix: String, width: int, height: int, fill_color: Color,
		bg_name: String, fill_name: String, label_name: String) -> ColorRect:
	var row := HBoxContainer.new()
	row.name = prefix + "Row"
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := Label.new()
	label.text = prefix
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 9)
	label.custom_minimum_size = Vector2(20, height + 2)
	row.add_child(label)
	# Background bar (the "track")
	var bg := ColorRect.new()
	bg.name = prefix + "Bg"
	bg.color = Color(0.10, 0.05, 0.05, 0.95)
	bg.custom_minimum_size = Vector2(width, height)
	bg.size = Vector2(width, height)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	set(bg_name, bg)
	# Fill
	var fill := ColorRect.new()
	fill.name = prefix + "Fill"
	fill.color = fill_color
	fill.size = Vector2(width, height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	set(fill_name, fill)
	# Numeric label
	var val_label := Label.new()
	val_label.name = prefix + "Value"
	val_label.text = ""
	val_label.add_theme_color_override("font_color", Color.WHITE)
	val_label.add_theme_color_override("font_outline_color", Color.BLACK)
	val_label.add_theme_constant_override("outline_size", 2)
	val_label.add_theme_font_size_override("font_size", 8)
	row.add_child(val_label)
	set(label_name, val_label)
	return bg


## Wire to a CombatManager. The HUD auto-updates on
## `active_unit_changed` and `unit_updated`.
func setup(combat: Node) -> void:
	_combat = combat
	if _combat == null:
		return
	if _combat.has_signal("active_unit_changed"):
		_combat.active_unit_changed.connect(_on_active_unit_changed)
	if _combat.has_signal("unit_updated"):
		_combat.unit_updated.connect(_on_unit_updated)
	refresh()


func _on_active_unit_changed(_uid: String) -> void:
	refresh()


func _on_unit_updated(_uid: String) -> void:
	refresh()


func refresh() -> void:
	if _combat == null:
		return
	var active: Dictionary = _combat.get_active_unit()
	if active.is_empty():
		_name_label.text = "—"
		_class_label.text = ""
		_hp_label.text = ""
		_mp_label.text = ""
		_ct_label.text = ""
		_hp_fill.size = Vector2.ZERO
		_mp_fill.size = Vector2.ZERO
		_ct_fill.size = Vector2.ZERO
		_portrait.texture = null
		_active_glow.color = Color(0.95, 0.80, 0.30, 0.0)
		return
	var team: String = str(active.get("team", "enemy"))
	_name_label.text = str(active.get("name", "?"))
	_class_label.text = "Lv. %d  •  %s" % [int(active.get("level", 1)), str(active.get("class", "?"))]
	# HP
	var hp: int = int(active.get("hp", 0))
	var max_hp: int = int(active.get("max_hp", hp))
	var hp_ratio: float = float(hp) / float(maxi(1, max_hp))
	_hp_fill.size = Vector2(BAR_WIDTH * hp_ratio, BAR_HEIGHT)
	_hp_fill.color = COLOR_HP if hp_ratio > 0.3 else COLOR_HP_LOW
	_hp_label.text = "%d/%d" % [hp, max_hp]
	# MP
	var mp: int = int(active.get("mp", 0))
	var max_mp: int = int(active.get("mp_max", mp))
	var mp_ratio: float = float(mp) / float(maxi(1, max_mp))
	_mp_fill.size = Vector2(BAR_WIDTH * mp_ratio, MP_BAR_HEIGHT)
	_mp_label.text = "%d/%d" % [mp, max_mp]
	# CT — show progress toward 100
	var ct: int = int(active.get("ct", 0))
	var ct_ratio: float = clampf(float(ct) / 100.0, 0.0, 1.0)
	_ct_fill.size = Vector2(BAR_WIDTH * ct_ratio, CT_BAR_HEIGHT)
	_ct_label.text = "CT %d" % ct
	# Portrait
	_set_portrait(active)
	# Active glow
	_active_glow.color = Color(0.95, 0.80, 0.30, 0.35 if team == "player" else 0.55)


func _set_portrait(unit: Dictionary) -> void:
	var path: String = ""
	var team: String = str(unit.get("team", "enemy"))
	if team == "player":
		var race: String = str(unit.get("race", "human")).to_lower()
		var gender: String = str(unit.get("gender", "male")).to_lower()
		var race_dir: String = _character_race_dir(race)
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
