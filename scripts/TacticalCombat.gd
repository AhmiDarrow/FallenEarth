## TacticalCombat — Unified FFT-style battle scene (overworld + rift).
class_name TacticalCombat extends Control

const CombatMgr = preload("res://scripts/CombatManager.gd")
const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const DungeonGen = preload("res://scripts/RiftDungeonGenerator.gd")
const ClassProg = preload("res://scripts/ClassProgression.gd")

var _encounter: Dictionary = {}
var _combat: Node = null
var _grid_size: int = 7
var _grid_cells: Array[Button] = []

@onready var status_label: RichTextLabel = $MainVBox/StatusLabel as RichTextLabel
@onready var grid_container: GridContainer = $MainVBox/GridPanel/GridContainer as GridContainer
@onready var turn_order_label: RichTextLabel = $MainVBox/TurnOrderLabel as RichTextLabel
@onready var instructions_label: RichTextLabel = $MainVBox/InstructionsLabel as RichTextLabel
@onready var log_label: RichTextLabel = $MainVBox/LogLabel as RichTextLabel
@onready var skill_btn: Button = $MainVBox/ActionsHBox/SkillButton as Button
@onready var skill_menu: PopupMenu = $MainVBox/ActionsHBox/SkillMenu as PopupMenu
@onready var attack_btn: Button = $MainVBox/ActionsHBox/AttackButton as Button
@onready var wait_btn: Button = $MainVBox/ActionsHBox/WaitButton as Button
@onready var finish_btn: Button = $MainVBox/ActionsHBox/FinishButton as Button
@onready var retreat_btn: Button = $MainVBox/ActionsHBox/RetreatButton as Button
@onready var result_panel: VBoxContainer = $MainVBox/ResultPanel as VBoxContainer
@onready var result_label: RichTextLabel = $MainVBox/ResultPanel/ResultLabel as RichTextLabel
@onready var continue_btn: Button = $MainVBox/ResultPanel/ContinueButton as Button


func _ready() -> void:
	_load_encounter()
	_grid_size = int(_encounter.get("grid_size", 7))
	grid_container.columns = _grid_size

	_combat = CombatMgr.new()
	_combat.setup_from_encounter(_encounter)
	_combat.log_message.connect(_on_combat_log)
	_combat.battle_phase_changed.connect(_on_battle_phase_changed)
	_combat.active_unit_changed.connect(_on_active_unit_changed)
	_combat.subphase_changed.connect(_on_subphase_changed)

	skill_btn.pressed.connect(_on_skill_pressed)
	skill_menu.id_pressed.connect(_on_skill_selected)
	attack_btn.pressed.connect(_on_attack_pressed)
	wait_btn.pressed.connect(_on_wait_pressed)
	finish_btn.pressed.connect(_on_finish_pressed)
	retreat_btn.pressed.connect(_on_retreat_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)

	_setup_grid()
	result_panel.visible = false
	_refresh_ui()


func _load_encounter() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		_encounter = gs.get_pending_combat()
	if _encounter.is_empty():
		_encounter = EncounterBuilder.build_rift_room(
			gs.get_character_data() if is_instance_valid(gs) else {},
			"Ash Wastes", "rift_fallback", 0, 0, "encounter", ""
		)


func _setup_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	_grid_cells.clear()
	for y in range(_grid_size):
		for x in range(_grid_size):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(44, 44)
			cell.focus_mode = Control.FOCUS_NONE
			cell.pressed.connect(_on_cell_pressed.bind(x, y))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.08, 0.12)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.3, 0.25, 0.4)
			cell.add_theme_stylebox_override("normal", style)
			grid_container.add_child(cell)
			_grid_cells.append(cell)


func _on_cell_pressed(x: int, y: int) -> void:
	if _combat == null or _combat.battle_phase != CombatMgr.BattlePhase.ACTIVE:
		return
	if not _combat.is_player_active():
		return

	var pos: Vector2i = Vector2i(x, y)
	if _combat.turn_subphase == CombatMgr.TurnSubphase.TARGET_ATTACK:
		_combat.try_attack_at(pos)
	elif _combat.turn_subphase == CombatMgr.TurnSubphase.TARGET_SKILL:
		_combat.try_skill_at(pos)
	elif _combat.turn_subphase == CombatMgr.TurnSubphase.MOVE:
		_combat.try_move_active_unit_to(pos)
	_refresh_ui()


func _on_skill_pressed() -> void:
	if _combat == null:
		return
	_populate_skill_menu()
	skill_menu.position = skill_btn.global_position + Vector2(0, skill_btn.size.y)
	skill_menu.popup()


