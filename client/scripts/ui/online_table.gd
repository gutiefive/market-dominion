extends Control
class_name OnlineTable

## Private online room. Tiles, cash, and the seed come from the server.

signal closed_panel

const BG := Color("0e1525")
const CARD := Color("162033")
const TEAL := Color("2dd4bf")
const TEXT := Color("e8eef9")
const MUTED := Color("93a0b8")
const DANGER := Color("f0a0a0")
const AMBER := Color("fbbf24")

var _market_history := MatchJournal.new()
var _history_room := ""

var _base := "http://127.0.0.1:8741"
var _match_id := ""
var _token := ""
var _you := ""
var _version := 0
var _seq := 0
# A fresh nonce per page load keeps retries idempotent without colliding across seats or refreshes.
var _action_nonce := Crypto.new().generate_random_bytes(12).hex_encode()
var _retry_in := -1.0
var _standings: Label
var _host := false
var _step := "lobby"
var _hand: Array = []
var _pending: Array = []
var _selected := ""
var _socket := RoomSocket.new()
var _http: HTTPRequest
var _status: Label
var _error: Label
var _error_title: Label
var _error_layer: Control
var _error_body: Label
var _invite: Label
var _invite_code: Label
var _ready_list: VBoxContainer
var _start_button: Button
var _start_hint: Label
var _link_banner: Label
var _lobby: VBoxContainer
var _play: VBoxContainer
var _board: BoardGrid
var _hand_row: Container
var _actions: Container
var _lobby_actions: HBoxContainer
var _side: RichTextLabel
var _watch: MarketWatch
var _badge: Label
var _cash_label: Label
var _net_label: Label
var _checklist: Label
var _preview: Label
var _rules: RulesPanel
var _founder_layer: Control
var _founder_copy: Label
var _founder_buttons: VBoxContainer
var _merger_layer: Control
var _merger_copy: Label
var _merger_buttons: VBoxContainer
var _confirm_layer: Control
var _confirm_copy: Label
var _confirm_command := ""
var _confirm_payload: Dictionary = {}
var _event_layer: Control
var _event_copy: Label
var _dismissed_event := ""
var _public: Dictionary = {}
var _nickname: LineEdit
var _join_match: LineEdit
var _join_code: LineEdit
var _server: LineEdit
var _restore: Button
var _form_scroll: ScrollContainer
var _pending_http := "command"
var _zoom_steps := 0
var _reconnect_attempts := 0


static func server_from_search(search: String) -> String:
	var text := search.strip_edges()
	var hash := text.find("#")
	if hash >= 0:
		text = text.substr(0, hash)
	var query := text
	var qmark := text.find("?")
	if qmark >= 0:
		query = text.substr(qmark + 1)
	elif text.contains("://"):
		return ""
	for part in query.split("&"):
		if part == "":
			continue
		var bits := part.split("=", true, 1)
		if bits.size() != 2:
			continue
		if bits[0].uri_decode() != "server":
			continue
		var value := bits[1].uri_decode().strip_edges()
		if value.begins_with("https://") or value.begins_with("http://"):
			return value
		return ""
	return ""


static func invite_from_search(search: String) -> String:
	var query := _query_of(search)
	if query == "":
		return ""
	for part in query.split("&"):
		var bits := part.split("=", true, 1)
		if bits.size() != 2 or bits[0].uri_decode() != "invite":
			continue
		var value := bits[1].uri_decode().strip_edges().to_upper()
		if value.length() < 4 or value.length() > 12:
			return ""
		return value
	return ""


static func invitation_href(page: String, code: String) -> String:
	var text := page.strip_edges()
	var hash := text.find("#")
	if hash >= 0:
		text = text.substr(0, hash)
	var base := text
	var query := ""
	var qmark := text.find("?")
	if qmark >= 0:
		base = text.substr(0, qmark)
		query = text.substr(qmark + 1)
	var kept: PackedStringArray = []
	for part in query.split("&"):
		if part == "":
			continue
		var bits := part.split("=", true, 1)
		var key := bits[0].uri_decode()
		if key == "invite" or key == "session_token" or key == "token":
			continue
		kept.append(part)
	kept.append("invite=%s" % code.uri_encode())
	if base == "":
		return "?%s" % "&".join(kept)
	return "%s?%s" % [base, "&".join(kept)]


static func _query_of(search: String) -> String:
	var text := search.strip_edges()
	var hash := text.find("#")
	if hash >= 0:
		text = text.substr(0, hash)
	var qmark := text.find("?")
	if qmark >= 0:
		return text.substr(qmark + 1)
	if text.contains("://"):
		return ""
	return text


func _web_server_query() -> String:
	if not OS.has_feature("web"):
		return ""
	var raw: Variant = JavaScriptBridge.eval("window.location.search", true)
	if typeof(raw) != TYPE_STRING:
		return ""
	return server_from_search(str(raw))


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	Palette.load_settings()
	_socket.message_received.connect(_on_socket)
	_socket.closed.connect(_on_socket_closed)
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http)
	_build()


