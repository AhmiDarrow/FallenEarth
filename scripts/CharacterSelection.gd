## CharacterSelection — Race + Class selection UI with save/load integration
## Uses static nodes from CharacterSelection.tscn. Buttons are built at runtime.

class_name CharacterSelection extends Control


signal character_selected(race_key: String, class_key: String)
signal character_created_and_ready(race_key: String, class_key: String, origin: String, character_id: String)
signal selection_reset()

const RACE_DATA_PATH := "res://data/races.json"
const CLASS_DATA_PATH := "res://data/character_classes.json"


# -- state --
var _selected_race_key: String = ""
var _selected_class_key: String = ""
var available_races: Array[String] = []
var available_classes: Array[String] = []
var _race_info_cache: Dictionary = {}


func _ready() -> void:
	$MainVBox/BottomBar/ConfirmButton.pressed.connect(_on_confirm_pressed)
	$MainVBox/BottomBar/ResetButton.pressed.connect(reset_selection)
	character_created_and_ready.connect(_on_character_created_and_ready)
	
	# Connect name field to update summary
	var name_edit := $MainVBox/NameHBox/NameEdit as LineEdit
	if is_instance_valid(name_edit):
		name_edit.text_changed.connect(_on_name_changed)
	
	prefill_upworld_races()
	prefill_underworld_races()
	prefill_class_buttons()
	_update_selection_summary()


# ===================================================================
# Race Population
# ===================================================================

func get_origin_for_race(race_key: String, data: Dictionary = {}) -> String:
	if data.is_empty():
		data = _load_race_data()
	for category in ["upworld", "underworld"]:
		if category in data and race_key in data[category]:
			return category
	return "unknown"


func _load_race_data() -> Dictionary:
	var file := FileAccess.open(RACE_DATA_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		push_error("[CharacterSelection] Cannot load %s" % RACE_DATA_PATH)
		return {}
	
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_race_info_cache = parsed
	return _race_info_cache


func _create_race_button(race_key: String, info: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = ("%s" % race_key).capitalize()
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.size_flags_horizontal = 3
	btn.set_meta("race_key", race_key)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.25)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.4, 0.3, 0.6)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.25, 0.15, 0.35)
	btn.add_theme_stylebox_override("hover", hover_style)

	var desc: String = info.get("description", "A character.") as String
	var base: Dictionary = info.get("base_stats", {}) as Dictionary
	var stats_str = "STR:%d DEX:%d CON:%d INT:%d WIS:%d CHA:%d" % [
		base.get("str", 10), base.get("dex", 10), base.get("con", 10),
		base.get("int", 10), base.get("wis", 10), base.get("cha", 10)
	]
	btn.tooltip_text = "%s\nBase: %s" % [desc, stats_str]
	
	_apply_race_button_style(btn, race_key == _selected_race_key)
	
	btn.pressed.connect(_on_race_selected.bind(race_key))
	return btn

func _apply_race_button_style(btn: Button, is_selected: bool):
	if is_selected:
		btn.self_modulate = Color(1.0, 1.0, 0.6)
		var sel_style := StyleBoxFlat.new()
		sel_style.bg_color = Color(0.3, 0.25, 0.45)
		sel_style.border_width_bottom = 2
		sel_style.border_width_top = 2
		sel_style.border_width_left = 2
		sel_style.border_width_right = 2
		sel_style.border_color = Color(0.85, 0.75, 1.0)
		btn.add_theme_stylebox_override("normal", sel_style)
	else:
		btn.self_modulate = Color.WHITE
		# Re-apply base if needed (simple approach)
		var base_style := StyleBoxFlat.new()
		base_style.bg_color = Color(0.15, 0.1, 0.25)
		base_style.border_width_bottom = 1
		base_style.border_width_top = 1
		base_style.border_width_left = 1
		base_style.border_width_right = 1
		base_style.border_color = Color(0.4, 0.3, 0.6)
		btn.add_theme_stylebox_override("normal", base_style)