func _populate_skill_menu() -> void:
	skill_menu.clear()
	var abilities: Array[Dictionary] = _combat.get_player_abilities()
	var mp: Dictionary = _combat.get_player_mp()
	for i in range(abilities.size()):
		var ab: Dictionary = abilities[i]
		var label: String = "%s (%d MP)" % [ab.get("name", "?"), ab.get("mp_cost", 0)]
		if int(mp.get("current", 0)) < int(ab.get("mp_cost", 99)):
			label += " [low MP]"
		skill_menu.add_item(label, i)
		skill_menu.set_item_metadata(i, str(ab.get("id", "")))


func _on_skill_selected(id: int) -> void:
	if _combat == null:
		return
	var skill_id: String = str(skill_menu.get_item_metadata(id))
	_combat.begin_skill_action(skill_id)
	_refresh_ui()


func _on_attack_pressed() -> void:
	if _combat == null:
		return
	_combat.begin_attack_action()
	_refresh_ui()


func _on_wait_pressed() -> void:
	if _combat == null:
		return
	_combat.wait_action()
	_sync_player_health()
	_refresh_ui()


func _on_finish_pressed() -> void:
	if _combat == null:
		return
	_combat.finish_turn()
	_sync_player_health()
	_refresh_ui()


func _on_retreat_pressed() -> void:
	_sync_player_health()
	_return_from_battle(false)


func _on_continue_pressed() -> void:
	_return_from_battle(_combat != null and _combat.battle_phase == CombatMgr.BattlePhase.VICTORY)


func _on_battle_phase_changed(_phase: int) -> void:
	_sync_player_health()
	_show_result_if_done()
	_refresh_ui()


func _on_active_unit_changed(_uid: String) -> void:
	_refresh_ui()


func _on_subphase_changed(_sub: int) -> void:
	_refresh_ui()


func _on_combat_log(_text: String) -> void:
	_refresh_log()


func _show_result_if_done() -> void:
	if _combat == null:
		return
	if _combat.battle_phase == CombatMgr.BattlePhase.ACTIVE:
		return
	result_panel.visible = true
	if _combat.battle_phase == CombatMgr.BattlePhase.VICTORY:
		result_label.text = "[b][color=#a5d6a7]VICTORY[/color][/b]"
		_grant_victory_loot()
		_grant_victory_xp()
	else:
		result_label.text = "[b][color=#ef9a9a]DEFEAT[/color][/b]"


func _grant_victory_xp() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return
	var xp: int = ClassProg.combat_xp_reward(_encounter, true)
	var result: Dictionary = gs.grant_class_xp(xp)
	var lvl: int = int(result.get("level", 1))
	var gained: int = int(result.get("levels_gained", 0))
	var cm: ClassManager = get_node_or_null("/root/ClassManager") as ClassManager
	var next_xp: int = ClassProg.xp_required_for_next_level(lvl) if is_instance_valid(cm) else 0
	if gained > 0:
		result_label.text += "\n\n[b][color=#fff59d]LEVEL UP ×%d![/color][/b] Now [b]Lv.%d[/b] / %d" % [
			gained, lvl, ClassProg.MAX_LEVEL,
		]
	else:
		result_label.text += "\n\n+%d Class XP  ([b]Lv.%d[/b] — %d/%d to next)" % [
			xp, lvl, int(result.get("xp", 0)), next_xp,
		]


func _grant_victory_loot() -> void:
	if not bool(_encounter.get("victory_loot", false)):
		return
	var runner: Node = get_node_or_null("/root/RiftRunner")
	if not is_instance_valid(runner):
		return
	var biome: String = str(_encounter.get("biome_key", "Ash Wastes"))
	var count: int = int(_encounter.get("loot_count", 2))
	var loot: Array = runner.get_random_loot(biome, count)
	if loot.is_empty():
		return
	result_label.text += "\n\n[b]Loot:[/b]"
	for item in loot:
		result_label.text += "\n• %s" % item.get("name", "Item")


func _sync_player_health() -> void:
	if _combat == null:
		return
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		gs.set_character_health(_combat.get_player_health_for_sync())