func _process(delta: float) -> void:
	_socket.poll()
	if _retry_in >= 0.0:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_retry_in = -1.0
			_connect_socket()


func show_snapshot(event: Dictionary) -> void:
	_on_event(event)
	visible = true


func _build() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_preset(PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	_form_scroll = scroll
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_top = 8
	scroll.offset_right = -12
	scroll.offset_bottom = -8
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)
	var header := HFlowContainer.new()
	root.add_child(header)
	var title := _note("Online room")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("Rules", func() -> void: _rules.show_panel()))
	header.add_child(_button("Back to local", _close))
	_link_banner = _note("")
	_link_banner.add_theme_color_override("font_color", AMBER)
	root.add_child(_link_banner)
	_status = _note("")
	_error = _note("")
	_error.add_theme_color_override("font_color", DANGER)
	root.add_child(_status)
	root.add_child(_error)
	_lobby = VBoxContainer.new()
	_lobby.add_theme_constant_override("separation", 8)
	root.add_child(_lobby)
	var server_text := "http://127.0.0.1:8741"
	if OS.has_feature("web"):
		server_text = ""
	var from_page := _configured_server()
	if from_page != "":
		server_text = from_page
	_server = _field(server_text)
	if from_page != "":
		_server.editable = false
	_nickname = _field("Rowan")
	_join_match = _field("")
	_join_code = _field("")
	_lobby.add_child(_labeled("Server", _server))
	_lobby.add_child(_labeled("Nickname", _nickname))
	_lobby.add_child(_button("Create private room", _create_room))
	_lobby.add_child(_labeled("Match id", _join_match))
	_lobby.add_child(_labeled("Invite code", _join_code))
	_lobby.add_child(_button("Join with invite", _join_room))
	_invite_code = _note("Invite code appears here after the server creates the room.")
	_invite_code.add_theme_font_size_override("font_size", 28)
	_invite_code.add_theme_color_override("font_color", TEAL)
	_lobby.add_child(_invite_code)
	_lobby.add_child(_button("Copy invitation link", _copy_invite))
	_invite = _note("The server deals the tiles. This screen never shuffles them.")
	_lobby.add_child(_invite)
	_ready_list = VBoxContainer.new()
	_lobby.add_child(_ready_list)
	_lobby_actions = HBoxContainer.new()
	_lobby_actions.add_theme_constant_override("separation", 8)
	_lobby.add_child(_lobby_actions)
	_start_hint = _note("The host starts when 2–4 players are in the room and every one of them is ready.")
	_lobby.add_child(_start_hint)
	_restore = _button("Restore this browser's room", _restore_saved_session)
	_restore.visible = false
	_lobby.add_child(_restore)
	_play = VBoxContainer.new()
	_play.visible = false
	_play.add_theme_constant_override("separation", 6)
	root.add_child(_play)
	_standings = _note("")
	_standings.add_theme_color_override("font_color", TEXT)
	_standings.add_theme_font_size_override("font_size", 20)
	_play.add_child(_standings)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("separation", 8)
	_play.add_child(top)
	_badge = _note("Seat")
	_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	_badge.add_theme_color_override("font_color", AMBER)
	top.add_child(_badge)
	_cash_label = _note("Cash")
	_cash_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cash_label.custom_minimum_size = Vector2(130, 0)
	_cash_label.add_theme_color_override("font_color", TEXT)
	top.add_child(_cash_label)
	_net_label = _note("Net")
	_net_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_net_label.custom_minimum_size = Vector2(130, 0)
	_net_label.add_theme_color_override("font_color", TEAL)
	top.add_child(_net_label)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var table := HBoxContainer.new()
	table.add_theme_constant_override("separation", 10)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_child(column)
	_play.add_child(table)
	_play.set_meta("table", table)
	_play.set_meta("column", column)
	_checklist = _note("Turn")
	_checklist.add_theme_color_override("font_color", TEXT)
	column.add_child(_checklist)
	_preview = _note("Hover or focus a district.")
	column.add_child(_preview)
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 8)
	column.add_child(zoom_row)
	zoom_row.add_child(_button("Zoom out", func() -> void: _nudge_zoom(-1)))
	zoom_row.add_child(_button("Zoom in", func() -> void: _nudge_zoom(1)))
	_board = BoardGrid.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_board)
	_board.cell_pressed.connect(_choose_cell)
	_board.cell_hovered.connect(_on_hover)
	var hand_caption := _note("Your tiles — only this session")
	hand_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	hand_caption.add_theme_color_override("font_color", TEXT)
	column.add_child(hand_caption)
	_hand_row = HFlowContainer.new()
	_hand_row.add_theme_constant_override("separation", 8)
	column.add_child(_hand_row)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 6)
	_actions.add_theme_constant_override("v_separation", 6)
	column.add_child(_actions)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(280, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	(_play.get_meta("table") as HBoxContainer).add_child(side)
	_play.set_meta("side", side)
	side.add_child(_note("Market watchlist · history since this page joined"))
	_watch = MarketWatch.new()
	side.add_child(_watch)
	side.add_child(_note("Activity"))
	_side = RichTextLabel.new()
	_side.bbcode_enabled = false
	_side.fit_content = true
	_side.scroll_active = false
	_side.custom_minimum_size = Vector2(0, 64)
	_side.add_theme_color_override("default_color", TEXT)
	side.add_child(_side)
	_rules = RulesPanel.new()
	add_child(_rules)
	_founder_layer = _choice_layer("Found a company")
	_founder_copy = _layer_label(_founder_layer, 1)
	_founder_buttons = _layer_box(_founder_layer, 2)
	add_child(_founder_layer)
	_merger_layer = _choice_layer("Choose the surviving company")
	_merger_copy = _layer_label(_merger_layer, 1)
	_merger_buttons = _layer_box(_merger_layer, 2)
	add_child(_merger_layer)
	_confirm_layer = _choice_layer("Confirm market action")
	_confirm_copy = _layer_label(_confirm_layer, 1)
	var confirm_buttons := _layer_box(_confirm_layer, 2)
	confirm_buttons.add_child(_button("Confirm", _apply_confirm))
	confirm_buttons.add_child(_button("Cancel", func() -> void: _confirm_layer.visible = false))
	add_child(_confirm_layer)
	_event_layer = _choice_layer("Round event")
	_event_copy = _layer_label(_event_layer, 1)
	_layer_box(_event_layer, 2).add_child(_button("Continue", _dismiss_event))
	add_child(_event_layer)
	_error_layer = _choice_layer("Something went wrong")
	_error_title = _layer_label(_error_layer, 0)
	_error_body = _layer_label(_error_layer, 1)
	_layer_box(_error_layer, 2).add_child(_button("Dismiss", func() -> void: _error_layer.visible = false))
	_layer_box(_error_layer, 2).add_child(_button("Reconnect", _reconnect))
	add_child(_error_layer)
	_apply_page_invite()
	_offer_saved_session()
	resized.connect(_fit_board)


func present() -> void:
	visible = true
	_apply_full_rect()
	move_to_front()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		call_deferred("_apply_full_rect")


func _apply_full_rect() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if _form_scroll == null:
		return
	_form_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_form_scroll.offset_left = 12
	_form_scroll.offset_top = 8
	_form_scroll.offset_right = -12
	_form_scroll.offset_bottom = -8


func _create_room() -> void:
	_base = _server.text.strip_edges()
	_match_id = "room_%s" % Crypto.new().generate_random_bytes(12).hex_encode()
	_post(RoomCommands.envelope(_match_id, _next_action(), 0, "guesttoken", "create_room", {"nickname": _nickname.text.strip_edges()}))


func _join_room() -> void:
	_base = _server.text.strip_edges()
	if _base == "":
		_error.text = "Set the server, or open the page with ?server= or window.MD_SERVER."
		_show_problem("Server address missing", _error.text, false)
		return
	var code := _join_code.text.strip_edges().to_upper()
	if _join_match.text.strip_edges() == "" and code != "":
		_resolve_invite(code, true)
		return
	_match_id = _join_match.text.strip_edges()
	_pending_http = "command"
	_post(RoomCommands.envelope(
		_match_id, _next_action(), 0, "guesttoken", "join_room",
		{"invite_code": code, "nickname": _nickname.text.strip_edges()}
	))


func _post(body: Dictionary) -> void:
	_error.text = ""
	var url := _base + "/v1/rooms/commands"
	_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))


