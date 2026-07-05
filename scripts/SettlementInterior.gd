## SettlementInterior — Spatial settlement interior controller.
##
## Loaded by SettlementManager when the player enters a settlement.
## Displays a grid-based room system with WASD movement, NPC visuals,
## and E-key interactions (talk to NPCs, use exits, leave settlement).
class_name SettlementInterior
extends Control

const ROOMS_PATH := "res://data/settlement_rooms.json"
const SETTLEMENT_PATH := "/root/SettlementManager"
const CELL_SIZE := 24

const MOVE_COOLDOWN := 0.12

var _town_data: Dictionary = {}
var _hub: Node = null
var _rooms: Dictionary = {}
var _current_room_id: String = "town_square"
var _room_view: Node2D = null
var _player_x: int = 5
var _player_y: int = 1
var _move_cooldown: float = 0.0
var _focus_building: String = ""
var _camera: Camera2D = null
var _player_visual: Node2D = null
var _biome: String = ""
var _faction: String = ""
var _wanderers: Array = []
var _max_wanderers: int = 5


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_frame()
	_load_rooms()


func setup(town: Dictionary, hub: Node, focus_building: String = "") -> void:
	_town_data = town
	_hub = hub
	_focus_building = focus_building
	_biome = str(town.get("biome", ""))
	_faction = str(town.get("faction", ""))
	# Determine starting room
	if not _focus_building.is_empty() and _rooms.has(_focus_building):
		_current_room_id = _focus_building
		_player_x = 5
		_player_y = 1
	else:
		_current_room_id = "town_square"
		_player_x = 5
		_player_y = 3
	_enter_room(_current_room_id, _player_x, _player_y)


func _build_frame() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.03, 0.02, 0.04, 0.98)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Room container (centered in the screen)
	var container := Node2D.new()
	container.name = "RoomContainer"
	# Center the room in the screen (we'll adjust via _center_container in _process)
	add_child(container)

	# Camera
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position_smoothing_enabled = false
	container.add_child(_camera)

	# Info bar
	var info := HBoxContainer.new()
	info.name = "InfoBar"
	info.anchors_preset = Control.PRESET_TOP_WIDE
	info.offset_bottom = 28
	info.offset_left = 10
	info.offset_right = -10
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)

	var room_label := Label.new()
	room_label.name = "RoomLabel"
	room_label.text = "Town Square"
	room_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	room_label.add_theme_font_size_override("font_size", 14)
	room_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	room_label.add_theme_constant_override("outline_size", 2)
	room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(room_label)

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "WASD=move  E=interact  ESC=leave"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 1)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(hint)


func _load_rooms() -> void:
	var file: FileAccess = FileAccess.open(ROOMS_PATH, FileAccess.READ)
	if file == null:
		push_error("[SettlementInterior] Could not open %s" % ROOMS_PATH)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[SettlementInterior] rooms JSON root is not Dictionary")
		return
	var raw_rooms: Dictionary = parsed.get("rooms", {})
	for rid in raw_rooms:
		var rd: Dictionary = raw_rooms[rid] as Dictionary
		rd["id"] = str(rid)
		_rooms[str(rid)] = rd


func _enter_room(room_id: String, entry_x: int, entry_y: int) -> void:
	if not _rooms.has(room_id):
		push_error("[SettlementInterior] Unknown room: %s" % room_id)
		return

	# Tear down old room view
	if _room_view != null and is_instance_valid(_room_view):
		_room_view.queue_free()

	_current_room_id = room_id
	_player_x = entry_x
	_player_y = entry_y

	# Build new room view inside the container
	var container: Node2D = get_node_or_null("RoomContainer")
	if container == null or not is_instance_valid(container):
		return

	var room_data: Dictionary = _rooms[room_id]
	_room_view = Node2D.new()
	_room_view.name = "Room_%s" % room_id
	_room_view.set_script(load("res://scripts/RoomView.gd"))
	container.add_child(_room_view)
	_room_view.setup(room_data, entry_x, entry_y, _biome, _faction)

	# Create player visual
	_setup_player_visual()

	# Update info bar
	_update_info()

	# Position camera
	_update_camera()

	# Initialize wanderers on first room entry
	if _wanderers.is_empty():
		_init_wanderers()


func _setup_player_visual() -> void:
	# Remove old player visual
	if _player_visual != null and is_instance_valid(_player_visual):
		_player_visual.queue_free()

	_player_visual = Node2D.new()
	_player_visual.name = "PlayerVisual"
	_player_visual.z_index = 10

	# Player body (colored rect)
	var body := ColorRect.new()
	body.name = "Body"
	body.color = Color(0.3, 0.8, 0.5)
	body.size = Vector2(14, 14)
	body.position = Vector2(-7, -7)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_visual.add_child(body)

	# Player label
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = "@"
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-6, -8)
	lbl.size = Vector2(12, 16)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_visual.add_child(lbl)

	# Position at cell
	_player_visual.position = Vector2(
		_player_x * CELL_SIZE + CELL_SIZE * 0.5,
		_player_y * CELL_SIZE + CELL_SIZE * 0.5
	)

	var container: Node2D = get_node_or_null("RoomContainer")
	if container != null and is_instance_valid(container):
		container.add_child(_player_visual)


