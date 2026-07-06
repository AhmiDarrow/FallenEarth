## TacticalCombat — FFT-style battle scene (v0.10.0 overhaul).
##
## v0.10.0: The grid is now a real BattleGridView (49 cells with terrain
## tiles + height marks), units are BattleUnit nodes (mob sprites +
## facing + HP/CT bars + anim tweens), and the background is a
## biome-themed BattleBackground with vignette + drifting motes.
## The HUD status label, turn order, action buttons, and result panel
## still live here (restyled in v0.10.0 Phase 3).
class_name TacticalCombat extends Control

const CombatMgr = preload("res://scripts/CombatManager.gd")
const EncounterBuilder = preload("res://scripts/CombatEncounterBuilder.gd")
const DungeonGen = preload("res://scripts/RiftDungeonGenerator.gd")
const ClassProg = preload("res://scripts/ClassProgression.gd")
const BattleGridViewScript = preload("res://scripts/combat/BattleGridView.gd")
const BattleBackgroundScript = preload("res://scripts/combat/BattleBackground.gd")
const TurnOrderBarScript = preload("res://scripts/combat/TurnOrderBar.gd")
const UnitInfoCardScript = preload("res://scripts/combat/UnitInfoCard.gd")
const SkillBarScript = preload("res://scripts/combat/SkillBar.gd")
const TurnOrderPanelScript = preload("res://scripts/combat/TurnOrderPanel.gd")
const BattleResultPanelScript = preload("res://scripts/combat/BattleResultPanel.gd")
const CombatFeedbackScript = preload("res://scripts/CombatFeedback.gd")
const TargetingReticleScript = preload("res://scripts/combat/TargetingReticle.gd")
const CombatPopupScript = preload("res://scripts/combat/CombatPopup.gd")
const TopPromptScript = preload("res://scripts/combat/TopPrompt.gd")

var _encounter: Dictionary = {}
var _combat: Node = null
var _grid_size: int = 7
var _reticle: Control = null
var _top_prompt: Control = null

@onready var status_label: RichTextLabel = $HUDLayer/MainVBox/StatusLabel as RichTextLabel
@onready var turn_order_label: RichTextLabel = $HUDLayer/MainVBox/TurnOrderLabel as RichTextLabel
@onready var instructions_label: RichTextLabel = $HUDLayer/MainVBox/InstructionsLabel as RichTextLabel
@onready var log_label: RichTextLabel = $HUDLayer/MainVBox/LogLabel as RichTextLabel
@onready var skill_btn: Button = $HUDLayer/MainVBox/ActionsHBox/SkillButton as Button
@onready var skill_menu: PopupMenu = $HUDLayer/MainVBox/ActionsHBox/SkillMenu as PopupMenu
@onready var attack_btn: Button = $HUDLayer/MainVBox/ActionsHBox/AttackButton as Button
@onready var wait_btn: Button = $HUDLayer/MainVBox/ActionsHBox/WaitButton as Button
@onready var finish_btn: Button = $HUDLayer/MainVBox/ActionsHBox/FinishButton as Button
@onready var retreat_btn: Button = $HUDLayer/MainVBox/ActionsHBox/RetreatButton as Button
@onready var result_panel: VBoxContainer = $HUDLayer/MainVBox/ResultPanel as VBoxContainer
@onready var result_label: RichTextLabel = $HUDLayer/MainVBox/ResultPanel/ResultLabel as RichTextLabel
@onready var continue_btn: Button = $HUDLayer/MainVBox/ResultPanel/ContinueButton as Button
@onready var _background = $BattleBackgroundLayer/BattleBackground
@onready var _grid = $BattleLayer/BattleGridView
@onready var _feedback: Node = $BattleLayer/CombatFeedback
var _turn_order_bar: Control = null
var _unit_info_card: Control = null
var _skill_bar: Control = null
var _end_turn_btn: Button = null
var _turn_order_panel: Control = null
var _result_panel: Control = null