func _on_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _pending_http
	_pending_http = "command"
	if kind.begins_with("invite"):
		_on_invite_http(result, code, body, kind == "invite_join")
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_error.text = "The server did not answer. Start it with ./scripts/dev.sh."
		_show_problem("Server did not answer", _error.text, true)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_error.text = "The server returned %d." % code
		_show_problem("Server error", _error.text, false)
		return
	var events: Array = parsed.get("events", [])
	if events.is_empty():
		_error.text = "The server returned no events."
		_show_problem("Server error", _error.text, false)
		return
	var first: Dictionary = events[0]
	if str(first.get("event", "")) == "error":
		var error_code := str(first["payload"].get("code", "error"))
		_error.text = "%s — %s" % [error_code, str(first["payload"].get("message", "rejected"))]
		_show_problem(_error_heading(error_code), _error.text, false)
		return
	for event in events:
		_on_event(event)
	_connect_socket()


func _connect_socket() -> void:
	if _token == "":
		return
	var ws := _base.replace("https://", "wss://").replace("http://", "ws://")
	var url := "%s/v1/rooms/ws?match_id=%s&session_token=%s" % [ws, _match_id, _token]
	_socket.connect_to(url)


func _on_socket(event: Dictionary) -> void:
	_on_event(event)


func _on_socket_closed() -> void:
	if _token == "":
		return
	_market_history.gap()
	_reconnect_attempts += 1
	if _reconnect_attempts > 4:
		_link_banner.text = "Connection lost. Press Reconnect to try again."
		_show_problem("Connection lost", "The socket closed. Press Reconnect. The session token stays in this browser.", true)
		return
	_link_banner.text = "Connection lost. Reconnecting with the same session token."
	_show_problem("Connection lost", "The socket closed. The client is reconnecting with your session token. Tiles stay on the server.", true)
	_retry_in = minf(pow(2.0, _reconnect_attempts - 1), 8.0)


