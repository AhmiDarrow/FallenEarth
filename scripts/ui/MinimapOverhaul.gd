class_name MinimapOverhaul
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")

## MinimapOverhaul — Icon-based minimap showing NPCs, buildings, rifts.
##
## Replaces basic minimap with colored dot icons for entities.
## Auto-scales to player position.

const SIZE := 160.0
const ICON_SIZE := 3.0
var BG_COLOR := MT.OVERLAY_DARK
var PLAYER_COLOR := MT.MM_PLAYER
var NPC_COLOR := MT.ACCENT_SECONDARY
var BUILDING_COLOR := MT.BORDER_STRONG
var RIFT_COLOR := MT.MM_MOB_HOSTILE
var RESOURCE_COLOR := MT.ACCENT_SUCCESS
var GRID_COLOR := MT.MM_GRID_LINE

var _player_pos: Vector2 = Vector2.ZERO
var _npcs: Array[Dictionary] = []
var _buildings: Array[Dictionary] = []
var _rifts: Array[Dictionary] = []
var _resources: Array[Dictionary] = []
var _view_range: float = 100.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -SIZE - 12
	offset_top = 12
	offset_right = -12
	offset_bottom = SIZE + 12
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func update_data(player_pos: Vector2, npcs: Array, buildings: Array, rifts: Array, resources: Array) -> void:
	_player_pos = player_pos
	_npcs = npcs
	_buildings = buildings
	_rifts = rifts
	_resources = resources
	queue_redraw()


func set_view_range(range_val: float) -> void:
	_view_range = range_val
	queue_redraw()


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), BG_COLOR)

	# Grid lines
	for i in range(5):
		var x: float = SIZE * i / 4.0
		draw_line(Vector2(x, 0), Vector2(x, SIZE), GRID_COLOR, 1.0)
		var y: float = SIZE * i / 4.0
		draw_line(Vector2(0, y), Vector2(SIZE, y), GRID_COLOR, 1.0)

	# Center player
	var center := Vector2(SIZE * 0.5, SIZE * 0.5)

	# Draw buildings
	for b in _buildings:
		var bpos: Vector2 = b.get("pos", Vector2.ZERO)
		var offset: Vector2 = (bpos - _player_pos) / _view_range * SIZE * 0.5
		if offset.length() < SIZE * 0.5:
			draw_circle(center + offset, ICON_SIZE + 1.0, BUILDING_COLOR)

	# Draw resources
	for r in _resources:
		var rpos: Vector2 = r.get("pos", Vector2.ZERO)
		var offset: Vector2 = (rpos - _player_pos) / _view_range * SIZE * 0.5
		if offset.length() < SIZE * 0.5:
			draw_circle(center + offset, ICON_SIZE, RESOURCE_COLOR)

	# Draw NPCs
	for n in _npcs:
		var npos: Vector2 = n.get("pos", Vector2.ZERO)
		var offset: Vector2 = (npos - _player_pos) / _view_range * SIZE * 0.5
		if offset.length() < SIZE * 0.5:
			draw_circle(center + offset, ICON_SIZE, NPC_COLOR)

	# Draw rifts
	for r in _rifts:
		var rpos: Vector2 = r.get("pos", Vector2.ZERO)
		var offset: Vector2 = (rpos - _player_pos) / _view_range * SIZE * 0.5
		if offset.length() < SIZE * 0.5:
			draw_circle(center + offset, ICON_SIZE + 1.0, RIFT_COLOR)

	# Draw player (always centered)
	draw_circle(center, 3.0, PLAYER_COLOR)
	draw_circle(center, 1.5, Color.WHITE)