func _ready() -> void:
	_load_encounter()
	_grid_size = int(_encounter.get("grid_size", 7))

	# v0.10.10: Hide the legacy status/log/instructions labels AND
	# the legacy right-side MainVBox container itself. The new
	# TopPrompt + TurnOrderBar + UnitInfoCard + SkillBar + bottom
	# action bar take their place. The MainVBox had a yellow-border
	# "Tactical Combat" header + status + turn order + log + action
	# buttons that all bled through into the middle of the screen
	# in the v0.10.5+ iso-diamond layout. We keep the @onready refs
	# (status_label, etc.) so other code paths that touch them
	# still resolve, but the whole MainVBox is invisible.
	status_label.visible = false
	turn_order_label.visible = false
	instructions_label.visible = false
	log_label.visible = false
	var legacy_main := get_node_or_null("HUDLayer/MainVBox")
	if legacy_main != null:
		legacy_main.visible = false
		# Drop the legacy actions hbox (the buttons are moved into
		# the new bottom action bar below).
		var legacy_actions := legacy_main.get_node_or_null("ActionsHBox")
		if legacy_actions != null:
			legacy_actions.visible = false

	# v0.10.4 polish: use the actual viewport size (not a hardcoded
	# 1280x720 assumption) to center the battle layers. The scene
	# file positions BattleBackground + BattleGridView at (640, 360)
	# which is only correct for a 1280x720 viewport. On wider
	# displays this left the grid off-center toward the right side
	# of the screen. Re-anchor to the actual viewport center now.
	var vp_size: Vector2 = get_viewport_rect().size
	var vp_center: Vector2 = vp_size * 0.5
	if _background != null:
		_background.position = vp_center
	if _grid != null:
		_grid.position = vp_center
	if _feedback != null:
		_feedback.position = vp_center

	# Configure background (uses viewport size for the layout).
	_background.configure(
		str(_encounter.get("biome_key", "Ash Wastes")),
		_grid_size,
		vp_size
	)

	# Build terrain from the same height_seed the engine uses, then
	# configure the grid with both terrain + units.
	var encounter_for_grid: Dictionary = (_encounter.duplicate(true) as Dictionary)
	encounter_for_grid["units"] = []
	encounter_for_grid = _grid.build_terrain_for_encounter(encounter_for_grid)
	_grid.configure(encounter_for_grid)

	# v0.10.10: CombatFeedback shares the grid_layer's offset so
	# HP bars align with the cell centers (square grid; the
	# grid_layer's position is the top-left of the centered grid).
	if _feedback != null and _grid._grid_layer != null:
		_feedback.position = vp_center + _grid._grid_layer.position

	_combat = CombatMgr.new()
	_combat.setup_from_encounter(_encounter)
	_combat.log_message.connect(_on_combat_log)
	_combat.battle_phase_changed.connect(_on_battle_phase_changed)
	_combat.active_unit_changed.connect(_on_active_unit_changed)
	_combat.subphase_changed.connect(_on_subphase_changed)
	_combat.unit_updated.connect(_on_unit_updated)
	# Spawn unit visuals now that the engine has set them up.
	_sync_grid_units()

	# Wire input
	_grid.cell_clicked.connect(_on_cell_clicked)
	skill_btn.pressed.connect(_on_skill_pressed)
	skill_menu.id_pressed.connect(_on_skill_selected)
	attack_btn.pressed.connect(_on_attack_pressed)
	wait_btn.pressed.connect(_on_wait_pressed)
	finish_btn.pressed.connect(_on_finish_pressed)
	retreat_btn.pressed.connect(_on_retreat_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)

	# Wire action icons onto the buttons (Phase 4 assets).
	_apply_button_icon(attack_btn, "res://assets/battle_ui/icon_attack.png")
	_apply_button_icon(skill_btn, "res://assets/battle_ui/icon_skill.png")
	_apply_button_icon(wait_btn, "res://assets/battle_ui/icon_wait.png")
	_apply_button_icon(finish_btn, "res://assets/battle_ui/end_turn_button.png")
	# v0.10.1 polish: restyle the action buttons with the new
	# FFT-style metal assets (red/blue/grey/gold) and chunky text.
	_style_action_button(attack_btn, "Attack", Color(0.95, 0.85, 0.55))
	_style_action_button(skill_btn, "Skill", Color(0.65, 0.85, 1.0))
	_style_action_button(wait_btn, "Wait", Color(0.85, 0.85, 0.95))
	_style_finish_button(finish_btn)
	# Hide the legacy skill popup (we use SkillBar at the bottom now).
	skill_btn.visible = false
	# Make End Turn button larger and prominent
	finish_btn.custom_minimum_size = Vector2(140, 56)
	finish_btn.add_theme_font_size_override("font_size", 16)

	# Feedback (HP bars + floating numbers)
	if _feedback != null and _feedback.has_method("setup"):
		_feedback.setup(_combat)
		_feedback.setup_hp_bars(_combat.get_units(), _grid_size, BattleGridViewScript.CELL_SIZE)

	# v0.10.0+: top-center turn order bar (replaces the right-side
	# TurnOrderPanel and the older center BattleHUD panel; it shows
	# the active unit's portrait + HP in its first slot, so we no
	# longer need a separate BattleHUD overlay).
	_turn_order_bar = TurnOrderBarScript.new()
	_turn_order_bar.name = "TurnOrderBar"
	$HUDLayer.add_child(_turn_order_bar)
	if _turn_order_bar.has_method("setup"):
		_turn_order_bar.setup(_combat)

	# v0.10.0+: bottom-left unit info card (portrait + stats)
	_unit_info_card = UnitInfoCardScript.new()
	_unit_info_card.name = "UnitInfoCard"
	$HUDLayer.add_child(_unit_info_card)
	if _unit_info_card.has_method("setup"):
		_unit_info_card.setup(_combat)

	# v0.10.0+: bottom-center skill bar (3 hotkeyed skills)
	_skill_bar = SkillBarScript.new()
	_skill_bar.name = "SkillBar"
	$HUDLayer.add_child(_skill_bar)
	if _skill_bar.has_method("setup"):
		_skill_bar.setup(_combat)

	# v0.10.1 polish: build a dedicated bottom-center action bar
	# (End Turn + Retreat) so the player has the most important
	# action always in view, regardless of the legacy right-side
	# MainVBox. The legacy actions in MainVBox stay wired but
	# become a fallback if the dedicated bar is somehow destroyed.
	_build_bottom_action_bar()

	# v0.10.1 polish: top-center prompt ("Select a white tile to move")
	_top_prompt = TopPromptScript.new()
	_top_prompt.name = "TopPrompt"
	$HUDLayer.add_child(_top_prompt)

	# Phase 3 polish: targeting reticle (follows cursor during targeting)
	_reticle = TargetingReticleScript.new()
	_reticle.name = "TargetingReticle"
	_reticle.visible = false
	$HUDLayer.add_child(_reticle)

	# Phase 3 polish: replace simple result panel with the styled one
	_result_panel = BattleResultPanelScript.new()
	_result_panel.name = "BattleResultPanel"
	$HUDLayer.add_child(_result_panel)
	if _result_panel.has_method("set_continue_handler"):
		_result_panel.set_continue_handler(_on_continue_pressed)

	result_panel.visible = false
	_refresh_ui()

	# Audio
	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play_track"):
		mm.call("play_track", "combat")
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa != null and aa.has_method("stop_all"):
		aa.call("stop_all", 0.4)