func _on_event(event: Dictionary) -> void:
	var name := str(event.get("event", ""))
	if name == "error":
		var payload: Dictionary = event["payload"]
		var code := str(payload.get("code", "error"))
		_error.text = "%s — %s" % [code, str(payload.get("message", "rejected"))]
		_show_problem(_error_heading(code), _error.text, code == "unauthorized")
		if code == "stale_version":
			_send("request_snapshot", {})
		return
	if name == "player_disconnected":
		_link_banner.text = "A seat disconnected. The server passes that turn after the grace period."
	if name == "turn_changed":
		var turn_info: Dictionary = event.get("payload", {})
		if str(turn_info.get("reason", "")) == "grace_elapsed":
			_link_banner.text = "Time expired. The server played a safe pass for that seat."
	if name == "player_reconnected":
		_link_banner.text = "Reconnected. This session was restored from the server."
		_error_layer.visible = false
	if event.has("state_version"):
		_version = int(event["state_version"])
	if name == "room_updated":
		var info: Dictionary = event["payload"]
		if info.has("session_token"):
			_token = str(info["session_token"])
			_you = str(info.get("player_id", _you))
			_remember_session()
		if info.has("invite_code"):
			_invite.text = "Match %s    invite %s" % [_match_id, str(info["invite_code"])]
			_join_match.text = _match_id
			_join_code.text = str(info["invite_code"])
		_host = str(info.get("host_id", "")) == _you
	if name == "state_snapshot":
		_apply_snapshot(event["payload"])


func _apply_snapshot(payload: Dictionary) -> void:
	if str(payload.get("you", "")) != "":
		_you = str(payload["you"])
	_hand = payload.get("your_hand", [])
	_step = str(payload.get("step", "lobby"))
	_pending = payload.get("pending_options", [])
	var state: Dictionary = payload["state"]
	if _history_room != str(state["match_id"]):
		_market_history = MatchJournal.new()
		_history_room = str(state["match_id"])
	var quotes := {"BYTE": int(state["crypto_market"]["price"])}
	for corp in state["corporations"]:
		quotes[str(corp["id"])] = int(corp["share_price"]) if bool(corp["active"]) else null
	_market_history.observe(int(state["round_number"]), int(state["version"]), quotes, "Received snapshot")
	_public = state
	_version = int(state["version"])
	if _reconnect_attempts > 0:
		_link_banner.text = "Reconnected. Your seat was restored."
	_reconnect_attempts = 0
	_retry_in = -1.0
	_error_layer.visible = false
	var playing := str(state["phase"]) != "lobby"
	_lobby.visible = not playing
	_play.visible = playing
	if not playing:
		_status.text = "Lobby. Ready, then the host starts when 2–4 players are ready."
		_show_lobby_actions(state)
		return
	var mine := str(state.get("active_player_id", "")) == _you and str(state["phase"]) != "completed"
	_status.text = "Version %d. %s" % [_version, "Your turn." if mine else "Waiting for the other seat."]
	_standings.text = ""
	if str(state["phase"]) == "completed":
		_status.text = "Match complete. Version %d." % _version
		_link_banner.text = "Match complete. Final standings below."
		var lines: PackedStringArray = ["Final standings"]
		var rank := 0
		for player_id in final_ranking(state):
			rank += 1
			for player in state["players"]:
				if str(player["id"]) == str(player_id):
					lines.append("%d. %s — $%d" % [rank, str(player["display_name"]), _net_worth(state, player)])
		_standings.text = "\n".join(lines)
	var occupied := {}
	var companies := {}
	for cell in state["board"]:
		occupied[str(cell["coordinate"])] = bool(cell["occupied"])
		if cell["company_id"] != null:
			companies[str(cell["coordinate"])] = str(cell["company_id"])
	var legal: Array = _hand.duplicate() if mine and _step == "place" else []
	_board.set_state(occupied, companies, legal, _selected)
	_fit_board()
	_fill_hand(mine)
	_fill_actions(mine, state)
	_fill_online_chrome(state, mine)
	_side.text = _side_text(state, mine)
	_sync_online_modals(mine, state)


