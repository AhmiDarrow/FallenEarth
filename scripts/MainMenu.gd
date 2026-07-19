## MainMenu — Main menu screen with functional navigation via GameManager autoload
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")

@onready var new_game_btn: Button = $VBoxContainer/NewGameButton as Button
@onready var load_game_btn: Button = $VBoxContainer/LoadGameButton as Button
@onready var multiplayer_btn: Button = $VBoxContainer/MultiplayerButton as Button
@onready var options_btn: Button = $VBoxContainer/OptionsButton as Button
@onready var mods_btn: Button = get_node_or_null("VBoxContainer/ModsButton") as Button
@onready var exit_btn: Button = $VBoxContainer/ExitButton as Button

var save_dir: String = "user://saves/"
var _load_popup: Window = null
var _mp_popup: Window = null
var _mods_popup: Window = null
var _mod_settings_popup: Window = null


func _ready() -> void:
	var bg := get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.color = MT.BG_DEEP
	MT.apply_primary(new_game_btn)
	MT.apply_secondary(load_game_btn)
	MT.apply_secondary(options_btn)
	MT.apply_danger(exit_btn)
	MT.apply_secondary(multiplayer_btn)
	if mods_btn != null:
		MT.apply_secondary(mods_btn)
		mods_btn.pressed.connect(_on_mods)
	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	multiplayer_btn.pressed.connect(_on_multiplayer)
	options_btn.pressed.connect(_on_options)
	exit_btn.pressed.connect(_on_exit)
	print("[MainMenu] Main menu loaded.")
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
	_load_popup.close_requested.connect(_load_popup.hide)

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


func _on_multiplayer() -> void:
	print("[MainMenu] Multiplayer clicked")
	_show_multiplayer_menu()


func _show_multiplayer_menu() -> void:
	if is_instance_valid(_mp_popup):
		_mp_popup.queue_free()

	_mp_popup = Window.new()
	_mp_popup.title = "Multiplayer"
	_mp_popup.size = Vector2i(400, 300)
	_mp_popup.unresizable = true
	_mp_popup.transient = true
	_mp_popup.exclusive = true
	add_child(_mp_popup)
	_mp_popup.close_requested.connect(_mp_popup.hide)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	_mp_popup.add_child(root)

	var title := Label.new()
	title.text = "Play with friends"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	var desc := Label.new()
	desc.text = "Host a game or join one over LAN / direct connection."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	root.add_child(desc)

	root.add_child(_make_spacer(8))

	var host_btn := Button.new()
	host_btn.text = "Host Game"
	host_btn.custom_minimum_size = Vector2(300, 50)
	host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_btn.pressed.connect(_on_host_game)
	ButtonStyleHelper.apply_primary(host_btn)
	root.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Join Game"
	join_btn.custom_minimum_size = Vector2(300, 50)
	join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_btn.pressed.connect(_on_join_game)
	ButtonStyleHelper.apply_secondary(join_btn)
	root.add_child(join_btn)

	var scan_btn := Button.new()
	scan_btn.text = "Scan LAN"
	scan_btn.custom_minimum_size = Vector2(300, 30)
	scan_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_btn.pressed.connect(_on_scan_lan)
	ButtonStyleHelper.apply_secondary(scan_btn)
	root.add_child(scan_btn)

	root.add_child(_make_spacer(8))

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(300, 30)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void:
		_mp_popup.hide()
	)
	ButtonStyleHelper.apply_danger(back_btn)
	root.add_child(back_btn)

	_mp_popup.popup_centered()


func _on_host_game() -> void:
	print("[MainMenu] Hosting game...")
	var lm: Node = get_node_or_null("/root/LobbyManager")
	if lm == null or not lm.has_method("host_lobby"):
		push_error("[MainMenu] LobbyManager not available")
		return
	if lm.host_lobby():
		_show_lobby_panel(true)
	else:
		_save_label("Failed to host game.")


func _on_join_game() -> void:
	_show_join_dialog()


func _on_scan_lan() -> void:
	print("[MainMenu] Scanning LAN...")
	var lm: Node = get_node_or_null("/root/LobbyManager")
	if lm == null or not lm.has_method("start_lan_discovery"):
		push_error("[MainMenu] LobbyManager not available")
		return
	lm.start_lan_discovery()
	if lm.is_connected("lobby_list_updated", _on_lan_list_updated):
		return
	lm.lobby_list_updated.connect(_on_lan_list_updated)
	_save_label("Scanning LAN...")


