## CharacterSelection — Race + Class selection UI with save/load integration
## Uses static nodes from CharacterSelection.tscn. Buttons are built at runtime.

class_name CharacterSelection extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")

signal character_selected(race_key: String, class_key: String)
signal character_created_and_ready(race_key: String, class_key: String, origin: String, character_id: String)
signal selection_reset()

const RACE_DATA_PATH := "res://data/races.json"
const CLASS_DATA_PATH := "res://data/character_classes.json"


# -- state --
const PORTRAIT_RACE_MAP := {
	"ai": "sentientai",
}

var _selected_race_key: String = ""
var _selected_class_key: String = ""
var _selected_gender: String = "male"
var _selected_portrait: int = 1
var available_races: Array[String] = []
var available_classes: Array[String] = []
var _race_info_cache: Dictionary = {}
var _portrait_preview: TextureRect = null
var _portrait_index_label: Label = null
var _info_popup: Window = null


func _ready() -> void:
	var bg := $BackgroundColor as ColorRect
	if bg != null:
		bg.color = MT.BG_DEEP
	# Style buttons
	ButtonStyleHelper.apply_secondary($MainScroll/MainVBox/BackRow/BackButton)
	ButtonStyleHelper.apply_primary($MainScroll/MainVBox/BottomBar/ConfirmButton)
	ButtonStyleHelper.apply_ghost($MainScroll/MainVBox/BottomBar/ResetButton)
	# Wire signals
	$MainScroll/MainVBox/BackRow/BackButton.pressed.connect(_on_back_pressed)
	$MainScroll/MainVBox/BottomBar/ConfirmButton.pressed.connect(_on_confirm_pressed)
	$MainScroll/MainVBox/BottomBar/ResetButton.pressed.connect(reset_selection)
	character_created_and_ready.connect(_on_character_created_and_ready)
	
	# Apply MT theme to static scene labels
	$MainScroll/MainVBox/RaceHeader.add_theme_color_override("font_color", MT.TEXT_ACCENT)
	$MainScroll/MainVBox/ClassHeader.add_theme_color_override("font_color", MT.TEXT_ACCENT)
	$MainScroll/MainVBox/SelectionSummary.add_theme_color_override("font_color", MT.TEXT_SECONDARY)
	$MainScroll/MainVBox/RacesHBox/UpworldPanel/UpworldVBox/UpworldLabel.add_theme_color_override("font_color", MT.TEXT_ACCENT)
	$MainScroll/MainVBox/RacesHBox/UnderworldPanel/UnderworldVBox/UnderworldLabel.add_theme_color_override("font_color", MT.TEXT_ACCENT)
	$MainScroll/MainVBox/ClassPanel/ClassVBox/ClassLabel.add_theme_color_override("font_color", MT.TEXT_ACCENT)
	$MainScroll/MainVBox/NameHBox/NameLabel.add_theme_color_override("font_color", MT.TEXT_PRIMARY)
	$MainScroll/MainVBox/GenderHBox/GenderLabel.add_theme_color_override("font_color", MT.TEXT_PRIMARY)

	# Connect name field to update summary
	var name_edit := $MainScroll/MainVBox/NameHBox/NameEdit as LineEdit
	if is_instance_valid(name_edit):
		name_edit.text_changed.connect(_on_name_changed)
	
	_build_gender_buttons()
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


func _create_race_button(race_key: String, info: Dictionary) -> HBoxContainer:
	var btn := UIHelper.make_button(("%s" % race_key).capitalize(), "ghost", 0, 36)
	btn.set_meta("race_key", race_key)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = MT.BG_SURFACE
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = MT.ACCENT_NEON
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = MT.BG_ELEVATED
	btn.add_theme_stylebox_override("hover", hover_style)

	var desc: String = info.get("description", "A character.") as String
	btn.tooltip_text = desc

	_apply_race_button_style(btn, race_key == _selected_race_key)
	btn.pressed.connect(_on_race_selected.bind(race_key))

	var info_btn := _make_info_button()
	info_btn.tooltip_text = "Show details"
	info_btn.pressed.connect(_on_race_info_pressed.bind(race_key))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(btn)
	row.add_child(info_btn)
	return row