func _show_lobby_actions(state: Dictionary) -> void:
	var code := _join_code.text.strip_edges()
	_invite_code.text = code if code != "" else "No invite code yet"
	for child in _ready_list.get_children():
		child.queue_free()
	var ready_count := 0
	for player in state["players"]:
		var ready := bool(player["is_ready"])
		if ready:
			ready_count += 1
		var mark := "✓ ready" if ready else "· not ready"
		var row := _note("%s  %s  %s  %s" % [mark, str(player["display_name"]), str(player["id"]), "host" if str(player["id"]) == "p1" else "guest"])
		row.add_theme_color_override("font_color", TEXT)
		_ready_list.add_child(row)
	var seated := int(state["players"].size())
	var can_start := seated >= 2 and seated <= 4 and ready_count == seated
	_invite.text = "Match %s. Share the invite code. The server keeps the tiles." % _match_id
	for child in _lobby_actions.get_children():
		child.queue_free()
	_lobby_actions.add_child(_button("Ready", func() -> void: _send("ready", {"is_ready": true})))
	if _you == "p1":
		var start := _button("Start match", func() -> void: _send("start_match", {}))
		start.disabled = not can_start
		_lobby_actions.add_child(start)
		if can_start:
			_start_hint.text = "Everyone is ready. You can start."
		elif seated < 2:
			_start_hint.text = "Need at least 2 players before the host can start."
		else:
			_start_hint.text = "%d of %d ready. Start stays off until every seat is ready." % [ready_count, seated]
	else:
		_start_hint.text = "Only the host starts, and only when 2–4 players are ready."


func _fill_hand(mine: bool) -> void:
	for child in _hand_row.get_children():
		child.queue_free()
	if _hand.is_empty():
		if mine and _step == "place":
			_hand_row.add_child(_button("Skip placement", func() -> void: _send("end_turn", {})))
		else:
			_hand_row.add_child(_note("none"))
		return
	for tile in _hand:
		var coordinate := str(tile)
		if mine and _step == "place":
			var button := _button(coordinate, _place_hand.bind(coordinate))
			button.custom_minimum_size = Vector2(72, 40)
			_hand_row.add_child(button)
		else:
			var label := _note(coordinate)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", TEXT)
			label.custom_minimum_size = Vector2(56, 36)
			_hand_row.add_child(label)


func _fill_actions(mine: bool, state: Dictionary) -> void:
	for child in _actions.get_children():
		child.queue_free()
	if not mine:
		return
	if _step == "choose_founder" or _step == "choose_survivor":
		_actions.add_child(_note("Choose in the dialog."))
		return
	if _step != "market":
		return
	for corp in state["corporations"]:
		if not bool(corp["active"]):
			continue
		var corp_id := str(corp["id"])
		var corp_name := str(corp["name"])
		_actions.add_child(_button("Buy " + corp_name, _queue_trade.bind("market_buy_share", corp_id, "Buy 1 %s at the posted price?" % corp_name)))
		_actions.add_child(_button("Sell " + corp_name, _queue_trade.bind("market_sell_share", corp_id, "Sell 1 %s at the posted price?" % corp_name)))
	_actions.add_child(_button("Buy BYTE", _queue_trade.bind("market_buy_byte", "", "Buy 1 BYTE at the posted price?")))
	_actions.add_child(_button("Sell BYTE", _queue_trade.bind("market_sell_byte", "", "Sell 1 BYTE at the posted price?")))
	_actions.add_child(_button("Pass", _queue_trade.bind("pass_market_action", "", "Pass this market action?")))


func _place_hand(coordinate: String) -> void:
	_selected = coordinate
	_send("place_tile", {"coordinate": coordinate})


func _trade(command: String, corp_id: String) -> void:
	_send(command, {"corporation_id": corp_id})


func _send(command: String, payload: Dictionary) -> void:
	_error.text = ""
	var body := RoomCommands.envelope(_match_id, _next_action(), _version, _token, command, payload)
	if _socket.is_open():
		_socket.send_text(JSON.stringify(body))
		return
	_post(body)