func _process(_delta: float) -> void:
	if _combat == null or _reticle == null:
		return
	var targeting: bool = _combat.turn_subphase in [
		CombatMgr.TurnSubphase.TARGET_ATTACK, CombatMgr.TurnSubphase.TARGET_SKILL,
	]
	if not targeting:
		_reticle.visible = false
		return
	# Set reticle color based on subphase.
	if _combat.turn_subphase == CombatMgr.TurnSubphase.TARGET_ATTACK:
		_reticle.set_kind("attack")
	else:
		_reticle.set_kind("skill")
	# Convert mouse position to grid-local coords and snap to the
	# nearest isometric cell center. The grid is centered at vp_center
	# and the cell centers are at (grid * iso transform).
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	var vp_center: Vector2 = get_viewport_rect().size * 0.5
	# Find the closest cell by iterating (7x7 is small enough for this).
	var best_dist: float = 1e9
	var snap: Vector2 = vp_center
	for x in range(_grid_size):
		for y in range(_grid_size):
			if _grid != null and _grid.has_method("cell_to_iso"):
				var iso: Vector2 = _grid.cell_to_iso(x, y)
				var world: Vector2 = vp_center + iso
				var dist: float = mouse_screen.distance_squared_to(world)
				if dist < best_dist:
					best_dist = dist
					snap = world
	_reticle.position = snap
	_reticle.visible = true


func _load_encounter() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		_encounter = gs.get_pending_combat()
	if _encounter.is_empty():
		_encounter = EncounterBuilder.build_rift_room(
			gs.get_character_data() if is_instance_valid(gs) else {},
			"Ash Wastes", "rift_fallback", 0, 0, "encounter", ""
		)


func _sync_grid_units() -> void:
	if _grid == null or _combat == null:
		return
	var units: Array = _combat.get_units()
	# The grid built itself without units. Push the units in now via
	# `update_unit` (which adds or updates the BattleUnit node).
	for u in units:
		_grid.update_unit(u)