func _on_lan_list_updated(lobbies: Array) -> void:
	if lobbies.is_empty():
		_save_label("No LAN games found.")
		return
	_save_label("Found %d LAN game(s)." % lobbies.size())
	_show_lan_list(lobbies)


func _show_lan_list(lobbies: Array) -> void:
	if is_instance_valid(_load_popup):
		_load_popup.queue_free()
	_load_popup = Window.new()
	_load_popup.title = "LAN Games"
	_load_popup.size = Vector2i(420, 320)
	_load_popup.unresizable = true
	_load_popup.transient = true
	_load_popup.exclusive = true
	add_child(_load_popup)
	_load_popup.close_requested.connect(_load_popup.hide)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_popup.add_child(root)

	var title := Label.new()
	title.text = "Select a game to join:"
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for entry in lobbies:
		var btn := Button.new()
		btn.text = "%s — %d players (%s)" % [entry.name, entry.players, entry.host]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(360, 36)
		var host_ip: String = str(entry.host)
		var port: int = int(entry.port)
		btn.pressed.connect(func() -> void:
			_load_popup.hide()
			_connect_to(host_ip, port)
		)
		list.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _load_popup.hide())
	root.add_child(cancel)

	_load_popup.popup_centered()


func _show_join_dialog() -> void:
	if is_instance_valid(_load_popup):
		_load_popup.queue_free()
	_load_popup = Window.new()
	_load_popup.title = "Join Game"
	_load_popup.size = Vector2i(400, 200)
	_load_popup.unresizable = true
	_load_popup.transient = true
	_load_popup.exclusive = true
	add_child(_load_popup)
	_load_popup.close_requested.connect(_load_popup.hide)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	_load_popup.add_child(root)

	var title := Label.new()
	title.text = "Enter host IP address:"
	root.add_child(title)

	var ip_input := LineEdit.new()
	ip_input.placeholder_text = "e.g. 192.168.1.100"
	ip_input.custom_minimum_size = Vector2(300, 36)
	root.add_child(ip_input)

	var port_input := LineEdit.new()
	port_input.placeholder_text = "Port (default: 28900)"
	port_input.custom_minimum_size = Vector2(300, 36)
	root.add_child(port_input)

	var connect_btn := Button.new()
	connect_btn.text = "Connect"
	connect_btn.pressed.connect(func() -> void:
		var host := ip_input.text.strip_edges()
		var port_str := port_input.text.strip_edges()
		var port := 28900
		if not port_str.is_empty():
			port = int(port_str)
		if host.is_empty():
			_save_label("Enter a host address.")
			return
		_load_popup.hide()
		_connect_to(host, port)
	)
	root.add_child(connect_btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _load_popup.hide())
	root.add_child(cancel)

	_load_popup.popup_centered()


func _connect_to(host: String, port: int) -> void:
	print("[MainMenu] Joining %s:%d..." % [host, port])
	var lm: Node = get_node_or_null("/root/LobbyManager")
	if lm == null or not lm.has_method("join_lobby"):
		push_error("[MainMenu] LobbyManager not available")
		return
	if lm.join_lobby(host, port):
		_save_label("Connecting to %s:%d..." % [host, port])
		_show_lobby_panel(false)
	else:
		_save_label("Failed to connect.")