func prefill_upworld_races():
	var container := $MainVBox/RacesHBox/UpworldPanel/UpworldVBox/UpworldScroll/UpworldButtonList as VBoxContainer
	if not is_instance_valid(container):
		push_error("[CharacterSelection] UpworldButtonList not found in scene.")
		return
	
	for child in container.get_children():
		child.queue_free()
	
	available_races.clear()
	
	var data: Dictionary = _load_race_data()
	var upworld = data.get("upworld", {}) as Dictionary
	
	for race_key in upworld.keys():
		available_races.append(race_key)
		var info: Dictionary = upworld[race_key] as Dictionary
		var btn := _create_race_button(race_key, info)
		container.add_child(btn)
	
	container.queue_sort()
	print("[CharacterSelection] Populated Upworld races: %d" % upworld.size())

func prefill_underworld_races():
	var container := $MainVBox/RacesHBox/UnderworldPanel/UnderworldVBox/UnderworldScroll/UnderworldButtonList as VBoxContainer
	if not is_instance_valid(container):
		push_error("[CharacterSelection] UnderworldButtonList not found in scene.")
		return
	
	for child in container.get_children():
		child.queue_free()
	
	var data: Dictionary = _load_race_data()
	var underworld = data.get("underworld", {}) as Dictionary
	
	for race_key in underworld.keys():
		available_races.append(race_key)
		var info: Dictionary = underworld[race_key] as Dictionary
		var btn := _create_race_button(race_key, info)
		container.add_child(btn)
	
	container.queue_sort()
	print("[CharacterSelection] Populated Underworld races: %d" % underworld.size())


func _on_race_selected(race_key: String):
	_selected_race_key = race_key
	_update_all_race_buttons()
	_update_selection_summary()
	
	print("[CharacterSelection] Selected race: %s (origin=%s)" % [race_key, get_origin_for_race(race_key)])

func _update_all_race_buttons():
	# Update Upworld list
	var up_container := $MainVBox/RacesHBox/UpworldPanel/UpworldVBox/UpworldScroll/UpworldButtonList as VBoxContainer
	if is_instance_valid(up_container):
		for child in up_container.get_children():
			if child is Button and child.has_meta("race_key"):
				var key: String = child.get_meta("race_key")
				_apply_race_button_style(child, key == _selected_race_key)
	
	# Update Underworld list
	var under_container := $MainVBox/RacesHBox/UnderworldPanel/UnderworldVBox/UnderworldScroll/UnderworldButtonList as VBoxContainer
	if is_instance_valid(under_container):
		for child in under_container.get_children():
			if child is Button and child.has_meta("race_key"):
				var key: String = child.get_meta("race_key")
				_apply_race_button_style(child, key == _selected_race_key)


# ===================================================================
# Class Population
# ===================================================================

func _load_class_data() -> Array:
	var file := FileAccess.open(CLASS_DATA_PATH, FileAccess.READ)
	if not is_instance_valid(file):
		push_error("[CharacterSelection] Cannot load %s" % CLASS_DATA_PATH)
		return []
	
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	
	if parsed is Array:
		available_classes.clear()
		for entry: Variant in parsed:
			if entry is Dictionary and entry.has("name"):
				available_classes.append((entry as Dictionary)["name"])
		print("[CharacterSelection] Loaded %d classes from json." % available_classes.size())
		return parsed
	
	push_error("[CharacterSelection] Failed to parse classes.json")
	return []


