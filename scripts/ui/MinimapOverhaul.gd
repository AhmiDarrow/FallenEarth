## MinimapOverhaul — Icon-based minimap showing NPCs, buildings, rifts.
##
## Replaces basic minimap with colored dot icons for entities.
## Auto-scales to player position.
class_name MinimapOverhaul
extends Control

const SIZE := 120.0
const ICON_SIZE := 2.0
const BG_COLOR := Color(0.04, 0.04, 0.06, 0.85)
const PLAYER_COLOR := Color(0.4, 0.85, 1.0)
const NPC_COLOR := Color(0.3, 0.6, 1.0)
const BUILDING_COLOR := Color(0.6, 0.45, 0.3)
const RIFT_COLOR := Color(1.0, 0.3, 0.3)
const RESOURCE_COLOR := Color(0.3, 0.8, 0.3)
const GRID_COLOR := Color(0.15, 0.15, 0.18, 0.4)

var _player_pos: Vector2 = Vector2.ZERO
var _npcs: Array[Dictionary] = []
var _buildings: Array[Dictionary] = []
var _rifts: Array[Dictionary] = []
var _resources: Array[Dictionary] = []
var _view_range: float = 100.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
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