func _on_cell_clicked(x: int, y: int) -> void:
	if _combat == null or _combat.battle_phase != CombatMgr.BattlePhase.ACTIVE:
		return
	if not _combat.is_player_active():
		return
	var pos: Vector2i = Vector2i(x, y)
	if _combat.turn_subphase == CombatMgr.TurnSubphase.TARGET_ATTACK:
		# Find the unit at this position and play a swing before resolving.
		var target: Dictionary = _combat.get_unit_at(pos)
		if not target.is_empty():
			_grid.play_unit_attack_swing("player")
			_grid.flash_unit(str(target.get("id", "")))
		var atk_result: Dictionary = _combat.try_attack_at(pos)
		# Spawn popup for back/side attacks based on facing.
		if not target.is_empty():
			var hit_type: String = _compute_hit_type_for_popup(target, pos)
			if not hit_type.is_empty():
				_spawn_combat_popup(hit_type, pos)
		_sync_grid_units()
	elif _combat.turn_subphase == CombatMgr.TurnSubphase.TARGET_SKILL:
		var target2: Dictionary = _combat.get_unit_at(pos)
		if not target2.is_empty():
			_grid.flash_unit(str(target2.get("id", "")))
		_combat.try_skill_at(pos)
		_sync_grid_units()
	elif _combat.turn_subphase == CombatMgr.TurnSubphase.MOVE:
		# Move the active unit with a tween.
		var active: Dictionary = _combat.get_active_unit()
		if not active.is_empty():
			_grid.move_unit_to(str(active.get("id", "")), x, y, true)
		_combat.try_move_active_unit_to(pos)
		_sync_grid_units()
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
	_sync_grid_units()
	_sync_player_health()
	_show_result_if_done()
	_refresh_ui()


func _on_active_unit_changed(_uid: String) -> void:
	if _grid != null:
		_grid.set_active_unit(_uid)
	_refresh_ui()


func _on_subphase_changed(_sub: int) -> void:
	_refresh_ui()


func _on_unit_updated(_uid: String) -> void:
	# Engine mutated a unit. Push the new state to the BattleUnit node.
	if _grid == null or _combat == null:
		return
	for u in _combat.get_units():
		if str(u.get("id", "")) == _uid:
			_grid.update_unit(u)
			if int(u.get("hp", 0)) > 0 and int(u.get("hp", 0)) < int(u.get("max_hp", u.get("hp", 0))):
				_grid.flash_unit(_uid)
			break


func _on_combat_log(_text: String) -> void:
	_refresh_log()


func _show_result_if_done() -> void:
	if _combat == null:
		return
	if _combat.battle_phase == CombatMgr.BattlePhase.ACTIVE:
		return
	# Build the BBCode body for the styled result panel.
	var body: String = ""
	if _combat.battle_phase == CombatMgr.BattlePhase.VICTORY:
		body = _build_victory_body()
		if _result_panel != null and _result_panel.has_method("set_outcome"):
			_result_panel.set_outcome("victory", "VICTORY", body)
		_grant_victory_loot()
		_grant_victory_xp()
	else:
		body = "[center]The wasteland claims another traveler.[/center]"
		if _result_panel != null and _result_panel.has_method("set_outcome"):
			_result_panel.set_outcome("defeat", "DEFEAT", body)
	# Hide the legacy result panel (we use the styled one now).
	result_panel.visible = false


func _build_victory_body() -> String:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if not is_instance_valid(gs):
		return "[center]Combat won.[/center]"
	var xp: int = ClassProg.combat_xp_reward(_encounter, true)
	var result: Dictionary = gs.grant_class_xp(xp)
	var lvl: int = int(result.get("level", 1))
	var gained: int = int(result.get("levels_gained", 0))
	var cm: ClassManager = get_node_or_null("/root/ClassManager") as ClassManager
	var next_xp: int = ClassProg.xp_required_for_next_level(lvl) if is_instance_valid(cm) else 0
	var lines: Array[String] = []
	if gained > 0:
		lines.append("[center][b][color=#fff59d]LEVEL UP ×%d![/color][/b] Now [b]Lv.%d[/b] / %d[/center]" % [gained, lvl, ClassProg.MAX_LEVEL])
	else:
		lines.append("[center]+%d Class XP  ([b]Lv.%d[/b] — %d/%d to next)[/center]" % [xp, lvl, int(result.get("xp", 0)), next_xp])
	if bool(_encounter.get("victory_loot", false)):
		var runner: Node = get_node_or_null("/root/RiftRunner")
		if is_instance_valid(runner):
			var biome: String = str(_encounter.get("biome_key", "Ash Wastes"))
			var count: int = int(_encounter.get("loot_count", 2))
			var loot: Array = runner.get_random_loot(biome, count)
			if not loot.is_empty():
				lines.append("\n[b]Loot:[/b]")
				for item in loot:
					lines.append("• %s" % item.get("name", "Item"))
	return "\n".join(lines)


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
	if _grid != null and _combat != null:
		_grid.refresh_ranges(
			_combat.get_reachable_move_tiles(),
			_combat.get_attackable_tiles(),
			_combat.get_skillable_tiles()
		)
	_update_status()
	_update_turn_order()
	_update_instructions()
	_refresh_log()
	_update_buttons()


