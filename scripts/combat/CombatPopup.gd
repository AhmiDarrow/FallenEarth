## CombatPopup — Floating text that pops up briefly: "MISS",
## "CRITICAL", "BACK ATTACK", "SIDE ATTACK", "DODGE", "COUNTER".
## Zooms in from small to large, then fades.
class_name CombatPopup extends Control

const DURATION := 1.0
const RISE_DISTANCE := 30.0

const COLORS := {
	"miss": Color(0.7, 0.7, 0.7),
	"dodge": Color(0.8, 0.85, 1.0),
	"critical": Color(1.0, 0.85, 0.3),
	"back_attack": Color(1.0, 0.5, 0.3),
	"side_attack": Color(1.0, 0.75, 0.4),
	"counter": Color(0.7, 0.95, 1.0),
}

var _label: Label
var _kind: String = "miss"
var _tween: Tween = null


func _ready() -> void:
	_build_children()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_children() -> void:
	_label = Label.new()
	_label.name = "Label"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_font_size_override("font_size", 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	add_child(_label)


## Show a popup at the given world position. kind is one of:
## "miss", "dodge", "critical", "back_attack", "side_attack", "counter".
func show_popup(kind: String, world_pos: Vector2) -> void:
	_kind = kind
	_label.text = _label_for(kind)
	_label.add_theme_color_override("font_color", COLORS.get(kind, Color.WHITE))
	position = world_pos - size * 0.5
	scale = Vector2(0.3, 0.3)
	modulate = Color(1, 1, 1, 0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	_tween.tween_interval(DURATION * 0.6)
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, 0.25)
	_tween.tween_callback(queue_free)


func _label_for(kind: String) -> String:
	match kind:
		"miss":
			return "MISS"
		"dodge":
			return "DODGE"
		"critical":
			return "CRITICAL"
		"back_attack":
			return "BACK!"
		"side_attack":
			return "SIDE"
		"counter":
			return "COUNTER"
		_:
			return kind.to_upper()
