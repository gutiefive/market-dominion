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

var _base := "http://127.0.0.1:8741"
var _match_id := ""
var _token := ""
var _you := ""
var _version := 0
var _seq := 0
var _host := false
var _step := "lobby"
var _hand: Array = []
var _pending: Array = []
var _selected := ""
var _socket := RoomSocket.new()
var _http: HTTPRequest
var _status: Label
var _error: Label
var _invite: Label
var _lobby: VBoxContainer
var _play: VBoxContainer
var _board: BoardGrid
var _hand_row: HBoxContainer
var _actions: HBoxContainer
var _lobby_actions: HBoxContainer
var _side: RichTextLabel
var _nickname: LineEdit
var _join_match: LineEdit
var _join_code: LineEdit
var _server: LineEdit


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_socket.message_received.connect(_on_socket)
	_socket.closed.connect(_on_socket_closed)
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http)
	_build()


func _process(_delta: float) -> void:
	_socket.poll()


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
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Online room"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("Back to local", _close))
	_status = _note("")
	_error = _note("")
	_error.add_theme_color_override("font_color", DANGER)
	root.add_child(_status)
	root.add_child(_error)
	_lobby = VBoxContainer.new()
	_lobby.add_theme_constant_override("separation", 8)
	root.add_child(_lobby)
	_server = _field("http://127.0.0.1:8741")
	_nickname = _field("Rowan")
	_join_match = _field("")
	_join_code = _field("")
	_lobby.add_child(_labeled("Server", _server))
	_lobby.add_child(_labeled("Nickname", _nickname))
	_lobby.add_child(_button("Create private room", _create_room))
	_lobby.add_child(_labeled("Match id", _join_match))
	_lobby.add_child(_labeled("Invite code", _join_code))
	_lobby.add_child(_button("Join with invite", _join_room))
	_invite = _note("The server deals the tiles. This screen never shuffles them.")
	_lobby.add_child(_invite)
	_lobby_actions = HBoxContainer.new()
	_lobby_actions.add_theme_constant_override("separation", 8)
	_lobby.add_child(_lobby_actions)
	_play = VBoxContainer.new()
	_play.visible = false
	_play.add_theme_constant_override("separation", 8)
	root.add_child(_play)
	_board = BoardGrid.new()
	_board.custom_minimum_size = Vector2(420, 420)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.add_child(_board)
	_board.cell_pressed.connect(_choose_cell)
	var hand_caption := _note("Your tiles")
	hand_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	hand_caption.add_theme_color_override("font_color", TEXT)
	_play.add_child(hand_caption)
	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 8)
	_play.add_child(_hand_row)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	_play.add_child(_actions)
	_side = RichTextLabel.new()
	_side.bbcode_enabled = true
	_side.fit_content = true
	_side.scroll_active = false
	_side.custom_minimum_size = Vector2(0, 180)
	_side.add_theme_color_override("default_color", TEXT)
	_play.add_child(_side)


func _create_room() -> void:
	_base = _server.text.strip_edges()
	_match_id = "room_%d" % int(Time.get_unix_time_from_system())
	_post(RoomCommands.envelope(_match_id, _next_action(), 0, "guesttoken", "create_room", {"nickname": _nickname.text.strip_edges()}))


func _join_room() -> void:
	_base = _server.text.strip_edges()
	_match_id = _join_match.text.strip_edges()
	_post(RoomCommands.envelope(
		_match_id, _next_action(), 0, "guesttoken", "join_room",
		{"invite_code": _join_code.text.strip_edges().to_upper(), "nickname": _nickname.text.strip_edges()}
	))


func _post(body: Dictionary) -> void:
	_error.text = ""
	var url := _base + "/v1/rooms/commands"
	_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))


func _on_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_error.text = "The server did not answer. Start it with ./scripts/dev.sh."
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_error.text = "The server returned %d." % code
		return
	var events: Array = parsed.get("events", [])
	if events.is_empty():
		_error.text = "The server returned no events."
		return
	var first: Dictionary = events[0]
	if str(first.get("event", "")) == "error":
		_error.text = str(first["payload"]["message"])
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
	_status.text = "Socket closed. Reconnecting with the same session."
	_connect_socket()