func _apply_race_button_style(btn: Button, is_selected: bool):
	var style := StyleBoxFlat.new()
	if is_selected:
		btn.self_modulate = MT.ACCENT_PRIMARY
		style.bg_color = MT.ACCENT_NEON
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = MT.ACCENT_PRIMARY
	else:
		btn.self_modulate = Color.WHITE
		style.bg_color = MT.BG_SURFACE
		style.border_width_bottom = 1
		style.border_width_top = 1
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_color = MT.ACCENT_NEON
	btn.add_theme_stylebox_override("normal", style)

func prefill_upworld_races():
	var container := $MainScroll/MainVBox/RacesHBox/UpworldPanel/UpworldVBox/UpworldScroll/UpworldButtonList as VBoxContainer
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
		var row := _create_race_button(race_key, info)
		container.add_child(row)
	
	container.queue_sort()
	print("[CharacterSelection] Populated Upworld races: %d" % upworld.size())

func prefill_underworld_races():
	var container := $MainScroll/MainVBox/RacesHBox/UnderworldPanel/UnderworldVBox/UnderworldScroll/UnderworldButtonList as VBoxContainer
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
		var row := _create_race_button(race_key, info)
		container.add_child(row)
	
	container.queue_sort()
	print("[CharacterSelection] Populated Underworld races: %d" % underworld.size())


func _on_race_selected(race_key: String):
	_selected_race_key = race_key
	_selected_portrait = 1
	_update_all_race_buttons()
	_update_portrait_preview()
	_update_selection_summary()
	
	print("[CharacterSelection] Selected race: %s (origin=%s)" % [race_key, get_origin_for_race(race_key)])

func _update_all_race_buttons():
	# Update Upworld list
	var up_container := $MainScroll/MainVBox/RacesHBox/UpworldPanel/UpworldVBox/UpworldScroll/UpworldButtonList as VBoxContainer
	if is_instance_valid(up_container):
		for wrapper in up_container.get_children():
			if not (wrapper is HBoxContainer):
				continue
			var key: String = _race_key_from_row(wrapper)
			if key.is_empty():
				continue
			_apply_race_button_style(wrapper.get_child(0), key == _selected_race_key)

	# Update Underworld list
	var under_container := $MainScroll/MainVBox/RacesHBox/UnderworldPanel/UnderworldVBox/UnderworldScroll/UnderworldButtonList as VBoxContainer
	if is_instance_valid(under_container):
		for wrapper in under_container.get_children():
			if not (wrapper is HBoxContainer):
				continue
			var key: String = _race_key_from_row(wrapper)
			if key.is_empty():
				continue
			_apply_race_button_style(wrapper.get_child(0), key == _selected_race_key)


func _race_key_from_row(wrapper: Container) -> String:
	for c in wrapper.get_children():
		if c is Button and c.has_meta("race_key"):
			return c.get_meta("race_key")
	return ""


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
	
	var scroll := $MainScroll/MainVBox/ClassPanel/ClassVBox/ClassScrollContainer/ClassButtonList as VBoxContainer
	if is_instance_valid(scroll):
		for child in scroll.get_children():
			child.queue_free()
	
	var data: Array = _load_class_data()
	if data.is_empty():
		return
	
	for entry: Variant in data:
		if entry is Dictionary and entry.has("name"):
			var key: String = (entry as Dictionary)["name"] as String

			var btn := UIHelper.make_button(("%s" % key).capitalize(), "ghost", 0, 40)
			btn.set_meta("class_key", key)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_color_override("font_color", Color.WHITE)

			var style := StyleBoxFlat.new()
			style.bg_color = MT.BG_SURFACE
			style.border_width_bottom = 1
			style.border_width_top = 1
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_color = MT.ACCENT_NEON
			btn.add_theme_stylebox_override("normal", style)
			var hover_style := style.duplicate()
			hover_style.bg_color = MT.BG_ELEVATED
			btn.add_theme_stylebox_override("hover", hover_style)

			btn.self_modulate = MT.ACCENT_PRIMARY if key == _selected_class_key else Color.WHITE
			var desc: String = entry.get("description", "") as String
			btn.tooltip_text = desc if desc != "" else ""
			btn.pressed.connect(_on_class_selected.bind(key))

			var info_btn := _make_info_button()
			info_btn.tooltip_text = "Show details"
			info_btn.pressed.connect(_on_class_info_pressed.bind(key))

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.add_child(btn)
			row.add_child(info_btn)
			scroll.add_child(row)

	# Force layout update so the list is visible immediately
	scroll.queue_sort()
	if is_instance_valid(scroll.get_parent()):
		scroll.get_parent().queue_sort()
	
	print("[CharacterSelection] Built class panel with %d buttons." % available_classes.size())


