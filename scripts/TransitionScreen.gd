## TransitionScreen — Full-screen fade overlay for scene transitions.
##
## Add to scene tree as a CanvasLayer. Call fade_out() → change scene → fade_in().
## Shows random loading tips during fade-out.
extends CanvasLayer

var _rect: ColorRect = null
var _tip_label: Label = null
var _loading_tips: Node = null  # LoadingTips autoload
var _is_fading: bool = false


func _ready() -> void:
	layer = 100

	# Full-screen black rect, starts transparent
	_rect = ColorRect.new()
	_rect.name = "FadeRect"
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

	# Tip label (centered bottom-third)
	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_tip_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	_tip_label.add_theme_font_size_override("font_size", 14)
	_tip_label.visible = false
	_tip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip_label.offset_bottom = -40
	_tip_label.offset_top = -80
	add_child(_tip_label)

	# Try to get LoadingTips autoload
	_loading_tips = get_node_or_null("/root/LoadingTips")


func fade_out(duration: float = 0.5) -> Signal:
	if _is_fading:
		return Signal()
	_is_fading = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Show a random tip
	if _loading_tips != null and _loading_tips.has_method("get_random_tip"):
		_tip_label.text = _loading_tips.get_random_tip()
		_tip_label.visible = true

	# Animate alpha 0 → 1
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, duration)
	return tween.finished


func fade_in(duration: float = 0.5) -> Signal:
	_tip_label.visible = false

	# Animate alpha 1 → 0
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 0.0, duration)
	tween.finished.connect(_on_fade_in_complete)
	return tween.finished


func _on_fade_in_complete() -> void:
	_is_fading = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Convenience: fade out → swap scene → fade in.
func transition_scene(scene_path: String, duration: float = 0.5) -> void:
	if _is_fading:
		return
	await fade_out(duration)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in(duration)


func is_fading() -> bool:
	return _is_fading
