## RiftInstance — Procedural explorable dungeon: rooms, encounters, boss at end, core to close.
class_name RiftInstance extends Control

const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const DungeonGen = preload("res://scripts/RiftDungeonGenerator.gd")

var _rift_id: String = "rift_001"
var _biome_key: String = "Ash Wastes"
var _entry_q: int = 0
var _entry_r: int = 0
var _entry_local_x: int = 256
var _entry_local_y: int = 256
var _dungeon: Dictionary = {}
var _player_x: int = 0
var _player_y: int = 0
var _rift_cleared: bool = false

var _runner: Node = null
var _grid_cells: Array[Button] = []
var _dungeon_w: int = 15
var _dungeon_h: int = 11
var _pause_menu: PauseMenu = null

@onready var status_label: RichTextLabel = $MainVBox/StatusLabel as RichTextLabel
@onready var grid_container: GridContainer = $MainVBox/GridPanel/GridContainer as GridContainer
@onready var loot_panel: VBoxContainer = $MainVBox/LootPanel as VBoxContainer
@onready var loot_label: RichTextLabel = $MainVBox/LootPanel/LootLabel as RichTextLabel
@onready var clear_btn: Button = $MainVBox/ActionsHBox/ClearRiftButton as Button
@onready var back_btn: Button = $MainVBox/ActionsHBox/BackButton as Button
@onready var instructions_label: RichTextLabel = $MainVBox/InstructionsLabel as RichTextLabel
@onready var log_label: RichTextLabel = $MainVBox/LogLabel as RichTextLabel


func _ready() -> void:
	print("[RiftInstance] Procedural rift dungeon loading.")

	if has_node("/root/RiftRunner"):
		_runner = get_node("/root/RiftRunner")
	else:
		_runner = load("res://scripts/RiftRunner.gd").new()
		add_child(_runner)

	_load_rift_context()
	_ensure_dungeon()
	_enter_dungeon_mode()


func _load_rift_context() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var ctx: Dictionary = gs.get_pending_rift()
		if not ctx.is_empty():
			_rift_id = str(ctx.get("rift_id", _rift_id))
			_biome_key = str(ctx.get("biome_key", _biome_key))
			_entry_q = int(ctx.get("entry_q", 0))
			_entry_r = int(ctx.get("entry_r", 0))
			_entry_local_x = int(ctx.get("entry_local_x", ctx.get("local_x", 256)))
			_entry_local_y = int(ctx.get("entry_local_y", ctx.get("local_y", 256)))
			if ctx.get("dungeon") is Dictionary:
				_dungeon = (ctx["dungeon"] as Dictionary).duplicate(true)
			return
	print("[RiftInstance] No pending rift context — using defaults.")


func _ensure_dungeon() -> void:
	if not _dungeon.is_empty():
		return
	_dungeon = DungeonGen.generate(_rift_id, _biome_key)
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var ctx: Dictionary = gs.get_pending_rift()
		ctx["dungeon"] = _dungeon.duplicate(true)
		gs.set_pending_rift(ctx)