func _update_info() -> void:
	var room_label: Label = get_node_or_null("InfoBar/RoomLabel") as Label
	if room_label != null and is_instance_valid(room_label):
		var room_data: Dictionary = _rooms.get(_current_room_id, {})
		room_label.text = str(room_data.get("name", _current_room_id))


func _update_camera() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	if _room_view == null or not is_instance_valid(_room_view):
		return
	var room_size: Vector2 = _room_view.get_pixel_size()
	# Center camera on the room
	_camera.position = room_size * 0.5


func _process(delta: float) -> void:
	_move_cooldown = maxf(_move_cooldown - delta, 0.0)
	_tick_wanderers(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if get_tree().paused:
		return

	match event.keycode:
		KEY_ESCAPE:
			_leave_settlement()
			get_viewport().set_input_as_handled()
			return
		KEY_E:
			_try_interact()
			get_viewport().set_input_as_handled()
			return

	if _move_cooldown > 0.0:
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

	_try_move(dx, dy)
	get_viewport().set_input_as_handled()


func _try_move(dx: int, dy: int) -> void:
	var nx: int = _player_x + dx
	var ny: int = _player_y + dy
	if _room_view == null or not is_instance_valid(_room_view):
		return
	if _room_view.is_wall(nx, ny):
		return
	_player_x = nx
	_player_y = ny
	_move_cooldown = MOVE_COOLDOWN
	_update_player_position()


func _update_player_position() -> void:
	if _player_visual != null and is_instance_valid(_player_visual):
		_player_visual.position = Vector2(
			_player_x * CELL_SIZE + CELL_SIZE * 0.5,
			_player_y * CELL_SIZE + CELL_SIZE * 0.5
		)
	if _room_view != null and is_instance_valid(_room_view):
		_room_view.set_player_cell(_player_x, _player_y)


func _try_interact() -> void:
	if _room_view == null or not is_instance_valid(_room_view):
		return

	# 1. Check for room exit (on current cell or adjacent)
	var exit: Dictionary = _room_view.get_exit_at(_player_x, _player_y)
	if exit.is_empty():
		exit = _room_view.get_exit_near(_player_x, _player_y)
	if not exit.is_empty():
		var target_room: String = str(exit.get("target_room", ""))
		var target_x: int = int(exit.get("target_x", 5))
		var target_y: int = int(exit.get("target_y", 1))
		if not target_room.is_empty():
			_enter_room(target_room, target_x, target_y)
			return

	# 2. Check for settlement exit
	if _room_view.is_settlement_exit(_player_x, _player_y) or _room_view.is_settlement_exit_near(_player_x, _player_y):
		_leave_settlement()
		return

	# 3. Check for NPC (on current cell or adjacent)
	var npc: Dictionary = _room_view.get_npc_at(_player_x, _player_y)
	if npc.is_empty():
		npc = _room_view.get_npc_near(_player_x, _player_y)
	if not npc.is_empty():
		_interact_npc(npc)
		return


func _interact_npc(npc: Dictionary) -> void:
	var role: String = str(npc.get("role", ""))
	var npc_name: String = str(npc.get("name", "?"))
	var race: String = str(npc.get("race", ""))
	var gender: String = str(npc.get("gender", "male"))

	# Check if DialogueManager has dialogue for this role
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm != null and dm.call("has_role_dialogue", role):
		_open_dialogue_ui(role, npc_name, race, gender)
		return

	# Fallback for roles without dialogue trees
	match role:
		"riftspire_portal":
			_travel_to_riftspire()
		_:
			_show_greeting(npc_name, role, "Nice to meet you.")


func _open_shop() -> void:
	if has_node("Shop"):
		return
	var ShopScript: GDScript = load("res://scripts/ui/ShopInterface.gd")
	if ShopScript == null:
		return
	var shop: Control = ShopScript.new()
	shop.name = "Shop"
	add_child(shop)


func _open_mission_board() -> void:
	if has_node("MissionBoard"):
		return
	var MBScript: GDScript = load("res://scripts/ui/MissionBoardInterface.gd")
	if MBScript == null:
		return
	var board: Control = MBScript.new()
	board.name = "MissionBoard"
	add_child(board)


func _open_dialogue_ui(role: String, npc_name: String, race: String, gender: String) -> void:
	if has_node("DialogueUI"):
		return
	var DialogueUIScript: GDScript = load("res://scripts/DialogueUI.gd")
	if DialogueUIScript == null:
		return
	var dialogue_ui: Control = DialogueUIScript.new()
	dialogue_ui.name = "DialogueUI"
	add_child(dialogue_ui)
	dialogue_ui.action_triggered.connect(_on_dialogue_action)
	dialogue_ui.dialogue_finished.connect(func(): dialogue_ui.queue_free())
	dialogue_ui.call("start_dialogue", role, npc_name, race, gender)


func _on_dialogue_action(action: String) -> void:
	match action:
		"open_shop":
			_open_shop()
		"open_mission_board":
			_open_mission_board()
		"travel_to_riftspire":
			_travel_to_riftspire()


func _show_greeting(npc_name: String, role: String, msg: String) -> void:
	# Show a floating dialog label
	if has_node("Dialog"):
		get_node("Dialog").queue_free()
	var panel := PanelContainer.new()
	panel.name = "Dialog"
	panel.offset_left = 60
	panel.offset_right = 500
	panel.offset_top = size.y - 120
	panel.offset_bottom = size.y - 40
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = "[color=#ffe082][b]%s[/b][/color] (%s)\n[i]%s[/i]" % [npc_name, role, msg]
	panel.add_child(lbl)

	# Auto-remove after 3 seconds
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(panel):
			panel.queue_free()
	)