func _on_class_selected(class_key: String):
	_selected_class_key = class_key

	var scroll := $MainScroll/MainVBox/ClassPanel/ClassVBox/ClassScrollContainer/ClassButtonList as VBoxContainer
	if is_instance_valid(scroll):
		for wrapper in scroll.get_children():
			if not (wrapper is HBoxContainer):
				continue
			for c in wrapper.get_children():
				if c is Button and c.has_meta("class_key"):
					var key: String = c.get_meta("class_key")
					c.self_modulate = MT.ACCENT_PRIMARY if key == class_key else Color.WHITE
					break

	_update_selection_summary()
	print("[CharacterSelection] Selected class: %s" % class_key)


# ===================================================================
# Gender Selection
# ===================================================================

func _build_gender_buttons():
	var list := $MainScroll/MainVBox/GenderHBox/GenderButtonList as HBoxContainer
	if not is_instance_valid(list):
		push_error("[CharacterSelection] GenderButtonList not found.")
		return
	for child in list.get_children():
		child.queue_free()
	var group := ButtonGroup.new()
	for gender in ["male", "female"]:
		var btn := UIHelper.make_button(gender.capitalize(), "ghost", 120, 32, true)
		btn.button_group = group
		btn.set_meta("gender", gender)
		_apply_gender_button_style(btn, gender == _selected_gender)
		btn.pressed.connect(_on_gender_selected.bind(gender))
		list.add_child(btn)
	if _selected_gender.is_empty():
		_selected_gender = "male"
	_update_gender_buttons()
	_build_portrait_picker()


func _get_portrait_race_key() -> String:
	var data: Dictionary = _load_race_data()
	for category in ["upworld", "underworld"]:
		var group: Dictionary = data.get(category, {})
		if group.has(_selected_race_key):
			var vtag: String = str(group[_selected_race_key].get("visual_tag", ""))
			return PORTRAIT_RACE_MAP.get(vtag, vtag)
	return PORTRAIT_RACE_MAP.get(_selected_race_key.to_lower(), _selected_race_key.to_lower())


func _build_portrait_picker() -> void:
	var mv: VBoxContainer = $MainScroll/MainVBox
	if is_instance_valid(mv):
		for child in mv.get_children():
			if child.name == "PortraitHBox":
				for c in child.get_children():
					c.queue_free()
				child.queue_free()

	var hbox := UIHelper.make_hbox(12)
	hbox.name = "PortraitHBox"

	_portrait_preview = TextureRect.new()
	_portrait_preview.name = "PortraitPreview"
	_portrait_preview.custom_minimum_size = Vector2(210, 210)
	_portrait_preview.size = Vector2(210, 210)
	_portrait_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_preview.add_theme_stylebox_override("normal",
		MT.panel(MT.BG_SURFACE, MT.BORDER_STRONG, MT.RADIUS_LG, MT.BORDER_WIDTH))
	hbox.add_child(_portrait_preview)

	var btn_vbox := UIHelper.make_vbox(2)
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var prev_btn := UIHelper.make_button("<", "ghost", 40, 36)
	prev_btn.pressed.connect(_on_portrait_prev)
	btn_vbox.add_child(prev_btn)

	_portrait_index_label = UIHelper.make_accent_label("1/6", MT.FS_SMALL)
	_portrait_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_vbox.add_child(_portrait_index_label)

	var next_btn := UIHelper.make_button(">", "ghost", 40, 36)
	next_btn.pressed.connect(_on_portrait_next)
	btn_vbox.add_child(next_btn)

	hbox.add_child(btn_vbox)

	if is_instance_valid(mv):
		var name_hbox := mv.get_node_or_null("NameHBox")
		var insert_idx: int = name_hbox.get_index() + 1 if is_instance_valid(name_hbox) else mv.get_child_count()
		mv.add_child(hbox)
		mv.move_child(hbox, insert_idx)

	_update_portrait_preview()