func _enter_dungeon_mode() -> void:
	_dungeon_w = int(_dungeon.get("width", 15))
	_dungeon_h = int(_dungeon.get("height", 11))
	grid_container.columns = _dungeon_w

	var pp: Dictionary = _dungeon.get("player_pos", {}) as Dictionary
	_player_x = int(pp.get("x", 1))
	_player_y = int(pp.get("y", _dungeon_h - 2))

	clear_btn.pressed.connect(_on_close_rift_core_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	if has_node("MainVBox/ActionsHBox/EndTurnButton"):
		$MainVBox/ActionsHBox/EndTurnButton.visible = false

	_setup_grid()
	_refresh_dungeon_ui()

	if is_instance_valid(_runner):
		_runner.start_run(_rift_id, 1.0, _biome_key)

	instructions_label.text = (
		"[center]Explore the rift dungeon. [color=#e57373]✕[/color] = encounter, "
		+ "[color=#ef5350]☠[/color] = boss, [color=#b39ddb]◆[/color] = core (after boss). WASD to move.[/center]"
	)
	log_label.text = "[i]%d rooms generated. Reach the boss chamber.[/i]" % int(_dungeon.get("room_count", 0))


func _setup_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	_grid_cells.clear()
	for y in range(_dungeon_h):
		for x in range(_dungeon_w):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(28, 26)
			cell.focus_mode = Control.FOCUS_NONE
			cell.pressed.connect(_on_cell_pressed.bind(x, y))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.08, 0.06, 0.1)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.25, 0.2, 0.35)
			cell.add_theme_stylebox_override("normal", style)
			grid_container.add_child(cell)
			_grid_cells.append(cell)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if get_tree().paused:
		return
	if _rift_cleared:
		return
	var dx: int = 0
	var dy: int = 0
	match event.keycode:
		KEY_UP, KEY_W:
			dy = -1
		KEY_DOWN, KEY_S:
			dy = 1
		KEY_LEFT, KEY_A:
			dx = -1
		KEY_RIGHT, KEY_D:
			dx = 1
		_:
			return
	_try_move_to(_player_x + dx, _player_y + dy)


func _on_cell_pressed(x: int, y: int) -> void:
	_try_move_to(x, y)


func _try_move_to(x: int, y: int) -> void:
	if _rift_cleared:
		return
	var dist: int = absi(x - _player_x) + absi(y - _player_y)
	if dist != 1 and not (x == _player_x and y == _player_y):
		return
	if not DungeonGen.is_walkable(_dungeon, x, y):
		return

	_player_x = x
	_player_y = y
	_save_player_pos()

	var cell: Dictionary = DungeonGen.tile_at(_dungeon, x, y)
	var tile_type: String = str(cell.get("type", ""))

	match tile_type:
		DungeonGen.TILE_ENCOUNTER:
			if not bool(cell.get("cleared", false)):
				_trigger_combat("encounter", "%d,%d" % [x, y])
				return
		DungeonGen.TILE_BOSS:
			if not bool(_dungeon.get("boss_defeated", false)):
				_trigger_combat("boss", "%d,%d" % [x, y])
				return
		DungeonGen.TILE_CORE:
			if bool(cell.get("locked", true)):
				log_label.text = "[i]Core locked — defeat the boss first.[/i]"
			_refresh_dungeon_ui()
			return

	_refresh_dungeon_ui()


func _trigger_combat(encounter_type: String, tile_key: String) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var char_data: Dictionary = gs.get_character_data()
	var encounter: Dictionary = EncounterBuilder.build_rift_room(
		char_data, _biome_key, _rift_id, _entry_q, _entry_r, encounter_type, tile_key,
		_entry_local_x, _entry_local_y
	)
	var ctx: Dictionary = gs.get_pending_rift()
	ctx["dungeon"] = _dungeon.duplicate(true)
	gs.set_pending_rift(ctx)
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_tactical_combat(encounter)


func _save_player_pos() -> void:
	_dungeon["player_pos"] = {"x": _player_x, "y": _player_y}
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		var ctx: Dictionary = gs.get_pending_rift()
		ctx["dungeon"] = _dungeon.duplicate(true)
		gs.set_pending_rift(ctx)