func prefill_class_buttons(force_new: bool = true):
	if force_new == false and not available_classes.is_empty():
		return
	
	var scroll := $MainVBox/ClassPanel/ClassVBox/ClassScrollContainer/ClassButtonList as VBoxContainer
	if is_instance_valid(scroll):
		for child in scroll.get_children():
			child.queue_free()
	
	var data: Array = _load_class_data()
	if data.is_empty():
		return
	
	for entry: Variant in data:
		if entry is Dictionary and entry.has("name"):
			var key: String = (entry as Dictionary)["name"] as String
			
			var btn := Button.new()
			btn.text = ("%s" % key).capitalize()
			btn.custom_minimum_size = Vector2(0, 40)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.size_flags_horizontal = 3  # fill + expand
			btn.set_meta("class_key", key)

			# Give buttons a visible dark style so they show on dark background
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.1, 0.25)
			style.border_width_bottom = 1
			style.border_width_top = 1
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_color = Color(0.4, 0.3, 0.6)
			btn.add_theme_stylebox_override("normal", style)
			var hover_style := style.duplicate()
			hover_style.bg_color = Color(0.25, 0.15, 0.35)
			btn.add_theme_stylebox_override("hover", hover_style)

			btn.self_modulate = Color(1.0, 1.0, 0.6) if key == _selected_class_key else Color.WHITE
			var desc: String = entry.get("description", "") as String
			btn.tooltip_text = desc if desc != "" else ""
			
			var stat_desc: String = ""
			var mods: Dictionary = entry.get("stat_mods", {}) as Dictionary
			for k: String in mods:
				stat_desc += "%s%+d " % [k.to_upper(), mods[k]]
			if not stat_desc.is_empty():
				btn.tooltip_text += "\nMods: %s" % stat_desc
			var combat: Dictionary = entry.get("combat", {}) as Dictionary
			if not combat.is_empty():
				btn.tooltip_text += "\n[FFT] Role: %s | MP: %d | Range: %d" % [
					combat.get("role", "?"), combat.get("mp_max", 0), combat.get("weapon_range", 1),
				]
			var prog: Dictionary = entry.get("progression", {}) as Dictionary
			if not prog.is_empty():
				var max_lv: int = int(prog.get("max_level", 256))
				var ab_count: int = (combat.get("abilities", []) as Array).size()
				btn.tooltip_text += "\n[Progression] Lv.1–%d | %d abilities unlock over time" % [max_lv, ab_count]
			
			btn.pressed.connect(_on_class_selected.bind(key))
			scroll.add_child(btn)

	# Force layout update so the list is visible immediately
	scroll.queue_sort()
	if is_instance_valid(scroll.get_parent()):
		scroll.get_parent().queue_sort()
	
	print("[CharacterSelection] Built class panel with %d buttons." % available_classes.size())


func _on_class_selected(class_key: String):
	_selected_class_key = class_key
	
	var scroll := $MainVBox/ClassPanel/ClassVBox/ClassScrollContainer/ClassButtonList as VBoxContainer
	if is_instance_valid(scroll):
		for child in scroll.get_children():
			if child is Button and child.has_meta("class_key"):
				var key: String = child.get_meta("class_key")
				child.self_modulate = Color(1.0, 1.0, 0.6) if key == class_key else Color.WHITE
	
	_update_selection_summary()
	print("[CharacterSelection] Selected class: %s" % class_key)


func _update_selection_summary():
	var name_edit := $MainVBox/NameHBox/NameEdit as LineEdit
	var char_name := name_edit.text.strip_edges() if is_instance_valid(name_edit) else ""
	
	var summary := $MainVBox/SelectionSummary as RichTextLabel
	var confirm_btn := $MainVBox/BottomBar/ConfirmButton as Button
	
	var can_proceed := not _selected_race_key.is_empty() and not _selected_class_key.is_empty()
	
	if is_instance_valid(confirm_btn):
		confirm_btn.disabled = not can_proceed
	
	if not is_instance_valid(summary):
		return
	
	var parts := []
	if not char_name.is_empty():
		parts.append("[b]Name:[/b] %s" % char_name)
	else:
		parts.append("[i](name will default)[/i]")
	
	if not _selected_race_key.is_empty():
		var origin := get_origin_for_race(_selected_race_key)
		parts.append("[b]Race:[/b] %s (%s)" % [_selected_race_key.capitalize(), origin])
	else:
		parts.append("[i]No race selected[/i]")
	
	if not _selected_class_key.is_empty():
		parts.append("[b]Class:[/b] %s (starts Lv.1, max Lv.256)" % _selected_class_key)
	else:
		parts.append("[i]No class selected[/i]")
	
	if can_proceed:
		parts.append("[color=green][b]Ready to confirm![/b][/color]")
	
	summary.text = " | ".join(parts)


