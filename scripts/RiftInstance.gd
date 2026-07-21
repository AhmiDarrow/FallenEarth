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
var _pause_menu: PauseMenu = null

@onready var rift_map_view: Node2D = $RiftMapView
@onready var status_label: RichTextLabel = $UI_Canvas/HeaderPanel/StatusLabel as RichTextLabel
@onready var instructions_label: RichTextLabel = $UI_Canvas/InstructionsLabel as RichTextLabel
@onready var log_label: RichTextLabel = $UI_Canvas/LogLabel as RichTextLabel
@onready var clear_btn: Button = $UI_Canvas/BottomPanel/ActionsHBox/ClearRiftButton as Button
@onready var back_btn: Button = $UI_Canvas/BottomPanel/ActionsHBox/BackButton as Button
@onready var loot_panel: Panel = $UI_Canvas/LootPanel as Panel
@onready var loot_label: RichTextLabel = $UI_Canvas/LootPanel/LootVBox/LootLabel as RichTextLabel
@onready var loot_close_btn: Button = $UI_Canvas/LootPanel/LootVBox/LootCloseBtn as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[RiftInstance] TileMap-based rift dungeon loading.")

	if has_node("/root/RiftRunner"):
		_runner = get_node("/root/RiftRunner")
	else:
		_runner = load("res://scripts/RiftRunner.gd").new()
		add_child(_runner)

	_load_rift_context()
	_ensure_dungeon()
	_enter_dungeon_mode()

	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play_track"):
		mm.call("play_track", "rift")
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa != null and aa.has_method("play_biome"):
		aa.call("play_biome", "rift", 0.8)


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
	var pp: Dictionary = _dungeon.get("player_pos", {}) as Dictionary
	_player_x = int(pp.get("x", 1))
	_player_y = int(pp.get("y", 1))

	if is_instance_valid(rift_map_view) and rift_map_view.has_method("configure"):
		rift_map_view.configure(_dungeon, _biome_key)
		rift_map_view.set_player_cell(Vector2i(_player_x, _player_y))
		rift_map_view.reveal_around_player(Vector2i(_player_x, _player_y))

	clear_btn.pressed.connect(_on_close_rift_core_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	loot_close_btn.pressed.connect(_on_loot_closed)

	if is_instance_valid(_runner):
		_runner.start_run(_rift_id, 1.0, _biome_key)

	var w: int = _dungeon.get("width", 31)
	var h: int = _dungeon.get("height", 23)
	instructions_label.text = (
		"[center]WASD to move • ⚔ encounter • ☠ boss • ◆ core[/center]"
	)
	log_label.text = "[i]Rift size: %d×%d. Reach the boss chamber.[/i]" % [w, h]
	status_label.text = "[b]Rift:[/b] %s  [b]Biome:[/b] %s" % [_rift_id, _biome_key]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
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


func _try_move_to(x: int, y: int) -> void:
	if _rift_cleared:
		return
	var dist: int = absi(x - _player_x) + absi(y - _player_y)
	if dist != 1:
		return
	if not DungeonGen.is_walkable(_dungeon, x, y):
		return

	_player_x = x
	_player_y = y
	_save_player_pos()

	if is_instance_valid(rift_map_view):
		rift_map_view.set_player_cell(Vector2i(_player_x, _player_y))
		rift_map_view.reveal_around_player(Vector2i(_player_x, _player_y))

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

	var boss_down: bool = bool(_dungeon.get("boss_defeated", false))
	_status_update(boss_down)


func _trigger_combat(encounter_type: String, tile_key: String) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var char_data: Dictionary = gs.get_character_data()
	var em: EquipmentManager = get_node_or_null("/root/EquipmentManager") as EquipmentManager
	var equip_stats: Dictionary = em.get_combat_stats("player") if is_instance_valid(em) else {}
	var encounter: Dictionary = EncounterBuilder.build_rift_room(
		char_data, _biome_key, _rift_id, _entry_q, _entry_r, encounter_type, tile_key,
		_entry_local_x, _entry_local_y, equip_stats
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


func _status_update(boss_down: bool) -> void:
	clear_btn.disabled = not boss_down or not _player_at_core()
	status_label.text = (
		"[b]Rift:[/b] %s  [b]Biome:[/b] %s  [b]Pos:[/b] (%d,%d)  [b]Boss:[/b] %s"
		% [_rift_id, _biome_key, _player_x, _player_y, "defeated" if boss_down else "active"]
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

	instructions_label.text = "[center]Rift closed. Loot acquired.[/center]"

	var loot_panel_label: RichTextLabel = loot_label
	var loot_text := "[b]LOOT ACQUIRED:[/b]\n"
	for item in loot:
		loot_text += "• %s (%s)\n" % [item.get("name", "Item"), item.get("type", "?")]
	loot_panel_label.text = loot_text
	loot_panel.visible = true


func _on_loot_closed() -> void:
	loot_panel.visible = false
	back_btn.text = "⬅ Return to Overworld"


func _on_back_pressed() -> void:
	var ns: Node = get_node_or_null("/root/NetworkSync")
	if ns != null and ns.has_method("sync_rift_exit"):
		var nm: Node = get_node_or_null("/root/NetworkManager")
		if nm != null and nm.has_method("is_server") and nm.is_server():
			ns.sync_rift_exit()

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
			var layer := CanvasLayer.new()
			layer.name = "PauseMenuLayer"
			layer.layer = 100
			add_child(layer)
			layer.add_child(_pause_menu)
	if is_instance_valid(_pause_menu):
		_pause_menu.open()
