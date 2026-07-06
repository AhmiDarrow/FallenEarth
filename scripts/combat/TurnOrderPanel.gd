## TurnOrderPanel — Vertical sidebar showing the next 6 units in
## CT order, with mini-portraits and CT progress. Highlights the
## active unit. Click a unit to peek at their stats.
class_name TurnOrderPanel extends Control

const ROW_HEIGHT := 38
const PORTRAIT_SIZE := 32
const PANEL_WIDTH := 220

const COLOR_BG := Color(0.05, 0.05, 0.08, 0.88)
const COLOR_BORDER := Color(0.30, 0.30, 0.40, 1.0)
const COLOR_ACTIVE := Color(0.95, 0.80, 0.30, 0.4)
const COLOR_ENEMY := Color(0.9, 0.3, 0.3)
const COLOR_PLAYER := Color(0.3, 0.8, 0.4)
const COLOR_BOSS := Color(0.7, 0.3, 0.9)
const COLOR_TEXT := Color.WHITE
const COLOR_TEXT_DIM := Color(0.65, 0.65, 0.7)


var _combat: Node = null
var _vbox: VBoxContainer


func _ready() -> void:
	_build_children()


func _build_children() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -PANEL_WIDTH - 8
	offset_right = -8
	offset_top = -200
	offset_bottom = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	panel.add_theme_stylebox_override("panel", sb)
	_vbox = VBoxContainer.new()
	_vbox.name = "List"
	_vbox.add_theme_constant_override("separation", 2)
	panel.add_child(_vbox)
	var header := Label.new()
	header.text = "Turn Order"
	header.add_theme_color_override("font_color", COLOR_TEXT)
	header.add_theme_color_override("font_outline_color", Color.BLACK)
	header.add_theme_constant_override("outline_size", 2)
	header.add_theme_font_size_override("font_size", 12)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(header)


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
	# Clear existing rows
	for child in _vbox.get_children():
		if child.name == "TurnOrderHeader":
			continue
		child.queue_free()
	# Sort units by descending CT so the next 6 are at the top.
	var units_sorted: Array = (_combat.get_units() as Array).duplicate()
	units_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ct_a: int = int(a.get("ct", 0))
		var ct_b: int = int(b.get("ct", 0))
		if ct_a == ct_b:
			return int(a.get("speed", 0)) > int(b.get("speed", 0))
		return ct_a > ct_b
	)
	for unit in units_sorted.slice(0, 6):
		if int(unit.get("hp", 0)) <= 0:
			continue
		_vbox.add_child(_build_row(str(unit.get("id", "?")), unit))


func _find_unit(uid: String) -> Dictionary:
	if _combat == null:
		return {}
	for u in _combat.get_units():
		if str(u.get("id", "")) == uid:
			return u
	return {}


func _build_row(uid: String, unit: Dictionary) -> Control:
	var row := Control.new()
	row.name = "Row_%s" % uid
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size = Vector2(0, ROW_HEIGHT)
	if uid == str(_combat.active_unit_id):
		var hl := ColorRect.new()
		hl.color = COLOR_ACTIVE
		hl.size = Vector2(PANEL_WIDTH - 8, ROW_HEIGHT)
		hl.position = Vector2(0, 0)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hl)
	# Portrait
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.position = Vector2(4, 3)
	portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_portrait(portrait, unit)
	row.add_child(portrait)
	# Name + class
	var name := Label.new()
	name.text = str(unit.get("name", "?"))
	name.position = Vector2(PORTRAIT_SIZE + 10, 2)
	name.size = Vector2(PANEL_WIDTH - PORTRAIT_SIZE - 16, 16)
	name.add_theme_color_override("font_color", _team_color(unit))
	name.add_theme_color_override("font_outline_color", Color.BLACK)
	name.add_theme_constant_override("outline_size", 2)
	name.add_theme_font_size_override("font_size", 10)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name)
	# CT bar
	var ct_bg := ColorRect.new()
	ct_bg.color = Color(0.1, 0.07, 0.05, 0.9)
	ct_bg.position = Vector2(PORTRAIT_SIZE + 10, 22)
	ct_bg.size = Vector2(PANEL_WIDTH - PORTRAIT_SIZE - 16, 4)
	ct_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ct_bg)
	var ct_fill := ColorRect.new()
	ct_fill.color = Color(0.95, 0.80, 0.30)
	var ct: int = int(unit.get("ct", 0))
	var ratio: float = clampf(float(ct) / 100.0, 0.0, 1.0)
	ct_fill.size = Vector2((PANEL_WIDTH - PORTRAIT_SIZE - 16) * ratio, 4)
	ct_fill.position = Vector2(0, 0)
	ct_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ct_bg.add_child(ct_fill)
	var ct_label := Label.new()
	ct_label.text = "CT %d" % ct
	ct_label.position = Vector2(PANEL_WIDTH - 50, 22)
	ct_label.size = Vector2(40, 12)
	ct_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	ct_label.add_theme_color_override("font_outline_color", Color.BLACK)
	ct_label.add_theme_constant_override("outline_size", 2)
	ct_label.add_theme_font_size_override("font_size", 8)
	ct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ct_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ct_label)
	return row


func _set_portrait(portrait: TextureRect, unit: Dictionary) -> void:
	var team: String = str(unit.get("team", "enemy"))
	var path: String = ""
	if team == "player":
		var race: String = str(unit.get("race", "human")).to_lower()
		var gender: String = str(unit.get("gender", "male")).to_lower()
		var race_dir: String = _character_race_dir(race)
		path = "res://assets/characters/%s/%s_%s_S.png" % [race_dir, race_dir, gender]
	else:
		var sprite_id: String = str(unit.get("sprite_id", unit.get("id", "")))
		path = "res://assets/mobs/%s.png" % sprite_id
	if ResourceLoader.exists(path):
		portrait.texture = load(path)
	else:
		portrait.texture = _placeholder()


func _team_color(unit: Dictionary) -> Color:
	if bool(unit.get("is_boss", false)):
		return COLOR_BOSS
	if str(unit.get("team", "enemy")) == "player":
		return COLOR_PLAYER
	return COLOR_ENEMY


func _placeholder() -> Texture2D:
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