func _on_event(event: Dictionary) -> void:
	var name := str(event.get("event", ""))
	if name == "error":
		var payload: Dictionary = event["payload"]
		_error.text = str(payload.get("message", "rejected"))
		if str(payload.get("code", "")) == "stale_version":
			_send("request_snapshot", {})
		return
	if event.has("state_version"):
		_version = int(event["state_version"])
	if name == "room_updated":
		var info: Dictionary = event["payload"]
		if info.has("session_token"):
			_token = str(info["session_token"])
			_you = str(info.get("player_id", _you))
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
	_version = int(state["version"])
	var playing := str(state["phase"]) != "lobby"
	_lobby.visible = not playing
	_play.visible = playing
	if not playing:
		_status.text = "Lobby. Ready, then the host starts with 2–4 players."
		_show_lobby_actions(state)
		return
	var mine := str(state.get("active_player_id", "")) == _you and str(state["phase"]) != "completed"
	_status.text = "Version %d. %s" % [_version, "Your turn." if mine else "Waiting for the other seat."]
	if str(state["phase"]) == "completed":
		_status.text = "Match complete. Version %d." % _version
	var occupied := {}
	var companies := {}
	for cell in state["board"]:
		occupied[str(cell["coordinate"])] = bool(cell["occupied"])
		if cell["company_id"] != null:
			companies[str(cell["coordinate"])] = str(cell["company_id"])
	var legal: Array = _hand.duplicate() if mine and _step == "place" else []
	_board.set_state(occupied, companies, legal, _selected)
	_board.set_cell_size(36)
	_fill_hand(mine)
	_fill_actions(mine, state)
	_side.text = _side_text(state, mine)


func _show_lobby_actions(state: Dictionary) -> void:
	var names: PackedStringArray = []
	for player in state["players"]:
		var ready := "ready" if bool(player["is_ready"]) else "not ready"
		names.append("%s %s (%s)" % [str(player["display_name"]), str(player["id"]), ready])
	_invite.text = "Match %s    invite %s\n%s" % [_match_id, _join_code.text, "\n".join(names)]
	for child in _lobby_actions.get_children():
		child.queue_free()
	_lobby_actions.add_child(_button("Ready", func() -> void: _send("ready", {"is_ready": true})))
	if _you == "p1":
		_lobby_actions.add_child(_button("Start match", func() -> void: _send("start_match", {})))


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
		var command := "choose_founder" if _step == "choose_founder" else "choose_merger_survivor"
		for option in _pending:
			var corp := str(option)
			_actions.add_child(_button(corp, _trade.bind(command, corp)))
		return
	if _step != "market":
		return
	for corp in state["corporations"]:
		if not bool(corp["active"]):
			continue
		var corp_id := str(corp["id"])
		var corp_name := str(corp["name"])
		_actions.add_child(_button("Buy " + corp_name, _trade.bind("market_buy_share", corp_id)))
		_actions.add_child(_button("Sell " + corp_name, _trade.bind("market_sell_share", corp_id)))
	_actions.add_child(_button("Buy BYTE", func() -> void: _send("market_buy_byte", {})))
	_actions.add_child(_button("Sell BYTE", func() -> void: _send("market_sell_byte", {})))
	_actions.add_child(_button("Pass", func() -> void: _send("pass_market_action", {})))


func _place_hand(coordinate: String) -> void:
	_selected = coordinate
	_send("place_tile", {"coordinate": coordinate})


func _trade(command: String, corp_id: String) -> void:
	_send(command, {"corporation_id": corp_id})


func _send(command: String, payload: Dictionary) -> void:
	_error.text = ""
	_seq += 1
	var body := RoomCommands.envelope(_match_id, "a%d" % _seq, _version, _token, command, payload)
	if _socket.is_open():
		_socket.send_text(JSON.stringify(body))
		return
	_post(body)


func _side_text(state: Dictionary, mine: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("Phase %s    round %s    bag %d    you %s" % [
		str(state["phase"]), str(state["round_number"]), int(state["tile_bag_count"]), _you
	])
	var market: Dictionary = state["crypto_market"]
	lines.append("BYTE $%d    exchange %d" % [int(market["price"]), int(market["exchange_coin_count"])])
	var sentiment: Dictionary = state["sector_sentiment"]
	lines.append("AI %s  Fintech %s  Energy %s  Media %s  Retail %s" % [
		str(sentiment["ai"]), str(sentiment["fintech"]), str(sentiment["energy"]), str(sentiment["media"]), str(sentiment["retail"])
	])
	for corp in state["corporations"]:
		if bool(corp["active"]):
			lines.append("%s  $%d  size %d  bank %d" % [str(corp["name"]), int(corp["share_price"]), int(corp["size"]), int(corp["bank_shares"])])
	for player in state["players"]:
		var mark := "  your seat" if str(player["id"]) == _you else ""
		lines.append("%s  cash $%d  hand %d  BYTE %d%s" % [
			str(player["display_name"]), int(player["cash"]), int(player["hand_count"]), int(player["byte_count"]), mark
		])
	var log: Array = state["action_log"]
	var start := maxi(0, log.size() - 4)
	for index in range(start, log.size()):
		lines.append(str(log[index]["outcome"]))
	if not mine:
		lines.append("Your tiles stay on this session only.")
	return "\n".join(lines)


func _choose_cell(coordinate: String) -> void:
	_selected = coordinate
	if _step == "place":
		_send("place_tile", {"coordinate": coordinate})


func _close() -> void:
	visible = false
	closed_panel.emit()


func _next_action() -> String:
	_seq += 1
	return "a%d" % _seq


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func _field(value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(280, 36)
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