func _update_status() -> void:
	if _combat == null:
		return
	var active: Dictionary = _combat.get_active_unit()
	var source: String = str(_encounter.get("source", "?"))
	var biome: String = str(_encounter.get("biome_key", "?"))
	var party_lv: int = int(_encounter.get("party_avg_level", 1))
	var mission_title: String = str(_encounter.get("mission_title", ""))
	var header: String = mission_title if not mission_title.is_empty() else source
	var txt: String = "[b]Tactical Combat[/b] — %s @ %s  [color=#90caf9](Party Lv.%d)[/color]\n" % [header, biome, party_lv]
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
		if _top_prompt != null:
			_top_prompt.hide_prompt()
		instructions_label.text = "[center]Battle ended.[/center]"
		return
	if not _combat.is_player_active():
		if _top_prompt != null:
			_top_prompt.show_prompt("Enemy acting…", "Wait for the next turn", 0.0)
		instructions_label.text = "[center][i]Enemy acting…[/i][/center]"
		return
	match _combat.turn_subphase:
		CombatMgr.TurnSubphase.MOVE:
			if _top_prompt != null:
				_top_prompt.show_prompt("Select a white tile to move", "Then choose an action", 0.0)
			instructions_label.text = "[center]Move (blue), then [b]Skill[/b] / [b]Attack[/b] / [b]Wait[/b] / [b]Finish[/b]. Flanking deals bonus damage.[/center]"
		CombatMgr.TurnSubphase.ACTION:
			if _top_prompt != null:
				_top_prompt.show_prompt("Choose an action", "Skill / Attack / Wait / Finish", 0.0)
			instructions_label.text = "[center]Choose [b]Skill[/b] (class ability), [b]Attack[/b], [b]Wait[/b], or [b]Finish Turn[/b].[/center]"
		CombatMgr.TurnSubphase.TARGET_ATTACK:
			if _top_prompt != null:
				_top_prompt.show_prompt("Select a target", "Red tiles = attack range", 0.0)
			instructions_label.text = "[center]Select enemy in [color=#c62828]red[/color] attack range.[/center]"
		CombatMgr.TurnSubphase.TARGET_SKILL:
			if _top_prompt != null:
				_top_prompt.show_prompt("Select a skill target", "Purple tiles = skill range", 0.0)
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


func _apply_button_icon(btn: Button, icon_path: String) -> void:
	if btn == null:
		return
	if not ResourceLoader.exists(icon_path):
		return
	var tex: Texture2D = load(icon_path) as Texture2D
	if tex != null:
		btn.icon = tex
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true


## Restyle a button as a chunky FFT-style action button.
## Wraps the label text in a ColorRect-tinted stylebox so the
## text reads cleanly on the metal button background. Uses the
## provided accent color for the label.
func _style_action_button(btn: Button, label_text: String, accent: Color) -> void:
	if btn == null:
		return
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.12, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.45, 0.55, 1.0)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.20, 0.18, 0.25, 0.92)
	sb_hover.border_color = Color(0.95, 0.80, 0.35, 1.0)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb.duplicate()
	sb_pressed.bg_color = Color(0.35, 0.25, 0.15, 0.95)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	var sb_disabled := sb.duplicate()
	sb_disabled.bg_color = Color(0.05, 0.05, 0.07, 0.5)
	sb_disabled.border_color = Color(0.20, 0.20, 0.25, 0.5)
	btn.add_theme_stylebox_override("disabled", sb_disabled)