func _on_portrait_prev() -> void:
	_selected_portrait = (_selected_portrait - 2 + 6) % 6 + 1
	_update_portrait_preview()


func _on_portrait_next() -> void:
	_selected_portrait = _selected_portrait % 6 + 1
	_update_portrait_preview()


func _update_portrait_preview() -> void:
	var parent := _portrait_preview.get_parent() if is_instance_valid(_portrait_preview) else null
	if not is_instance_valid(parent):
		return
	if _selected_race_key.is_empty():
		parent.visible = false
		return
	parent.visible = true
	var race_key: String = _get_portrait_race_key()
	var path: String = "res://assets/portraits/%s_%s/portrait_%02d.png" % [race_key, _selected_gender, _selected_portrait]
	if ResourceLoader.exists(path):
		_portrait_preview.texture = load(path)
		_portrait_preview.visible = true
	else:
		_portrait_preview.texture = null
		_portrait_preview.visible = false
	if is_instance_valid(_portrait_index_label):
		_portrait_index_label.text = "%d/6" % _selected_portrait


func _on_gender_selected(gender: String) -> void:
	_selected_gender = gender
	_selected_portrait = 1
	_update_gender_buttons()
	_update_portrait_preview()
	_update_selection_summary()
	print("[CharacterSelection] Selected gender: %s" % gender)


func _apply_gender_button_style(btn: Button, is_selected: bool):
	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = MT.ACCENT_NEON
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = MT.ACCENT_PRIMARY
		btn.self_modulate = MT.ACCENT_PRIMARY
	else:
		style.bg_color = MT.BG_SURFACE
		style.border_width_bottom = 1
		style.border_width_top = 1
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_color = MT.ACCENT_NEON
		btn.self_modulate = Color.WHITE
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = MT.BG_ELEVATED
	btn.add_theme_stylebox_override("hover", hover_style)


func _update_gender_buttons():
	var list := $MainScroll/MainVBox/GenderHBox/GenderButtonList as HBoxContainer
	if not is_instance_valid(list):
		return
	for child in list.get_children():
		if child is Button and child.has_meta("gender"):
			_apply_gender_button_style(child, child.get_meta("gender") == _selected_gender)


func _update_selection_summary():
	var name_edit := $MainScroll/MainVBox/NameHBox/NameEdit as LineEdit
	var char_name := name_edit.text.strip_edges() if is_instance_valid(name_edit) else ""
	
	var summary := $MainScroll/MainVBox/SelectionSummary as RichTextLabel
	var confirm_btn := $MainScroll/MainVBox/BottomBar/ConfirmButton as Button
	
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
	
	parts.append("[b]Gender:[/b] %s" % _selected_gender.capitalize())

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

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/WorldGeneration.tscn")


func _on_name_changed(_new_text: String):
	_update_selection_summary()

func _on_confirm_pressed():
	var name_edit := $MainScroll/MainVBox/NameHBox/NameEdit as LineEdit
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
	
	var create_success: bool = gs.create_character(_selected_race_key, _selected_class_key, origin, char_name, _selected_gender, _selected_portrait)
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
			"gender": _selected_gender,
			"stats": char_data.get("stats", {})
		})
	else:
		push_error("[CharacterSelection] Cannot reach GameManager.")


func auto_save_character(char_data: Dictionary) -> bool:
	var sm: Node = get_node_or_null("/root/SaveManager")
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
	_selected_gender = "male"

	var name_edit := $MainScroll/MainVBox/NameHBox/NameEdit as LineEdit
	if is_instance_valid(name_edit):
		name_edit.text = ""

	_build_gender_buttons()
	prefill_upworld_races()
	prefill_underworld_races()
	prefill_class_buttons()
	_update_selection_summary()
	print("[CharacterSelection] Selection reset — rebuilding UI.")
	selection_reset.emit()


# ===================================================================
# Info popups (the "i" icon next to races and classes)
# ===================================================================

func _make_info_button() -> Button:
	var btn := Button.new()
	btn.text = "i"
	btn.custom_minimum_size = Vector2(28, 28)
	MT.apply_button_style(btn, "ghost")
	return btn