func _side_text(state: Dictionary, mine: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("Phase %s  round %s  bag %d  you %s" % [
		str(state["phase"]), str(state["round_number"]), int(state["tile_bag_count"]), _you
	])
	var log: Array = state["action_log"]
	var start := maxi(0, log.size() - 4)
	for index in range(start, log.size()):
		lines.append(str(log[index]["outcome"]))
	if not mine:
		lines.append("Your tiles stay on this session only.")
	return "\n".join(lines)


func _fill_online_chrome(state: Dictionary, mine: bool) -> void:
	var active_id := str(state.get("active_player_id", ""))
	var active_name := active_id
	var mine_player: Dictionary = {}
	for player in state["players"]:
		if str(player["id"]) == active_id:
			active_name = str(player["display_name"])
		if str(player["id"]) == _you:
			mine_player = player
	var who := "you" if mine else "waiting"
	_badge.text = "%s  %s  ·  %s" % [active_name, active_id, who]
	if str(state["phase"]) == "completed":
		_badge.text = "Match complete · your seat %s" % _you
	var cash := int(mine_player.get("cash", 0)) if not mine_player.is_empty() else 0
	_cash_label.text = "Cash $%d" % cash
	_net_label.text = "Net $%d" % _net_worth(state, mine_player)
	var place_mark := "Now" if _step == "place" else "Done"
	var resolve_mark := "Now" if _step == "choose_founder" or _step == "choose_survivor" else "After place"
	var market_mark := "Now" if _step == "market" else "Up to 2"
	_checklist.text = "1 %s place   ·   2 %s resolve   ·   3 %s market" % [place_mark, resolve_mark, market_mark]
	if str(state["phase"]) == "completed":
		_checklist.text = "Final scores include shares and BYTE at the closing prices."
	var rows: Array = []
	var market: Dictionary = state["crypto_market"]
	var byte_count := int(mine_player.get("byte_count", 0)) if not mine_player.is_empty() else 0
	rows.append({
		"active": true,
		"symbol": "¤",
		"mark": "BYTE",
		"name": "BYTE coin",
		"detail": "$%d   exchange %d   you %d" % [int(market["price"]), int(market["exchange_coin_count"]), byte_count],
		"history": _market_history.points("BYTE"),
		"coverage": "Observed since this page joined; reconnect gaps are not interpolated.",
	})
	var holdings: Dictionary = mine_player.get("holdings_by_corp", {}) if not mine_player.is_empty() else {}
	var sentiment: Dictionary = state["sector_sentiment"]
	for corp in state["corporations"]:
		var sector := str(corp["sector"])
		var value := int(sentiment.get(sector, 0))
		var shown := "+%d" % value if value > 0 else str(value)
		rows.append({
			"active": bool(corp["active"]),
			"symbol": str(BoardGrid.SYMBOLS.get(corp["id"], "")),
			"mark": str(BoardGrid.MARKS.get(corp["id"], "")),
			"name": str(corp["name"]),
			"price": int(corp["share_price"]),
			"sentiment": "%s %s" % [sector, shown],
			"size": int(corp["size"]),
			"bank": int(corp["bank_shares"]),
			"yours": int(holdings.get(corp["id"], 0)),
			"history": _market_history.points(str(corp["id"])),
			"coverage": "Observed since this page joined; reconnect gaps are not interpolated.",
		})
	_watch.show_rows(rows)
	var latest := ""
	for entry in state["action_log"]:
		var outcome := str(entry.get("outcome", ""))
		if outcome.begins_with("Round event:"):
			latest = outcome
	var show_event := latest != "" and latest != _dismissed_event and str(state["phase"]) != "completed"
	_event_layer.visible = show_event
	_event_copy.text = latest


static func final_ranking(state: Dictionary) -> PackedStringArray:
	var rows: Array = []
	for player in state["players"]:
		var net := int(player["cash"]) + int(player["byte_count"]) * int(state["crypto_market"]["price"])
		var active_shares := 0
		for corp in state["corporations"]:
			if bool(corp["active"]):
				var count := int(player["holdings_by_corp"].get(corp["id"], 0))
				active_shares += count
				net += count * int(corp["share_price"])
		rows.append({"id": player["id"], "net_worth": net, "cash": int(player["cash"]), "active_shares": active_shares, "turn_order_index": int(player["turn_order_index"])})
	return Ranking.rank_players(rows)


func _net_worth(state: Dictionary, player: Dictionary) -> int:
	if player.is_empty():
		return 0
	var net := int(player["cash"])
	var market: Dictionary = state["crypto_market"]
	net += int(player["byte_count"]) * int(market["price"])
	var holdings: Dictionary = player.get("holdings_by_corp", {})
	for corp in state["corporations"]:
		if bool(corp["active"]):
			net += int(holdings.get(corp["id"], 0)) * int(corp["share_price"])
	return net


func _sync_online_modals(mine: bool, state: Dictionary) -> void:
	_founder_layer.visible = false
	_merger_layer.visible = false
	if not mine:
		return
	if _step == "choose_founder":
		_fill_choice(_founder_buttons, _founder_copy, "choose_founder", "Pick an inactive brand. The founder share comes from the bank when one remains.")
		_founder_layer.visible = true
	elif _step == "choose_survivor":
		_fill_choice(_merger_buttons, _merger_copy, "choose_merger_survivor", "The company you keep absorbs the chain. The others pay bonuses, then their shares are sold back.")
		_merger_layer.visible = true


func _fill_choice(box: VBoxContainer, copy: Label, command: String, text: String) -> void:
	copy.text = text
	for child in box.get_children():
		child.queue_free()
	for option in _pending:
		var corp_id := str(option)
		var label := "%s  %s  %s" % [
			str(BoardGrid.SYMBOLS.get(corp_id, "")),
			corp_id,
			str(BoardGrid.MARKS.get(corp_id, "")),
		]
		for corp in _public.get("corporations", []):
			if str(corp["id"]) == corp_id:
				label = "%s  %s  %s  size %d  $%d" % [
					str(BoardGrid.SYMBOLS.get(corp_id, "")),
					str(corp["name"]),
					str(BoardGrid.MARKS.get(corp_id, "")),
					int(corp["size"]),
					int(corp["share_price"]),
				]
		box.add_child(_button(label, _trade.bind(command, corp_id)))


func _queue_trade(command: String, corp_id: String, summary: String) -> void:
	_confirm_command = command
	_confirm_payload = {} if corp_id == "" else {"corporation_id": corp_id}
	_confirm_copy.text = summary + " The server checks cash and inventory. This screen does not change them."
	_confirm_layer.visible = true
	_confirm_layer.move_to_front()


func _apply_confirm() -> void:
	var command := _confirm_command
	var payload := _confirm_payload.duplicate()
	_confirm_layer.visible = false
	_confirm_command = ""
	if command == "":
		return
	_send(command, payload)


func _nudge_zoom(step: int) -> void:
	_zoom_steps = clampi(_zoom_steps + step, 0, 3)
	_fit_board()
	_preview.text = "Zoom step %d. Scroll to reach districts past the window." % _zoom_steps


func _layout_online(wide: bool) -> void:
	var table := _play.get_meta("table") as HBoxContainer
	var column := _play.get_meta("column") as VBoxContainer
	var side := _play.get_meta("side") as VBoxContainer
	if table == null or column == null or side == null:
		return
	var on_table := side.get_parent() == table
	if wide and not on_table:
		side.get_parent().remove_child(side)
		table.add_child(side)
		side.custom_minimum_size = Vector2(280, 0)
	elif not wide and on_table:
		table.remove_child(side)
		column.add_child(side)
		side.custom_minimum_size = Vector2(0, 0)


func _fit_board() -> void:
	if _board == null or not _play.visible:
		return
	var window := get_viewport_rect().size
	if window.x < 2.0:
		return
	for layer in [_founder_layer, _merger_layer, _confirm_layer, _event_layer, _error_layer]:
		var center := layer.get_child(1) as CenterContainer
		var card := center.get_child(0) as PanelContainer
		card.custom_minimum_size.x = minf(460, window.x - 24)
	_layout_online(window.x >= 980.0)
	var side := 300.0 if window.x >= 980.0 else 0.0
	var cell := int((window.x - side - 80.0) / 10.0)
	if window.y < 800.0:
		cell = mini(cell, 26)
	if window.x < 720.0:
		cell = maxi(cell, 28)
	_board.set_cell_size(clampi(cell + _zoom_steps * 6, 28 if window.x < 720.0 else 24, 58))


func _on_hover(coordinate: String) -> void:
	if _board != null:
		_preview.text = _board._tip(coordinate, false, _board._legal.has(coordinate), "")


func _copy_invite() -> void:
	var code := _join_code.text.strip_edges()
	if code == "":
		_link_banner.text = "Create or join a room before copying an invitation."
		return
	var page := ""
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("String(window.location.href || '')", true)
		if typeof(raw) == TYPE_STRING:
			page = str(raw)
	var link := invitation_href(page, code)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.clipboard.writeText(%s)" % JSON.stringify(link), true)
	else:
		DisplayServer.clipboard_set(link)
	_link_banner.text = link


func _configured_server() -> String:
	var from_query := _web_server_query()
	if from_query != "":
		return from_query
	if not OS.has_feature("web"):
		return ""
	var raw: Variant = JavaScriptBridge.eval("String(window.MD_SERVER || '')", true)
	if typeof(raw) != TYPE_STRING:
		return ""
	var value := str(raw).strip_edges()
	if value.begins_with("https://") or value.begins_with("http://"):
		return value
	return ""


func _resolve_invite(code: String, then_join: bool) -> void:
	_pending_http = "invite_join" if then_join else "invite"
	_base = _server.text.strip_edges()
	var url := "%s/v1/rooms/invites/%s" % [_base, code.uri_encode()]
	_http.request(url, PackedStringArray(), HTTPClient.METHOD_GET)


func _on_invite_http(result: int, code: int, body: PackedByteArray, then_join: bool) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_error.text = "That invitation was not found."
		_show_problem("Invitation not found", _error.text, false)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("match_id"):
		_error.text = "The invitation response was unreadable."
		_show_problem("Invitation not found", _error.text, false)
		return
	_join_match.text = str(parsed["match_id"])
	_join_code.text = str(parsed.get("invite_code", _join_code.text))
	_link_banner.text = "Room %s has %s players. Enter a nickname and join." % [str(parsed["match_id"]), str(parsed.get("player_count", ""))]
	var saved := _saved_session()
	if not then_join and not saved.is_empty() and str(saved.get("match_id", "")) == str(parsed["match_id"]):
		_restore_saved_session()
		return
	if then_join:
		_join_room()


func _apply_page_invite() -> void:
	if not OS.has_feature("web"):
		return
	var raw: Variant = JavaScriptBridge.eval("String(window.location.search || '')", true)
	if typeof(raw) != TYPE_STRING:
		return
	var code := invite_from_search(str(raw))
	if code == "":
		return
	_join_code.text = code
	_link_banner.text = "Invitation %s is ready. Enter a nickname and join." % code
	if _server.text.strip_edges() != "":
		_resolve_invite(code, false)


func _saved_session() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw: Variant = JavaScriptBridge.eval("String(localStorage.getItem('md.session') || '')", true)
	if typeof(raw) != TYPE_STRING or str(raw) == "":
		return {}
	var parsed = JSON.parse_string(str(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if str(parsed.get("token", "")) == "" or str(parsed.get("match_id", "")) == "":
		return {}
	return parsed


func _offer_saved_session() -> void:
	var saved := _saved_session()
	if saved.is_empty():
		return
	_restore.visible = true
	if _join_code.text.strip_edges() != "":
		_link_banner.text = "This browser still has a seat. It restores when the invitation matches that room."
		return
	_link_banner.text = "Restoring this browser's seat. The session token stays in local storage."
	_restore_saved_session()


func _restore_saved_session() -> void:
	if not OS.has_feature("web"):
		return
	var raw: Variant = JavaScriptBridge.eval("String(localStorage.getItem('md.session') || '')", true)
	if typeof(raw) != TYPE_STRING:
		return
	var parsed = JSON.parse_string(str(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_match_id = str(parsed.get("match_id", ""))
	_token = str(parsed.get("token", ""))
	_dismissed_event = str(parsed.get("dismissed_event", ""))
	var server := str(parsed.get("server", "")).strip_edges()
	if server.begins_with("https://") or server.begins_with("http://"):
		_server.text = server
	_base = _server.text.strip_edges()
	_join_match.text = _match_id
	_restore.visible = false
	_reconnect()


func _remember_session() -> void:
	if not OS.has_feature("web") or _token == "" or _match_id == "":
		return
	var payload := JSON.stringify({
		"match_id": _match_id,
		"token": _token,
		"server": _server.text.strip_edges(),
		"dismissed_event": _dismissed_event,
	})
	JavaScriptBridge.eval("localStorage.setItem('md.session', %s)" % JSON.stringify(payload), true)


func _reconnect() -> void:
	_error_layer.visible = false
	if _token == "":
		_show_problem("No session", "Create or join a room before reconnecting.", false)
		return
	_send("reconnect", {})
	_connect_socket()


func _show_problem(title: String, body: String, reconnecting: bool) -> void:
	_error_title.text = title
	_error_body.text = body
	_error_layer.visible = true
	_error_layer.move_to_front()
	if reconnecting:
		_link_banner.text = body


func _error_heading(code: String) -> String:
	match code:
		"out_of_turn":
			return "Not your turn"
		"stale_version":
			return "The table moved"
		"unauthorized":
			return "This session cannot enter that room"
		"duplicate_action":
			return "Duplicate action"
		"illegal_tile", "insufficient_cash", "insufficient_inventory", "wrong_phase":
			return "Invalid action"
		"rate_limited":
			return "Too many requests"
		_:
			return "Server error"


func _dismiss_event() -> void:
	_dismissed_event = _event_copy.text
	_event_layer.visible = false
	_remember_session()


func _choice_layer(title: String) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(PRESET_FULL_RECT)
	layer.visible = false
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.12, 0.72)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(minf(460, get_viewport_rect().size.x - 24), 0)
	card.add_theme_stylebox_override("panel", Palette.flat(CARD, Color("243044"), 1, 8))
	center.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var heading := _note(title)
	heading.add_theme_color_override("font_color", TEXT)
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	var copy := _note("")
	copy.custom_minimum_size = Vector2(0, 0)
	copy.add_theme_color_override("font_color", TEXT)
	box.add_child(copy)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	return layer


func _layer_label(layer: Control, index: int) -> Label:
	return _layer_box_parent(layer).get_child(index) as Label


func _layer_box(layer: Control, index: int) -> VBoxContainer:
	return _layer_box_parent(layer).get_child(index) as VBoxContainer


func _layer_box_parent(layer: Control) -> VBoxContainer:
	var center := layer.get_child(1) as CenterContainer
	var card := center.get_child(0) as PanelContainer
	var margin := card.get_child(0) as MarginContainer
	return margin.get_child(0) as VBoxContainer


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var owner := get_viewport().gui_get_focus_owner()
	if owner is LineEdit or owner is TextEdit:
		return
	if key.keycode == KEY_ESCAPE:
		_rules.hide_panel()
		_confirm_layer.visible = false
		if _event_layer.visible:
			_dismiss_event()
		_error_layer.visible = false
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_R and _rules != null:
		_rules.show_panel()
		get_viewport().set_input_as_handled()


func _choose_cell(coordinate: String) -> void:
	_selected = coordinate
	if _step == "place":
		_send("place_tile", {"coordinate": coordinate})


func _close() -> void:
	visible = false
	closed_panel.emit()


func _next_action() -> String:
	_seq += 1
	return "a%s_%d" % [_action_nonce, _seq]


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 44)
	var fill := Color("243044")
	var hover := fill if Palette.reduced_motion else fill.lightened(0.08)
	button.add_theme_stylebox_override("normal", Palette.flat(fill, fill, 1, 6))
	button.add_theme_stylebox_override("hover", Palette.flat(hover, TEAL, 1, 6))
	button.add_theme_stylebox_override("pressed", Palette.flat(fill.darkened(0.08), TEAL, 1, 6))
	button.add_theme_stylebox_override("disabled", Palette.flat(Color("121826"), Color("243044"), 1, 6))
	button.add_theme_stylebox_override("focus", Palette.flat(fill, AMBER, 2, 6))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_focus_color", TEXT)
	Palette.remember(button, 14)
	button.pressed.connect(callback)
	return button


func _field(value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(180, 44)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return edit


func _labeled(caption: String, edit: LineEdit) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _note(caption)
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	row.add_child(edit)
	return row


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED)
	return label