func _return_from_battle(victory: bool) -> void:
	_sync_player_health()
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		get_tree().change_scene_to_file("res://scenes/HubWorld.tscn")
		return

	var ctx: Dictionary = _encounter.get("return_context", {}) as Dictionary
	var source: String = str(_encounter.get("source", ""))

	if victory:
		var mm: MissionManager = get_node_or_null("/root/MissionManager") as MissionManager
		if is_instance_valid(mm) and mm.has_method("report_combat_victory"):
			mm.report_combat_victory(_encounter)

	if victory and bool(ctx.get("remove_mob_on_victory", false)):
		gs.remove_overworld_mob(str(ctx.get("tile_key", "")))

	gs.clear_pending_combat()

	var return_scene: String = str(_encounter.get("return_scene", "res://scenes/HubWorld.tscn"))
	var rift_ctx: Dictionary = {}
	if source == EncounterBuilder.SOURCE_RIFT:
		rift_ctx = gs.get_pending_rift()
		if rift_ctx.is_empty():
			rift_ctx = {
				"rift_id": ctx.get("rift_id", "rift_001"),
				"biome_key": ctx.get("biome_key", "Ash Wastes"),
				"entry_q": ctx.get("entry_q", 0),
				"entry_r": ctx.get("entry_r", 0),
				"entry_local_x": ctx.get("entry_local_x", 256),
				"entry_local_y": ctx.get("entry_local_y", 256),
			}
		if victory and bool(ctx.get("mark_dungeon_on_victory", false)):
			var dungeon: Dictionary = (rift_ctx.get("dungeon", {}) as Dictionary).duplicate(true)
			if not dungeon.is_empty():
				var enc_type: String = str(ctx.get("encounter_type", "encounter"))
				var tile_key: String = str(ctx.get("dungeon_tile_key", ""))
				if enc_type == "boss":
					dungeon = DungeonGen.mark_boss_defeated(dungeon)
				elif tile_key.contains(","):
					var parts: PackedStringArray = tile_key.split(",")
					if parts.size() >= 2:
						dungeon = DungeonGen.mark_encounter_cleared(dungeon, int(parts[0]), int(parts[1]))
				rift_ctx["dungeon"] = dungeon
		gs.set_pending_rift(rift_ctx)

	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		if return_scene.ends_with("HubWorld.tscn"):
			gm.go_to_hub(gs.get_character_data())
		elif return_scene.ends_with("RiftInstance.tscn"):
			gm.go_to_rift(
				str(rift_ctx.get("rift_id", ctx.get("rift_id", "rift_001"))),
				str(rift_ctx.get("biome_key", ctx.get("biome_key", "Ash Wastes"))),
				rift_ctx
			)
		else:
			get_tree().change_scene_to_file(return_scene)
	else:
		get_tree().change_scene_to_file(return_scene)


func _refresh_ui() -> void:
	_update_grid()
	_update_status()
	_update_turn_order()
	_update_instructions()
	_refresh_log()
	_update_buttons()


func _update_grid() -> void:
	if _combat == null:
		return
	var reachable: Array[Vector2i] = _combat.get_reachable_move_tiles()
	var attackable: Array[Vector2i] = _combat.get_attackable_tiles()
	var skillable: Array[Vector2i] = _combat.get_skillable_tiles()

	for i in range(_grid_cells.size()):
		var x: int = i % _grid_size
		var y: int = i / _grid_size
		var cell: Button = _grid_cells[i]
		var pos: Vector2i = Vector2i(x, y)
		var txt: String = ""
		var bg: Color = Color(0.1, 0.08, 0.12)
		var h: int = _combat.get_height_at(pos)
		if h > 0:
			bg = Color(0.12 + h * 0.04, 0.1, 0.14)

		for u in _combat.get_units():
			if u.get("pos", Vector2i(-1, -1)) != pos or int(u.get("hp", 0)) <= 0:
				continue
			if u.get("team") == CombatMgr.TEAM_PLAYER:
				txt = "◎"
				bg = Color(0.2, 0.55, 0.35)
			elif u.get("is_boss", false):
				txt = "☠"
				bg = Color(0.65, 0.15, 0.15)
			else:
				txt = "✕"
				bg = Color(0.45, 0.18, 0.18)

		if reachable.has(pos):
			bg = bg.lerp(Color(0.25, 0.45, 0.7), 0.45)
		if attackable.has(pos):
			bg = bg.lerp(Color(0.75, 0.25, 0.2), 0.5)
		if skillable.has(pos):
			bg = bg.lerp(Color(0.55, 0.25, 0.75), 0.5)

		var active: Dictionary = _combat.get_active_unit()
		if not active.is_empty() and active.get("pos", Vector2i.ZERO) == pos:
			cell.modulate = Color(1.25, 1.2, 0.9)
		else:
			cell.modulate = Color.WHITE

		if h > 0 and txt.is_empty():
			txt = str(h)
		cell.text = txt
		var style: StyleBoxFlat = cell.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.bg_color = bg
		cell.add_theme_stylebox_override("normal", style)