## Special styling for the "End Turn" button — uses the gold button
## asset as a backdrop and a chunkier border.
func _style_finish_button(btn: Button) -> void:
	if btn == null:
		return
	btn.text = "End Turn"
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	btn.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.0, 0.95))
	btn.add_theme_constant_override("outline_size", 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.20, 0.05, 0.92)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.95, 0.80, 0.30, 1.0)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.45, 0.30, 0.10, 0.95)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb.duplicate()
	sb_pressed.bg_color = Color(0.55, 0.40, 0.15, 0.95)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	var sb_disabled := sb.duplicate()
	sb_disabled.bg_color = Color(0.20, 0.15, 0.05, 0.5)
	sb_disabled.border_color = Color(0.45, 0.40, 0.15, 0.5)
	btn.add_theme_stylebox_override("disabled", sb_disabled)


## Compute popup kind based on facing relation between attacker and target.
## Returns "" for front attacks (no popup needed).
func _compute_hit_type_for_popup(target: Dictionary, atk_pos: Vector2i) -> String:
	if _combat == null:
		return ""
	var attacker: Dictionary = _combat.get_active_unit()
	if attacker.is_empty():
		return ""
	var tgt_pos: Vector2i = target.get("pos", atk_pos)
	var facing_mult: float = _combat._facing_multiplier(
		int(target.get("facing", CombatMgr.Facing.SOUTH)), atk_pos, tgt_pos
	)
	if facing_mult >= CombatMgr.BACK_ATTACK_MULT - 0.01:
		return "back_attack"
	if facing_mult >= CombatMgr.SIDE_ATTACK_MULT - 0.01:
		return "side_attack"
	return ""


## Spawn a CombatPopup at the target grid cell in screen space.
func _spawn_combat_popup(kind: String, target_cell: Vector2i) -> void:
	if CombatPopupScript == null:
		return
	var popup: Control = CombatPopupScript.new()
	popup.name = "Popup_%s" % kind
	$HUDLayer.add_child(popup)
	# Convert grid cell to iso screen position (grid is centered at vp_center).
	var vp_center: Vector2 = get_viewport_rect().size * 0.5
	var iso: Vector2 = _grid.cell_to_iso(target_cell.x, target_cell.y)
	var world_pos: Vector2 = vp_center + iso + _grid._grid_layer.position
	popup.show_popup(kind, world_pos)


## Build a bottom-center action bar (End Turn + Retreat). The bar
## sits just above the SkillBar at the bottom-center of the screen.
## Larger buttons (48px tall) to be more clickable on a 1280x720
## viewport and read clearly even with the SkillBar below.
func _build_bottom_action_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "BottomActionBar"
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	# Sit just above the SkillBar (which is at -112..-16 from the
	# bottom). This places the action bar at -134..-100, leaving a
	# 12px gap above the SkillBar's top edge so they read as two
	# distinct rows.
	bar.offset_left = -180
	bar.offset_right = 180
	bar.offset_top = -160
	bar.offset_bottom = -124
	bar.add_theme_constant_override("separation", 16)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUDLayer.add_child(bar)
	# Re-style the existing End Turn / Retreat buttons and reparent
	# them into the new bar so the player can click them at the
	# bottom of the screen.
	if finish_btn != null:
		_style_finish_button(finish_btn)
		finish_btn.custom_minimum_size = Vector2(160, 36)
		finish_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_remove_parent(finish_btn)
		bar.add_child(finish_btn)
		# Re-wire: ensure pressed is still connected
		if not finish_btn.pressed.is_connected(_on_finish_pressed):
			finish_btn.pressed.connect(_on_finish_pressed)
	if retreat_btn != null:
		_style_action_button(retreat_btn, "Retreat", Color(0.95, 0.7, 0.55))
		retreat_btn.custom_minimum_size = Vector2(120, 36)
		retreat_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_remove_parent(retreat_btn)
		bar.add_child(retreat_btn)
		if not retreat_btn.pressed.is_connected(_on_retreat_pressed):
			retreat_btn.pressed.connect(_on_retreat_pressed)
	# Hide the legacy ActionsHBox since we've moved the buttons out.
	var legacy_hbox := get_node_or_null("HUDLayer/MainVBox/ActionsHBox")
	if legacy_hbox != null:
		legacy_hbox.visible = false


## Helper to remove a node from its current parent (so it can be
## reparented into a new container). Calls queue_free on the old
## parent if it was a transient container.
func _remove_parent(node: Node) -> void:
	if node == null or node.get_parent() == null:
		return
	var old_parent: Node = node.get_parent()
	old_parent.remove_child(node)
