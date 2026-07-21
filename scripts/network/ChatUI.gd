## ChatUI — Chat overlay, shown as a collapsible bottom-left panel
extends Control

const MT = preload("res://assets/ui/MasterTheme.gd")
const UH = preload("res://scripts/ui/UIHelper.gd")
const MAX_MESSAGES := 50

var _chat_manager: Node = null
var _msg_container: VBoxContainer
var _input_field: LineEdit
var _toggle_btn: Button
var _scroll: ScrollContainer
var _expanded: bool = true
var _channel: String = "say"


func _init() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	size = Vector2(400, 200)
	position = Vector2(8, 500)
	name = "ChatUI"
	_build_ui()


func _build_ui() -> void:
	var panel := UH.make_surface_panel()
	panel.size = Vector2(400, 200)
	panel.position = Vector2.ZERO
	panel.mouse_filter = MOUSE_FILTER_STOP
	add_child(panel)

	var vbox := UH.make_vbox(2)
	vbox.size = Vector2(380, 180)
	vbox.position = Vector2(10, 10)
	panel.add_child(vbox)

	var header := UH.make_hbox(0)
	vbox.add_child(header)

	_toggle_btn = UH.make_button("Chat [_]", "primary", 80, 20)
	_toggle_btn.pressed.connect(_toggle)
	header.add_child(_toggle_btn)

	var chan_btn := UH.make_button("/say", "ghost", 50, 20)
	chan_btn.pressed.connect(_cycle_channel)
	header.add_child(chan_btn)
	chan_btn.name = "ChanBtn"

	_scroll = UH.make_scroll_container()
	_scroll.custom_minimum_size = Vector2(360, 120)
	vbox.add_child(_scroll)

	_msg_container = UH.make_vbox(1)
	_msg_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_msg_container)

	_input_field = UH.make_line_edit("Type here and press Enter...", 360, 24)
	_input_field.text_submitted.connect(_on_text_submitted)
	vbox.add_child(_input_field)

	UH.make_scrollable(vbox)


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		_input_field.clear()
		return
	# Parse channel prefix
	var channel := _channel
	var msg := text
	if text.begins_with("/"):
		var parts := text.split(" ", true, 1)
		var cmd := parts[0].to_lower()
		if cmd in ["/s", "/say"]:
			channel = "say"
			msg = parts[1] if parts.size() > 1 else ""
		elif cmd in ["/p", "/party"]:
			channel = "party"
			msg = parts[1] if parts.size() > 1 else ""
		elif cmd in ["/a", "/all"]:
			channel = "all"
			msg = parts[1] if parts.size() > 1 else ""
		elif cmd in ["/trade"]:
			_handle_trade_command(parts[1] if parts.size() > 1 else "")
			_input_field.clear()
			return
		elif cmd in ["/invite"]:
			_handle_invite_command(parts[1] if parts.size() > 1 else "")
			_input_field.clear()
			return
	if msg.strip_edges().is_empty():
		_input_field.clear()
		return
	if _chat_manager != null and _chat_manager.has_method("send_message"):
		_chat_manager.send_message(channel, msg)
	_input_field.clear()


func _cycle_channel() -> void:
	match _channel:
		"say":
			_channel = "party"
		"party":
			_channel = "all"
		_:
			_channel = "say"
	var btn := get_node_or_null("ChanBtn") if has_node("ChanBtn") else null
	# Find the channel button
	for child in get_children():
		var hbox := child as PanelContainer
		if hbox == null:
			continue
		var header := hbox.get_child(0) if hbox.get_child_count() > 0 else null
		if header == null or not (header is HBoxContainer):
			continue
		var chan_btn := header.get_child(1) if header.get_child_count() > 1 else null
		if chan_btn != null and (chan_btn is Button):
			chan_btn.text = "/" + _channel
			break


func add_message(sender_name: String, channel: String, text: String) -> void:
	var color := _channel_color(channel)
	var msg := UH.make_rich_section("[color=%s][%s][/color] [b]%s:[/b] %s" % [color, channel.to_upper(), sender_name, text], 0, Color.WHITE)
	msg.fit_content = true
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(340, 0)
	_msg_container.add_child(msg)
	# Trim old messages
	while _msg_container.get_child_count() > MAX_MESSAGES:
		_msg_container.get_child(0).queue_free()
	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value


func _channel_color(channel: String) -> String:
	match channel:
		"party": return "#66bb6a"
		"all": return "#ef5350"
		_: return "#b0bec5"


func _toggle() -> void:
	_expanded = not _expanded
	_scroll.visible = _expanded
	_input_field.visible = _expanded
	_toggle_btn.text = "Chat [%s]" % ("_" if _expanded else "+")


func _handle_trade_command(arg: String) -> void:
	if arg.is_empty():
		add_message("System", "say", "Usage: /trade <player_name>")
		return
	# Find player by name (case-insensitive partial match)
	var ns: Node = get_node_or_null("/root/NetworkSync")
	if ns == null:
		return
	var positions: Dictionary = ns.get_all_remote_positions() if ns.has_method("get_all_remote_positions") else {}
	var nm: Node = get_node_or_null("/root/NetworkManager")
	for pid in positions:
		var pname := "Player_%d" % pid
		if nm != null and nm.has_method("get_player_name"):
			pname = nm.get_player_name(pid)
		if pname.find(arg) >= 0 or pname.to_lower() == arg.to_lower():
			var tm: Node = get_node_or_null("/root/TradeManager")
			if tm != null and tm.has_method("send_trade_request"):
				tm.send_trade_request(int(pid))
				add_message("System", "say", "Trade request sent to %s" % pname)
			return
	add_message("System", "say", "Player '%s' not found" % arg)


func _handle_invite_command(arg: String) -> void:
	if arg.is_empty():
		add_message("System", "say", "Usage: /invite <player_name>")
		return
	var ns: Node = get_node_or_null("/root/NetworkSync")
	if ns == null:
		return
	var positions: Dictionary = ns.get_all_remote_positions() if ns.has_method("get_all_remote_positions") else {}
	var nm: Node = get_node_or_null("/root/NetworkManager")
	for pid in positions:
		var pname := "Player_%d" % pid
		if nm != null and nm.has_method("get_player_name"):
			pname = nm.get_player_name(pid)
		if pname.find(arg) >= 0 or pname.to_lower() == arg.to_lower():
			var ppm: Node = get_node_or_null("/root/PlayerPartyManager")
			if ppm != null and ppm.has_method("send_invite"):
				ppm.send_invite(int(pid))
				add_message("System", "say", "Party invite sent to %s" % pname)
			return
	add_message("System", "say", "Player '%s' not found" % arg)


func set_chat_manager(manager: Node) -> void:
	_chat_manager = manager