func _update_status() -> void:
	if _combat == null:
		return
	var active: Dictionary = _combat.get_active_unit()
	var source: String = str(_encounter.get("source", "?"))
	var biome: String = str(_encounter.get("biome_key", "?"))
	var party_lv: int = int(_encounter.get("party_avg_level", 1))
	var mission_title: String = str(_encounter.get("mission_title", ""))
	var header: String = mission_title if not mission_title.is_empty() else source
	var txt: String = "[b]FFT Combat[/b] — %s @ %s  [color=#90caf9](Party Lv.%d)[/color]\n" % [header, biome, party_lv]
	if not active.is_empty():
		txt += "[b]Active:[/b] %s  [b]CT:[/b] %d  [b]Spd:[/b] %d  [b]Move:[/b] %d  [b]Jump:[/b] %d\n" % [
			active.get("name", "?"),
			active.get("ct", 0),
			active.get("speed", 0),
			active.get("move", 0),
			active.get("jump", 0),
		]
		txt += "[b]Lv.[/b]%d  [b]HP:[/b] %d/%d  [b]MP:[/b] %d/%d  [b]Class:[/b] %s  [b]Facing:[/b] %s" % [
			active.get("level", 1),
			active.get("hp", 0), active.get("max_hp", 0),
			active.get("mp", 0), active.get("mp_max", 0),
			active.get("class", "?"),
			_facing_name(int(active.get("facing", 0))),
		]
	status_label.text = txt


func _update_turn_order() -> void:
	if _combat == null:
		return
	var order: Array[String] = _combat.get_turn_order_preview(6)
	turn_order_label.text = "[b]Turn order:[/b] " + " → ".join(order)


func _update_instructions() -> void:
	if _combat == null:
		return
	if _combat.battle_phase != CombatMgr.BattlePhase.ACTIVE:
		instructions_label.text = "[center]Battle ended.[/center]"
		return
	if not _combat.is_player_active():
		instructions_label.text = "[center][i]Enemy acting…[/i][/center]"
		return
	match _combat.turn_subphase:
		CombatMgr.TurnSubphase.MOVE:
			instructions_label.text = "[center]FFT: Move (blue), then [b]Skill[/b] / [b]Attack[/b] / [b]Wait[/b] / [b]Finish[/b]. Flanking deals bonus damage.[/center]"
		CombatMgr.TurnSubphase.ACTION:
			instructions_label.text = "[center]Choose [b]Skill[/b] (class ability), [b]Attack[/b], [b]Wait[/b], or [b]Finish Turn[/b].[/center]"
		CombatMgr.TurnSubphase.TARGET_ATTACK:
			instructions_label.text = "[center]Select enemy in [color=#c62828]red[/color] attack range.[/center]"
		CombatMgr.TurnSubphase.TARGET_SKILL:
			instructions_label.text = "[center]Select target in [color=#7b1fa2]purple[/color] skill range.[/center]"


func _refresh_log() -> void:
	if _combat == null:
		return
	var lines: Array[String] = _combat.get_log_lines()
	var tail: PackedStringArray = []
	var start: int = maxi(0, lines.size() - 7)
	for i in range(start, lines.size()):
		tail.append(lines[i])
	log_label.text = "[i]%s[/i]" % "\n".join(tail)


func _update_buttons() -> void:
	if _combat == null:
		return
	var player_turn: bool = _combat.is_player_active() and _combat.battle_phase == CombatMgr.BattlePhase.ACTIVE
	var targeting: bool = _combat.turn_subphase in [
		CombatMgr.TurnSubphase.TARGET_ATTACK, CombatMgr.TurnSubphase.TARGET_SKILL,
	]
	skill_btn.disabled = not player_turn or targeting
	attack_btn.disabled = not player_turn or targeting
	wait_btn.disabled = not player_turn
	finish_btn.disabled = not player_turn
	retreat_btn.disabled = _combat.battle_phase != CombatMgr.BattlePhase.ACTIVE


func _facing_name(facing: int) -> String:
	match facing:
		CombatMgr.Facing.NORTH:
			return "N"
		CombatMgr.Facing.EAST:
			return "E"
		CombatMgr.Facing.SOUTH:
			return "S"
		CombatMgr.Facing.WEST:
			return "W"
		_:
			return "?"