func _show_lobby_panel(is_server: bool) -> void:
	if is_instance_valid(_load_popup):
		_load_popup.queue_free()
	_load_popup = Window.new()
	_load_popup.title = "Lobby"
	_load_popup.size = Vector2i(420, 300)
	_load_popup.unresizable = true
	_load_popup.transient = true
	_load_popup.exclusive = true
	add_child(_load_popup)
	_load_popup.close_requested.connect(_load_popup.hide)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	_load_popup.add_child(root)

	var status := Label.new()
	if is_server:
		var lm: Node = get_node_or_null("/root/LobbyManager")
		var code := ""
		if lm != null and lm.has_method("get_join_code"):
			code = lm.get_join_code()
		status.text = "Hosting — Code: %s" % code
	else:
		status.text = "Connected to host"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status)

	var list_title := Label.new()
	list_title.text = "Players in lobby:"
	root.add_child(list_title)

	var player_list := VBoxContainer.new()
	player_list.name = "PlayerList"
	root.add_child(player_list)

	var lm: Node = get_node_or_null("/root/LobbyManager")
	if lm != null and lm.has_method("get_player_list"):
		for p in lm.get_player_list():
			var lbl := Label.new()
			lbl.text = "- %s" % p.name
			player_list.add_child(lbl)

	if is_server:
		var party_btn := Button.new()
		party_btn.text = "Invite All to Party"
		party_btn.pressed.connect(_on_invite_all_to_party)
		ButtonStyleHelper.apply_secondary(party_btn)
		root.add_child(party_btn)

	var start_btn := Button.new()
	if is_server:
		start_btn.text = "Start Game"
		start_btn.pressed.connect(_on_start_game)
		ButtonStyleHelper.apply_primary(start_btn)
	else:
		start_btn.text = "Leave"
		start_btn.pressed.connect(_on_leave_lobby)
		ButtonStyleHelper.apply_danger(start_btn)
	root.add_child(start_btn)

	var back_btn := Button.new()
	back_btn.text = "Disconnect"
	back_btn.pressed.connect(_on_leave_lobby)
	root.add_child(back_btn)

	_load_popup.popup_centered()


func _on_invite_all_to_party() -> void:
	print("[MainMenu] Inviting all players to party...")
	var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
	if ppm == null or not ppm.has_method("send_invite"):
		_save_label("Party system not available.")
		return
	var lm: Node = get_node_or_null("/root/LobbyManager")
	if lm == null or not lm.has_method("get_player_list"):
		return
	for p in lm.get_player_list():
		var pid: int = int(p.get("peer_id", 0))
		if pid != multiplayer.get_unique_id():
			ppm.send_invite(pid)
	_save_label("Invites sent!")


func _on_start_game() -> void:
	print("[MainMenu] Starting multiplayer game...")
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm != null and nm.has_method("is_server") and nm.is_server():
		start_multiplayer_game()
	else:
		_save_label("Only the host can start the game.")


func start_multiplayer_game() -> void:
	var gs: GameState = get_node_or_null("/root/GameState") as GameState
	if is_instance_valid(gs):
		gs.reset_session()
		gs.is_multiplayer = true
	go_to_world_gen()


func _on_leave_lobby() -> void:
	print("[MainMenu] Leaving lobby...")
	var lm: Node = get_node_or_null("/root/LobbyManager")
	if lm != null and lm.has_method("close_lobby"):
		lm.close_lobby()
	if is_instance_valid(_load_popup):
		_load_popup.queue_free()


func _make_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


func _save_label(text: String) -> void:
	save_game_label_text(text)


func _on_options() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Options.tscn")


func _on_mods() -> void:
	print("[MainMenu] Mods clicked")
	_show_mods_popup()


func _show_mods_popup() -> void:
	if is_instance_valid(_mods_popup):
		_mods_popup.queue_free()

	_mods_popup = Window.new()
	_mods_popup.title = "Mods"
	_mods_popup.size = Vector2i(560, 480)
	_mods_popup.unresizable = true
	_mods_popup.transient = true
	_mods_popup.exclusive = true
	add_child(_mods_popup)
	_mods_popup.close_requested.connect(_mods_popup.hide)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	_mods_popup.add_child(root)

	var title := Label.new()
	title.text = "Installed Mods"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "Mods are loaded from %s at startup. Restart the game after adding or removing mods." % ProjectSettings.globalize_path(ModLoader.MODS_DIR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hint.add_theme_font_size_override("font_size", 12)
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var manifests: Dictionary = ModLoader.manifests
	if manifests.is_empty() and ModLoader.failed_mods.is_empty():
		var empty := Label.new()
		empty.text = "No mods installed."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
	for mod_id in manifests:
		list.add_child(_make_mod_row(manifests[mod_id]))
	for failed_entry in ModLoader.failed_mods:
		var failed_id: String = str(failed_entry)
		if not manifests.has(failed_id):
			var lbl := Label.new()
			lbl.text = "✖ %s — failed to load (invalid manifest or script)" % failed_id
			lbl.add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
			list.add_child(lbl)

	var open_btn := Button.new()
	open_btn.text = "Open Mods Folder"
	open_btn.custom_minimum_size = Vector2(0, 36)
	open_btn.pressed.connect(func() -> void:
		OS.shell_open(ProjectSettings.globalize_path(ModLoader.MODS_DIR))
	)
	ButtonStyleHelper.apply_secondary(open_btn)
	root.add_child(open_btn)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 36)
	close.pressed.connect(func() -> void: _mods_popup.hide())
	ButtonStyleHelper.apply_danger(close)
	root.add_child(close)

	_mods_popup.popup_centered()


