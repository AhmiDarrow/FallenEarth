## BattleResultPanel — Styled victory/defeat panel with the
## biome-themed backdrop. Substitutes the simple result_label in
## TacticalCombat.
class_name BattleResultPanel extends Control

const VICTORY := "victory"
const DEFEAT := "defeat"

const PANEL_BG := Color(0.05, 0.04, 0.08, 0.95)
const COLOR_BORDER := Color(0.30, 0.30, 0.40, 1.0)
const COLOR_VICTORY := Color(0.45, 0.85, 0.50)
const COLOR_DEFEAT := Color(0.92, 0.30, 0.30)
const COLOR_LOOT := Color(1.0, 0.85, 0.40)
const VICTORY_BG_PATH := "res://assets/battle_ui/victory_panel.png"
const DEFEAT_BG_PATH := "res://assets/battle_ui/defeat_panel.png"

var _kind: String = VICTORY
var _title_label: Label
var _body_label: RichTextLabel
var _continue_btn: Button
var _panel: PanelContainer
var _biome: String = "Ash Wastes"


func _ready() -> void:
	_build_children()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build_children() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -240
	offset_right = 240
	offset_top = -120
	offset_bottom = 120
	# Background dim
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = COLOR_BORDER
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", COLOR_VICTORY)
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_label.add_theme_constant_override("outline_size", 4)
	_title_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(_title_label)
	_body_label = RichTextLabel.new()
	_body_label.name = "Body"
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(_body_label)
	_continue_btn = Button.new()
	_continue_btn.name = "Continue"
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(160, 36)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_continue_btn)


## Set the panel's outcome. body_bbcode is a BBCode string for the
## result body (XP, loot, level-up text).
func set_outcome(kind: String, title: String, body_bbcode: String) -> void:
	_kind = kind
	var path: String = VICTORY_BG_PATH if kind == VICTORY else DEFEAT_BG_PATH
	if ResourceLoader.exists(path):
		# Replace the existing bg texture if any, else create one.
		var existing: Node = _panel.get_node_or_null("Bg")
		if existing != null:
			existing.queue_free()
		var bg := TextureRect.new()
		bg.name = "Bg"
		bg.texture = load(path)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(bg)
		_panel.move_child(bg, 0)
	if kind == VICTORY:
		_title_label.text = "VICTORY"
		_title_label.add_theme_color_override("font_color", COLOR_VICTORY)
		_panel.get_theme_stylebox("panel").border_color = COLOR_VICTORY
	else:
		_title_label.text = "DEFEAT"
		_title_label.add_theme_color_override("font_color", COLOR_DEFEAT)
		_panel.get_theme_stylebox("panel").border_color = COLOR_DEFEAT
	_body_label.text = title + "\n" + body_bbcode
	visible = true
	_pop_in()


func set_continue_handler(callable: Callable) -> void:
	if _continue_btn.pressed.is_connected(_on_continue_pressed):
		_continue_btn.pressed.disconnect(_on_continue_pressed)
	_continue_btn.pressed.connect(callable)


func _on_continue_pressed() -> void:
	pass


func _pop_in() -> void:
	scale = Vector2(0.6, 0.6)
	modulate = Color(1, 1, 1, 0)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