func _on_race_info_pressed(race_key: String) -> void:
	var data: Dictionary = _load_race_data()
	var info: Dictionary = {}
	for category in ["upworld", "underworld"]:
		if data.has(category) and (data[category] as Dictionary).has(race_key):
			info = data[category][race_key]
			break
	if info.is_empty():
		return
	var title: String = "%s — %s" % [race_key.capitalize(), info.get("origin", "?")]
	var lines: Array[String] = []
	lines.append("[i]%s[/i]" % info.get("description", ""))
	var base: Dictionary = info.get("base_stats", {}) as Dictionary
	lines.append("\n[b]Base Stats[/b]")
	lines.append("STR %d   DEX %d   CON %d" % [
		base.get("str", 10), base.get("dex", 10), base.get("con", 10)])
	lines.append("INT %d   WIS %d   CHA %d" % [
		base.get("int", 10), base.get("wis", 10), base.get("cha", 10)])
	if info.has("flavor") and str(info.get("flavor", "")) != "":
		lines.append("\n[i][color=#%s]%s[/color][/i]" % [
			MT.TEXT_SECONDARY.to_html(false), info.get("flavor", "")])
	_show_info_window(title, "\n".join(lines))


func _on_class_info_pressed(class_key: String) -> void:
	var data: Array = _load_class_data()
	var entry: Dictionary = {}
	for e in data:
		if e is Dictionary and str(e.get("name", "")) == class_key:
			entry = e
			break
	if entry.is_empty():
		return
	var title: String = class_key.capitalize()
	var lines: Array[String] = []
	lines.append("[i]%s[/i]" % entry.get("description", ""))

	var mods: Dictionary = entry.get("stat_mods", {}) as Dictionary
	if not mods.is_empty():
		lines.append("\n[b]Stat Mods[/b]")
		var parts: Array[String] = []
		for k: String in mods:
			parts.append("%s %+d" % [k.to_upper(), int(mods[k])])
		lines.append("   ".join(parts))

	var combat: Dictionary = entry.get("combat", {}) as Dictionary
	if not combat.is_empty():
		lines.append("\n[b]Combat[/b]")
		lines.append("Role: %s  |  MP: %d  |  Range: %d  |  Reaction: %s" % [
			combat.get("role", "?"), int(combat.get("mp_max", 0)),
			int(combat.get("weapon_range", 1)), combat.get("reaction", "?")])

	var prog: Dictionary = entry.get("progression", {}) as Dictionary
	if not prog.is_empty():
		var abilities: Array = combat.get("abilities", []) as Array
		lines.append("\n[b]Progression[/b]")
		lines.append("Lv.1 → Lv.%d  |  %d unique abilities unlock over time" % [
			int(prog.get("max_level", 256)), abilities.size()])

	var skills: Array = entry.get("skills", []) as Array
	if not skills.is_empty():
		lines.append("\n[b]Skills[/b]")
		lines.append(", ".join(skills))

	_show_info_window(title, "\n".join(lines))


func _show_info_window(title: String, body_bbcode: String) -> void:
	if is_instance_valid(_info_popup):
		_info_popup.hide()
		_info_popup.queue_free()

	_info_popup = Window.new()
	_info_popup.title = title
	_info_popup.size = Vector2i(480, 380)
	_info_popup.transient = true
	_info_popup.unresizable = true
	_info_popup.exclusive = false
	_info_popup.close_requested.connect(func() -> void:
		if is_instance_valid(_info_popup):
			_info_popup.hide()
	)
	add_child(_info_popup)
	MT.apply_to(_info_popup)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	_info_popup.add_child(root)

	var title_lbl := UIHelper.make_accent_label(title, MT.FS_H3)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title_lbl)
	root.add_child(UIHelper.make_separator())

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.text = body_bbcode
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0, 240)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("default_color", MT.TEXT_PRIMARY)
	body.add_theme_font_size_override("normal_font_size", MT.FS_BODY)
	root.add_child(body)

	var btn_row := UIHelper.make_center_hbox()
	var close := UIHelper.make_button("Close", "secondary", 120, 36)
	close.pressed.connect(func() -> void:
		if is_instance_valid(_info_popup):
			_info_popup.hide()
	)
	btn_row.add_child(close)
	root.add_child(btn_row)

	_info_popup.popup_centered()