func _refresh_dungeon_ui() -> void:
	for i in range(_grid_cells.size()):
		var x: int = i % _dungeon_w
		var y: int = i / _dungeon_w
		var cell: Button = _grid_cells[i]
		var tile: Dictionary = DungeonGen.tile_at(_dungeon, x, y)
		var tile_type: String = str(tile.get("type", DungeonGen.TILE_WALL))
		var txt: String = ""
		var bg: Color = Color(0.06, 0.05, 0.08)

		match tile_type:
			DungeonGen.TILE_WALL:
				bg = Color(0.04, 0.03, 0.06)
			DungeonGen.TILE_FLOOR, DungeonGen.TILE_ENTRANCE:
				bg = Color(0.12, 0.1, 0.16)
			DungeonGen.TILE_ENCOUNTER:
				bg = Color(0.35, 0.12, 0.12) if not bool(tile.get("cleared", false)) else Color(0.12, 0.1, 0.16)
				if not bool(tile.get("cleared", false)):
					txt = "✕"
			DungeonGen.TILE_BOSS:
				if not bool(_dungeon.get("boss_defeated", false)):
					bg = Color(0.55, 0.1, 0.1)
					txt = "☠"
			DungeonGen.TILE_CORE:
				bg = Color(0.3, 0.18, 0.45)
				txt = "◇" if bool(tile.get("locked", true)) else "◆"

		if x == _player_x and y == _player_y:
			txt = "◎"
			bg = Color(0.18, 0.5, 0.32)

		cell.text = txt
		var style: StyleBoxFlat = cell.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.bg_color = bg
		cell.add_theme_stylebox_override("normal", style)

	var boss_down: bool = bool(_dungeon.get("boss_defeated", false))
	clear_btn.disabled = not boss_down or _player_at_core() == false
	status_label.text = (
		"[b]Rift:[/b] %s  [b]Biome:[/b] %s  [b]Pos:[/b] (%d,%d)  [b]Boss:[/b] %s  [b]Rooms:[/b] %d"
		% [_rift_id, _biome_key, _player_x, _player_y, "defeated" if boss_down else "active", int(_dungeon.get("room_count", 0))]
	)


func _player_at_core() -> bool:
	var core: Dictionary = _dungeon.get("core_pos", {}) as Dictionary
	return _player_x == int(core.get("x", -1)) and _player_y == int(core.get("y", -1))


func _on_close_rift_core_pressed() -> void:
	if _rift_cleared or not bool(_dungeon.get("boss_defeated", false)) or not _player_at_core():
		return
	if not is_instance_valid(_runner):
		return

	var loot: Array = _runner.get_random_loot(_biome_key, 4)
	_runner.clear_rift(loot)
	if _runner.has_method("close_rift"):
		_runner.close_rift(_rift_id)

	var mm: MissionManager = get_node_or_null("/root/MissionManager") as MissionManager
	if is_instance_valid(mm) and mm.has_method("report_rift_cleared"):
		mm.report_rift_cleared(_rift_id)

	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		gs.clear_pending_rift()

	_rift_cleared = true
	_dungeon["rift_cleared"] = true
	loot_panel.visible = true
	var loot_text := "[b]RIFT CLOSED — LOOT ACQUIRED:[/b]\n"
	for item in loot:
		loot_text += "• %s (%s)\n" % [item.get("name", "Item"), item.get("type", "?")]
	loot_label.text = loot_text
	back_btn.text = "⬅ Return to Overworld"
	instructions_label.text = "[center]Rift closed. Return to overworld.[/center]"


func _on_back_pressed() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		if not _rift_cleared:
			var ctx: Dictionary = gs.get_pending_rift()
			ctx["dungeon"] = _dungeon.duplicate(true)
			gs.set_pending_rift(ctx)
		else:
			gs.clear_pending_rift()
		gs.set_player_position(_entry_q, _entry_r)
		gs.set_local_position(_entry_local_x, _entry_local_y)
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		gm.go_to_hub(gs.get_character_data() if is_instance_valid(gs) else {})
	else:
		get_tree().change_scene_to_file("res://scenes/HubWorld.tscn")


func _toggle_pause_menu() -> void:
	if is_instance_valid(_pause_menu) and _pause_menu.visible:
		_pause_menu.close()
		return
	if not is_instance_valid(_pause_menu):
		var scene: PackedScene = load("res://scenes/ui/PauseMenu.tscn") as PackedScene
		if is_instance_valid(scene):
			_pause_menu = scene.instantiate() as PauseMenu
			add_child(_pause_menu)
	if is_instance_valid(_pause_menu):
		_pause_menu.open()