# ===================================================================
# Confirm / Reset
# ===================================================================

func _on_name_changed(_new_text: String):
	_update_selection_summary()

func _on_confirm_pressed():
	var name_edit := $MainVBox/NameHBox/NameEdit as LineEdit
	var char_name := name_edit.text.strip_edges() if is_instance_valid(name_edit) else ""
	
	if _selected_race_key.is_empty() or _selected_class_key.is_empty():
		push_warning("[CharacterSelection] Please select both a race and a class.")
		_update_selection_summary()
		return
	
	if char_name.is_empty():
		char_name = "Recruit"  # default name if not provided
	
	var success: bool = commit_character(char_name)
	if success:
		character_selected.emit(_selected_race_key, _selected_class_key)


func commit_character(char_name: String = "") -> bool:
	if _selected_race_key.is_empty() or _selected_class_key.is_empty():
		push_warning("[CharacterSelection] Cannot commit — missing race or class.")
		return false
	
	var origin: String = get_origin_for_race(_selected_race_key, _load_race_data())
	
	var gs: GameState = GameState
	if not is_instance_valid(gs):
		push_error("[CharacterSelection] GameState autoload not found.")
		return false
	
	var create_success: bool = gs.create_character(_selected_race_key, _selected_class_key, origin, char_name)
	if not create_success:
		push_error("[CharacterSelection] GameState.create_character failed for %s/%s." % [_selected_race_key, _selected_class_key])
		return false
	
	var char_data: Dictionary = gs.get_character_data()
	auto_save_character(char_data)
	
	print("[CharacterSelection] Character committed and auto-saved: '%s' race=%s class=%s origin=%s" % [
		char_data.get("name", ""), _selected_race_key, _selected_class_key, origin])
	
	character_created_and_ready.emit(_selected_race_key, _selected_class_key, origin, char_data.get("id", ""))
	return true


## ------------------------------------------------------------------
# Character creation completion handler
## ------------------------------------------------------------------

func _on_character_created_and_ready(race_key: String, class_key: String, origin: String, character_id: String) -> void:
	var gs: GameState = GameState
	var char_data: Dictionary = gs.get_character_data() if is_instance_valid(gs) else {}
	print("[CharacterSelection] Character ready '%s' (race=%s, class=%s, id=%s). Transitioning to HubWorld..." % [
		char_data.get("name", character_id), race_key, class_key, character_id])
	
	# Do this sync — scene is being destroyed next frame, don't defer.
	var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(gm):
		print("[CharacterSelection] Dispatching synchronous nav to go_to_hub...")
		gm.go_to_hub({
			"id": character_id,
			"name": char_data.get("name", ""),
			"race": race_key,
			"class": class_key,
			"origin": origin,
			"stats": char_data.get("stats", {})
		})
	else:
		push_error("[CharacterSelection] Cannot reach GameManager.")


func auto_save_character(char_data: Dictionary) -> bool:
	var sm: SaveManager = SaveManager
	if not is_instance_valid(sm):
		push_error("[CharacterSelection] Cannot auto-save — SaveManager autoload not found.")
		return false
	
	char_data["character_created_at"] = Time.get_unix_time_from_system() * 1000
	
	for i in range(9):
		if not sm.has_save_in_slot(i):
			char_data["saved_to_slot"] = i
			sm.save_to_game_file(char_data, i, "AutoSave")
			print("[CharacterSelection] Auto-saved to slot %d." % i)
			return true
	
	push_warning("[CharacterSelection] All 9 save slots are full.")
	return false


func reset_selection():
	_selected_race_key = ""
	_selected_class_key = ""
	
	var name_edit := $MainVBox/NameHBox/NameEdit as LineEdit
	if is_instance_valid(name_edit):
		name_edit.text = ""
	
	prefill_upworld_races()
	prefill_underworld_races()
	prefill_class_buttons()
	_update_selection_summary()
	print("[CharacterSelection] Selection reset — rebuilding UI.")
	selection_reset.emit()
