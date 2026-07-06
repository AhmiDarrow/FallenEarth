## MainMenu — Main menu screen with functional navigation via GameManager autoload
extends Control

@onready var new_game_btn: Button = $VBoxContainer/NewGameButton as Button
@onready var load_game_btn: Button = $VBoxContainer/LoadGameButton as Button
@onready var options_btn: Button = $VBoxContainer/OptionsButton as Button
@onready var exit_btn: Button = $VBoxContainer/ExitButton as Button

var save_dir: String = "user://saves/"
var _load_popup: Window = null


func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	options_btn.pressed.connect(_on_options)
	exit_btn.pressed.connect(_on_exit)
	print("[MainMenu] Main menu loaded.")
	# Start main menu music. Defensive lookup in case the autoload
	# hasn't been registered (e.g. when running a sub-scene headless).
	var mm: Node = get_node_or_null("/root/MusicManager")
	if mm != null and mm.has_method("play_track"):
		mm.call("play_track", "main_menu")
	var aa: Node = get_node_or_null("/root/AmbientAudio")
	if aa != null and aa.has_method("stop_all"):
		aa.call("stop_all", 0.3)


func save_game_label_text(text: String) -> void:
	if has_node("VBoxContainer/SaveLabel"):
		$VBoxContainer/SaveLabel.text = text
	else:
		var label: Label = Label.new()
		label.name = "SaveLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(280, 30)
		$VBoxContainer.add_child(label)
		label.text = text


func _on_new_game() -> void:
	print("[MainMenu] Starting New Game - World Generation first")
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		gs.reset_session()
	go_to_world_gen()


func go_to_world_gen() -> void:
	var game_mgr: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(game_mgr):
		game_mgr.go_to_world_gen()
	else:
		push_error("[MainMenu] GameManager autoload not found.")


func go_to_character_select() -> void:
	var game_mgr: GameManager = get_node_or_null("/root/GameManager") as GameManager
	if is_instance_valid(game_mgr):
		game_mgr.go_to_character_select()
	else:
		push_error("[MainMenu] GameManager autoload not found.")


func load_existing_slot(slot_id: int) -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs) and gs.load_game(slot_id):
		print("[MainMenu] Loaded slot %d via GameState" % slot_id)
		var char_data: Dictionary = gs.get_character_data()
		var gm: GameManager = get_node_or_null("/root/GameManager") as GameManager
		if is_instance_valid(gm) and not char_data.is_empty():
			gm.go_to_hub(char_data)
		else:
			save_game_label_text("Loaded slot %d (no character data)." % slot_id)
	else:
		save_game_label_text("Failed to load slot %d." % slot_id)


func _list_saves() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in range(9):
		var path := "user://saves/slot_%d.json" % i
		if FileAccess.file_exists(path):
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if is_instance_valid(file):
				var data: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
				var c: Variant = data.get("character", {})
				if (not c is Dictionary) or c.is_empty():
					c = data.get("game_state", {})
				var nm: String = str(data.get("save_name", ""))
				if nm == "" and c is Dictionary:
					nm = c.get("name", c.get("id", "Untitled"))
				if nm == "":
					nm = "Slot %d" % i
				var race := ""
				var cls := ""
				if c is Dictionary:
					race = str(c.get("race", ""))
					cls = str(c.get("class", ""))
				slots.append({
					"slot": i,
					"name": nm,
					"race": race,
					"class": cls,
					"autosave": data.get("autosave", false),
				})
				file.close()
	return slots


func _on_load_game() -> void:
	print("[MainMenu] Load Game clicked")
	var slots: Array[Dictionary] = _list_saves()
	if slots.is_empty():
		save_game_label_text("No saves found.")
		return
	_show_load_popup(slots)


func _show_load_popup(slots: Array[Dictionary]) -> void:
	if is_instance_valid(_load_popup):
		_load_popup.queue_free()

	_load_popup = Window.new()
	_load_popup.title = "Load Game"
	_load_popup.size = Vector2i(420, 320)
	_load_popup.unresizable = true
	_load_popup.transient = true
	_load_popup.exclusive = true
	add_child(_load_popup)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	_load_popup.add_child(root)

	var title := Label.new()
	title.text = "Select a save slot:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for entry in slots:
		var btn := Button.new()
		var autosave_tag := " [autosave]" if entry.get("autosave", false) else ""
		var detail := ""
		if entry.get("race", "") != "":
			detail = " — %s / %s" % [entry["race"], entry.get("class", "?")]
		btn.text = "Slot %d: %s%s%s" % [entry["slot"], entry["name"], detail, autosave_tag]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(360, 36)
		var slot_id: int = int(entry["slot"])
		btn.pressed.connect(func() -> void:
			_load_popup.hide()
			save_game_label_text("Loading %s..." % entry["name"])
			load_existing_slot(slot_id)
		)
		list.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _load_popup.hide())
	root.add_child(cancel)

	_load_popup.popup_centered()


func _on_options() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Options.tscn")


func _on_exit() -> void:
	get_tree().quit()