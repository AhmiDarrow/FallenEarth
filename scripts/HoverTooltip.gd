## HoverTooltip — Small Label that follows the mouse after a 1-second dwell.
##
## Phase 1b. Lifecycle:
##   - idle: _current_target == null, label hidden
##   - hovered: cursor on a target; _hover_start_time set; label still hidden
##   - showing: 1+ seconds on same target; label visible, follows mouse
##   - changed: target switched; reset _hover_start_time, restart dwell
##
## The actual hit-testing (deciding what's under the cursor) is done by
## HubWorld.hit_test_at_cell() — this script just renders the result.
## That keeps the world-state logic out of the UI script.
class_name HoverTooltip
extends Control

const DWELL_MS: int = 1000  # 1 second
const MOUSE_OFFSET: Vector2 = Vector2(14, 14)

var _label: Label
var _current_target: String = ""
var _hover_start_time: int = 0
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _visible: bool = false


func _ready() -> void:
	# Don't capture mouse input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor top-left, full size (label will be positioned manually)
	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	_label = Label.new()
	_label.name = "Text"
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_constant_override("font_size", 14)
	_label.position = MOUSE_OFFSET
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	visible = false


## Called by HubWorld each frame with the current world mouse position and
## the hit-test result text. Pass empty string if nothing is under the cursor.
func update(mouse_pos: Vector2, target_text: String) -> void:
	_last_mouse_pos = mouse_pos
	# Always position the label at the mouse (even when hidden) so it's
	# ready to appear without a frame of lag.
	position = mouse_pos

	if target_text.is_empty():
		# No target → hide and reset
		if _visible:
			_label.visible = false
			visible = false
			_visible = false
		_current_target = ""
		_hover_start_time = 0
		return

	# Target changed? Reset dwell timer.
	if target_text != _current_target:
		_current_target = target_text
		_hover_start_time = Time.get_ticks_msec()
		# Hide immediately when target switches — we don't show until the
		# dwell elapses on the new target.
		if _visible:
			_label.visible = false
			visible = false
			_visible = false
		return

	# Same target. Check dwell.
	var elapsed: int = Time.get_ticks_msec() - _hover_start_time
	if elapsed < DWELL_MS:
		return

	# Dwell elapsed; show the tooltip.
	if not _visible:
		_label.text = target_text
		_label.visible = true
		visible = true
		_visible = true


## Returns the current target text, or "" if none. Used by tests / debug.
func get_current_target() -> String:
	return _current_target


func is_showing() -> bool:
	return _visible