func _travel_to_riftspire() -> void:
	var tm: Node = get_node_or_null("/root/TownManager")
	if tm == null:
		_show_greeting("Riftspire Portal", "riftspire_portal", "The portal hums quietly.")
		return

	# Check level gate
	var prog: Node = get_node_or_null("/root/ProgressionManager")
	var level: int = int(prog.level) if prog != null else 1
	if not tm.can_enter_riftspire(level):
		var reason: String = tm.riftspire_block_reason(level)
		_show_greeting("Riftspire Portal", "riftspire_portal", reason)
		return

	# Parse riftspire hex key
	var rift_hex: String = tm.get_riftspire_hex()
	if rift_hex.is_empty():
		_show_greeting("Riftspire Portal", "riftspire_portal", "The portal flickers... destination unknown.")
		return
	var parts: PackedStringArray = rift_hex.split(",")
	if parts.size() != 2:
		_show_greeting("Riftspire Portal", "riftspire_portal", "The portal malfunctions.")
		return
	var rq: int = int(parts[0])
	var rr: int = int(parts[1])

	# Leave settlement first
	_leave_settlement()

	# Travel to riftspire hex
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("travel_to_hex"):
		gs.travel_to_hex(rq, rr)
		print("[SettlementInterior] Traveled to Riftspire hex %s" % rift_hex)
	else:
		_show_greeting("Riftspire Portal", "riftspire_portal", "The portal fizzles... travel failed.")


func _leave_settlement() -> void:
	var sm: Node = get_node_or_null(SETTLEMENT_PATH)
	if sm != null and sm.has_method("leave_settlement"):
		sm.leave_settlement()
	else:
		queue_free()


# ---------------------------------------------------------------------------
# Ambient behavior
# ---------------------------------------------------------------------------

func _init_wanderers() -> void:
	_wanderers.clear()
	var wanderer_script: GDScript = load("res://scripts/NPCWanderer.gd") as GDScript
	if wanderer_script == null:
		return
	var count: int = 0
	for room_id in _rooms:
		var room: Dictionary = _rooms[room_id]
		var npcs: Array = room.get("npcs", [])
		for npc in npcs:
			if count >= _max_wanderers:
				return
			var wanderer = wanderer_script.new(npc, room_id)
			_wanderers.append(wanderer)
			count += 1


func _tick_wanderers(delta: float) -> void:
	if _wanderers.is_empty():
		return
	if _room_view == null or not is_instance_valid(_room_view):
		return
	var player_cell := Vector2i(_player_x, _player_y)
	for wanderer in _wanderers:
		var result: Dictionary = wanderer.tick(delta, player_cell, _rooms)
		if result.is_empty():
			continue
		var action: String = str(result.get("action", ""))
		if action == "move_to_room":
			var target_room: String = str(result.get("room", ""))
			if target_room != _current_room_id:
				# Move to another room
				_enter_room(target_room, 5, 5)
				wanderer.current_room = target_room
				wanderer.current_x = 5
				wanderer.current_y = 5
				return  # Only one wanderer moves at a time
		elif action == "arrived":
			# NPC arrived at target room — update position
			if _room_view != null and is_instance_valid(_room_view):
				_room_view.update_npc_position(wanderer.npc_id, wanderer.current_x, wanderer.current_y)
		# Show mood emoji if player is nearby
		if _room_view != null and is_instance_valid(_room_view):
			var is_near: bool = _room_view.is_player_nearby(wanderer.current_x, wanderer.current_y, 3)
			var dm: Node = get_node_or_null("/root/DialogueManager")
			var rep: int = 0
			if dm != null:
				rep = dm.call("get_faction_rep", _faction) if _faction != "" else 0
			var mood: String = wanderer.get_display_mood(is_near, rep)
			var emoji: String = wanderer.get_mood_emoji(mood)
			_room_view.show_mood_emoji(wanderer.npc_id, emoji)