func _make_mod_row(manifest: Dictionary) -> Control:
	var mod_id: String = str(manifest.get("id", "?"))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	row.add_child(header)

	var name_lbl := Label.new()
	var author: String = str(manifest.get("author", ""))
	var author_txt: String = " — by %s" % author if not author.is_empty() else ""
	name_lbl.text = "%s v%s%s" % [str(manifest.get("name", mod_id)), str(manifest.get("version", "?")), author_txt]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var status := Label.new()
	if ModLoader.failed_mods.has(mod_id):
		status.text = "Failed"
		status.add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
	else:
		status.text = "Loaded"
		status.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	header.add_child(status)

	var all_settings: Dictionary = ModAPI.get_all_settings()
	if all_settings.has(mod_id) and not (all_settings[mod_id] as Dictionary).is_empty():
		var settings_btn := Button.new()
		settings_btn.text = "Settings"
		settings_btn.custom_minimum_size = Vector2(90, 28)
		var display_name: String = str(manifest.get("name", mod_id))
		settings_btn.pressed.connect(func() -> void:
			_show_mod_settings_popup(mod_id, display_name)
		)
		header.add_child(settings_btn)

	var description: String = str(manifest.get("description", ""))
	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
		desc.add_theme_font_size_override("font_size", 12)
		row.add_child(desc)

	return panel


func _show_mod_settings_popup(mod_id: String, mod_name: String) -> void:
	if is_instance_valid(_mod_settings_popup):
		_mod_settings_popup.queue_free()

	_mod_settings_popup = Window.new()
	_mod_settings_popup.title = "%s — Settings" % mod_name
	_mod_settings_popup.size = Vector2i(460, 360)
	_mod_settings_popup.unresizable = true
	_mod_settings_popup.transient = true
	_mod_settings_popup.exclusive = true
	add_child(_mod_settings_popup)
	_mod_settings_popup.close_requested.connect(_mod_settings_popup.hide)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	_mod_settings_popup.add_child(root)

	var hint := Label.new()
	hint.text = "Changes are saved immediately. Some settings may require a restart."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hint.add_theme_font_size_override("font_size", 12)
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var all_settings: Dictionary = ModAPI.get_all_settings()
	var settings: Dictionary = all_settings.get(mod_id, {})
	for key in settings:
		var setting_key: String = str(key)
		var info: Dictionary = settings[setting_key]
		var setting_type: String = str(info.get("type", "float"))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)

		var lbl := Label.new()
		lbl.text = str(info.get("display_name", setting_key))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		if setting_type == "bool":
			var cb := CheckBox.new()
			cb.button_pressed = bool(info.get("value", false))
			cb.toggled.connect(func(pressed: bool) -> void:
				ModAPI.set_setting(mod_id, setting_key, pressed)
			)
			row.add_child(cb)
		else:
			var edit := LineEdit.new()
			edit.text = str(info.get("value", ""))
			edit.custom_minimum_size = Vector2(140, 0)
			var apply := func(text: String) -> void:
				var value: Variant = text
				if setting_type == "float":
					value = text.to_float()
				elif setting_type == "int":
					value = int(text.to_float())
				ModAPI.set_setting(mod_id, setting_key, value)
			edit.text_submitted.connect(apply)
			edit.focus_exited.connect(func() -> void: apply.call(edit.text))
			row.add_child(edit)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 36)
	close.pressed.connect(func() -> void: _mod_settings_popup.hide())
	ButtonStyleHelper.apply_secondary(close)
	root.add_child(close)

	_mod_settings_popup.popup_centered()


func _on_exit() -> void:
	get_tree().quit()
