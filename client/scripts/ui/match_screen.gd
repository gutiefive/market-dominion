extends Control
## Local table. Pass-and-play covers every hand. A solo table keeps one human
## and lets computers play their own seats. Online rooms are unchanged.

const BG := Color("0e1525")
const CARD := Color("162033")
const TEAL := Color("2dd4bf")
const AMBER := Color("fbbf24")
const TEXT := Color("e8eef9")
const MUTED := Color("93a0b8")
const DANGER := Color("f0a0a0")

var _match: OfflineMatch
var _selected := ""
var _hover := ""
var _concealed := false
var _wide := true

var _setup: VBoxContainer
var _order: VBoxContainer
var _order_list: Label
var _play: VBoxContainer
var _table: Container
var _column: VBoxContainer
var _board_card: PanelContainer
var _board: BoardGrid
var _hand_row: HBoxContainer
var _hand_note: Label
var _place_button: Button
var _action_row: Container
var _market_corp := "nova_ai"
var _banner: PanelContainer
var _banner_label: Label
var _status: Label
var _event_label: Label
var _score_card: PanelContainer
var _score_box: VBoxContainer
var _error: Label
var _online: OnlineTable
var _side: PanelContainer
var _feed: ActionFeed
var _standings: StandingsPanel
var _seen_ready := false
var _seen_cash: Dictionary = {}
var _seen_book: Dictionary = {}
var _seen_price: Dictionary = {}
var _seen_log := 0
var _scroll: ScrollContainer
var _merger_layer: Control
var _merger_copy: Label
var _merger_buttons: VBoxContainer
var _seed_input: LineEdit
var _name_inputs: Array[LineEdit] = []
var _seat_checks: Array[CheckBox] = []
var _vs_bots: CheckBox
var _difficulty_row: HBoxContainer
var _difficulty: OptionButton
var _setup_blurb: Label
var _order_help: Label
var _order_go: Button
var _cash_label: Label
var _net_label: Label
var _badge: Label
var _checklist: Label
var _preview: Label
var _watch: MarketWatch
var _rules: RulesPanel
var _founder_layer: Control
var _founder_copy: Label
var _founder_buttons: VBoxContainer
var _confirm_layer: Control
var _confirm_copy: Label
var _confirm_kind := ""
var _event_layer: Control
var _event_copy: Label
var _dismissed_event := ""
var _error_layer: Control
var _error_title: Label
var _error_body: Label
var _zoom_steps := 0
var _cell_px := 36
var _dock: PanelContainer
var _dock_title: Label
var _dock_detail: Label
var _step_row: HBoxContainer
var _finish_market: Button
var _computer_note := ""
var _subtitle: Label
var _feedback: TableFeedback
var _seats: SeatBar


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	if theme == null:
		theme = load("res://theme/market_theme.tres") as Theme
	if theme == null:
		theme = MarketTheme.build()
	Palette.load_settings()
	_feedback = get_node_or_null("Feedback") as TableFeedback
	if _feedback == null:
		_feedback = preload("res://scenes/components/table_feedback.tscn").instantiate() as TableFeedback
		add_child(_feedback)
	_build()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and str(args[0]) == "--shot":
		await _run_shot(str(args[1]), str(args[2]) if args.size() > 2 else "opening")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _play != null and _play.visible:
		_fit_board()


func _build() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_preset(PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_top = 8
	scroll.offset_right = -12
	scroll.offset_bottom = -8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	_merger_layer = _build_merger_modal()
	add_child(_merger_layer)
	_founder_layer = _build_choice_layer("Found a company")
	_founder_copy = _choice_copy(_founder_layer)
	_founder_buttons = _choice_buttons(_founder_layer)
	add_child(_founder_layer)
	_confirm_layer = _build_confirm_layer()
	add_child(_confirm_layer)
	_event_layer = _build_event_layer()
	add_child(_event_layer)
	_error_layer = _build_error_layer()
	add_child(_error_layer)
	_rules = RulesPanel.new()
	add_child(_rules)
	_standings = preload("res://scenes/components/standings_panel.tscn").instantiate() as StandingsPanel
	_standings.visible = false
	add_child(_standings)
	_standings.play_again_pressed.connect(_on_deal_pressed)
	_standings.lobby_pressed.connect(_show_setup)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label("Market Dominion", 22, TEXT))
	_subtitle = _label("Local pass-and-play, computers on this device, or a private room.", 13, MUTED)
	titles.add_child(_subtitle)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	header.add_child(tools)
	var smaller := _button("Text", false)
	smaller.tooltip_text = "Cycle text size. The bracket keys do the same."
	smaller.pressed.connect(_cycle_text)
	tools.add_child(smaller)
	var motion := _button("Motion", false)
	motion.tooltip_text = "Toggle reduced motion. The M key does the same."
	motion.pressed.connect(_toggle_motion)
	tools.add_child(motion)
	var rules_button := _button("Rules", false)
	rules_button.pressed.connect(func() -> void: _rules.show_panel())
	tools.add_child(rules_button)
	var fresh := _button("New table", false)
	fresh.pressed.connect(_show_setup)
	tools.add_child(fresh)

	_status = _label("", 14, MUTED)
	root.add_child(_status)
	_error = _label("", 14, DANGER)
	_error.visible = false
	root.add_child(_error)

	_setup = _build_setup()
	_order = _build_order()
	_play = _build_play()
	root.add_child(_setup)
	root.add_child(_order)
	root.add_child(_play)
	_build_dock()
	_online = OnlineTable.new()
	_online.visible = false
	_online.closed_panel.connect(_hide_online)
	add_child(_online)
	for layer in [_merger_layer, _founder_layer, _confirm_layer, _event_layer, _error_layer, _rules, _online]:
		layer.move_to_front()
	_show_setup()


func _build_setup() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	var card := _card()
	panel.add_child(card)
	var box := _box_of(card)
	box.add_child(_label("Open a table", 20, TEXT))
	_setup_blurb = _label(
		"Two to four seats. The seed shuffles turn order, then the 81-tile bag, then deals five private tiles to each seat. The same seed deals the same hands. Nothing is sent to a server.",
		14, MUTED
	)
	box.add_child(_setup_blurb)
	_vs_bots = CheckBox.new()
	_vs_bots.text = "One human versus computers"
	_vs_bots.button_pressed = false
	_vs_bots.accessibility_name = "Play alone against computers"
	_vs_bots.toggled.connect(func(_on: bool) -> void: _sync_seat_mode())
	box.add_child(_vs_bots)
	_difficulty_row = HBoxContainer.new()
	_difficulty_row.add_theme_constant_override("separation", 8)
	_difficulty_row.visible = false
	box.add_child(_difficulty_row)
	_difficulty_row.add_child(_label("Computer difficulty", 14, TEXT))
	_difficulty = OptionButton.new()
	_difficulty.add_item("Easy")
	_difficulty.add_item("Normal")
	_difficulty.add_item("Hard")
	_difficulty.selected = 1
	_difficulty.accessibility_name = "Computer difficulty"
	_difficulty.custom_minimum_size = Vector2(180, 36)
	_style_option(_difficulty)
	_difficulty_row.add_child(_difficulty)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	box.add_child(seed_row)
	seed_row.add_child(_label("Seed", 14, TEXT))
	_seed_input = LineEdit.new()
	_seed_input.text = "7710"
	_seed_input.custom_minimum_size = Vector2(160, 36)
	_seed_input.placeholder_text = "0 or greater"
	_seed_input.accessibility_name = "Match seed"
	seed_row.add_child(_seed_input)
	var defaults := ["Rowan", "Quinn", "Avery", "Blake"]
	for index in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var check := CheckBox.new()
		check.text = "Seat %d" % (index + 1)
		check.button_pressed = index < 2
		check.disabled = index < 2
		check.toggled.connect(func(_on: bool) -> void: _error.text = "")
		_seat_checks.append(check)
		row.add_child(check)
		var name_input := LineEdit.new()
		name_input.text = defaults[index]
		name_input.custom_minimum_size = Vector2(220, 36)
		name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_input.accessibility_name = "Seat %d name" % (index + 1)
		_name_inputs.append(name_input)
		row.add_child(name_input)
	var start := _button("Deal tiles", true)
	start.pressed.connect(_on_deal_pressed)
	box.add_child(start)
	var online := _button("Online room", false)
	online.pressed.connect(_show_online)
	box.add_child(online)
	return panel


func _build_order() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.visible = false
	panel.add_theme_constant_override("separation", 8)
	var card := _card()
	panel.add_child(card)
	var box := _box_of(card)
	box.add_child(_label("Turn order", 20, TEXT))
	_order_help = _label(
		"Seats were shuffled before the bag. Tiles stay covered until the first player takes the device.",
		14, MUTED
	)
	box.add_child(_order_help)
	_order_list = _label("", 16, TEXT)
	box.add_child(_order_list)
	_order_go = _button("Pass the device", true)
	_order_go.pressed.connect(_reveal)
	box.add_child(_order_go)
	return panel


func _build_play() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.visible = false
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)

	var seats := preload("res://scenes/components/seat_bar.tscn").instantiate() as SeatBar
	_seats = seats
	seats.grab()
	panel.add_child(seats)
	_badge = seats.badge
	_cash_label = seats.cash_label
	_net_label = seats.net_label

	_banner = _card()
	_banner.visible = false
	panel.add_child(_banner)
	var banner_box := _box_of(_banner)
	var banner_row := HBoxContainer.new()
	banner_row.add_theme_constant_override("separation", 12)
	banner_box.add_child(banner_row)
	_banner_label = _label("", 14, AMBER)
	_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_row.add_child(_banner_label)
	var continue_button := _button("Continue", true)
	continue_button.custom_minimum_size = Vector2(148, 36)
	continue_button.pressed.connect(_reveal)
	banner_row.add_child(continue_button)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_score_card = _card()
	_score_card.visible = false
	_column.add_child(_score_card)
	_score_box = _box_of(_score_card)

	_event_label = _label("", 14, AMBER)
	_event_label.visible = false
	_column.add_child(_event_label)

	_checklist = _label("", 13, TEXT)
	_checklist.visible = false

	var board_panel := preload("res://scenes/components/board_panel.tscn").instantiate() as BoardPanel
	board_panel.grab()
	_column.add_child(board_panel)
	_board_card = board_panel
	_preview = board_panel.preview
	_board = board_panel.grid
	_board.cell_pressed.connect(_on_cell_pressed)
	_board.cell_hovered.connect(_on_cell_hovered)
	board_panel.zoom_out_pressed.connect(func() -> void: _nudge_zoom(-1))
	board_panel.zoom_in_pressed.connect(func() -> void: _nudge_zoom(1))

	var prices := preload("res://scenes/components/price_panel.tscn").instantiate() as PricePanel
	prices.grab()
	_side = prices
	_watch = prices.watch
	_feed = prices.feed
	return panel


func _build_dock() -> void:
	var dock := preload("res://scenes/components/market_dock.tscn").instantiate() as MarketDock
	_dock = dock
	dock.grab()
	add_child(dock)
	dock.place_pressed.connect(_place_selected)
	dock.pass_market_pressed.connect(_finish_market_turn)
	_dock_title = dock.title_label
	_dock_detail = dock.detail_label
	_hand_note = dock.hand_note
	_step_row = dock.steps
	_hand_row = dock.hand
	_action_row = dock.actions
	_place_button = dock.place_button
	_finish_market = dock.finish_button


func _dock_style(fill: Color, accent: Color) -> StyleBoxFlat:
	var box := _box(fill, accent, 10)
	box.border_width_top = 2
	box.border_width_left = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, -2)
	return box


func _sync_dock() -> void:
	if _dock == null or _scroll == null:
		return
	var playing := _play != null and _play.visible
	_dock.visible = playing and not _online.visible
	var market_open := _dock.visible and _match != null and _match.phase == "market" and not _concealed and not _viewing_bot()
	var dock_h := 228.0 if market_open else 168.0
	_dock.offset_top = -dock_h if _dock.visible else 0.0
	_scroll.offset_bottom = -(dock_h + 8.0) if _dock.visible else -8.0
	if _action_row != null and _action_row.get_parent() is CanvasItem:
		(_action_row.get_parent() as CanvasItem).visible = market_open
	if _subtitle != null:
		_subtitle.visible = not playing
	if _dock.visible and _match != null:
		var accent := AMBER if market_open else TEAL
		_dock.add_theme_stylebox_override("panel", _dock_style(Color("1a2744"), accent))


func _paint_steps() -> void:
	if _step_row == null or _match == null:
		return
	for child in _step_row.get_children():
		child.queue_free()
	var place_on := _match.phase == "place"
	var resolve_on := _match.phase == "choose_founder" or _match.phase == "choose_survivor"
	var market_on := _match.phase == "market"
	_step_row.add_child(_step_pill("Place", place_on))
	_step_row.add_child(_step_pill("Resolve", resolve_on))
	_step_row.add_child(_step_pill("Market", market_on))


func _step_pill(text: String, on: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.theme_type_variation = "StepOn" if on else "StepOff"
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "StepOnText" if on else "StepOffText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(72, 0)
	pill.add_child(label)
	return pill


func _finish_market_turn() -> void:
	if _match == null or _match.phase != "market" or _concealed or _viewing_bot():
		return
	var last_log := ""
	var guard := 0
	while _match.phase == "market" and guard < 4:
		guard += 1
		var result := _match.pass_market()
		if not bool(result.get("ok", false)):
			_error.text = str(result.get("error", "The market could not be passed."))
			_refresh()
			return
		last_log = str(result.get("log", last_log))
	_error.text = ""
	if _match.phase == "place" or _match.phase == "completed":
		_conceal_for_next(last_log)
	else:
		_refresh()


func _show_online() -> void:
	_scroll.visible = false
	_online.visible = true
	_online.move_to_front()
	_sync_dock()


func _hide_online() -> void:
	_online.visible = false
	_scroll.visible = true
	_sync_dock()


func _show_setup() -> void:
	_match = null
	_selected = ""
	_concealed = false
	_setup.visible = true
	_order.visible = false
	_play.visible = false
	_error.text = ""
	_computer_note = ""
	_status.text = "No table open. The deal stays on this device."
	_status.visible = true
	_seen_ready = false
	if _standings != null:
		_standings.visible = false
	_sync_dock()
	if _merger_layer != null:
		_merger_layer.visible = false
	if _founder_layer != null:
		_founder_layer.visible = false
	if _confirm_layer != null:
		_confirm_layer.visible = false
	if _event_layer != null:
		_event_layer.visible = false
	if _error_layer != null:
		_error_layer.visible = false
	if _rules != null:
		_rules.visible = false
	_sync_error_line()


func _sync_error_line() -> void:
	if _error == null:
		return
	_error.visible = not _error.text.strip_edges().is_empty()


func _sync_seat_mode() -> void:
	_error.text = ""
	_sync_error_line()
	var solo := _vs_bots.button_pressed
	var human_names := ["Rowan", "Quinn", "Avery", "Blake"]
	var computer_names := ["Ada", "Bo", "Cy"]
	_difficulty_row.visible = solo
	if solo:
		_setup_blurb.text = "You play one seat. Add one, two, or three computers and pick Easy, Normal, or Hard. Easy looks one tile ahead. Normal and Hard look five. They take their own turns on this device. Your tiles stay private. Computer tiles stay hidden."
		_seat_checks[0].text = "You"
		_seat_checks[0].button_pressed = true
		_seat_checks[0].disabled = true
		_name_inputs[0].editable = true
		for index in range(1, 4):
			_seat_checks[index].text = "Computer"
			_seat_checks[index].disabled = index == 1
			_seat_checks[index].button_pressed = true if index == 1 else _seat_checks[index].button_pressed
			_name_inputs[index].text = computer_names[index - 1]
			_name_inputs[index].editable = false
	else:
		_setup_blurb.text = "Two to four seats. The seed shuffles turn order, then the 81-tile bag, then deals five private tiles to each seat. The same seed deals the same hands. Nothing is sent to a server."
		for index in range(4):
			_seat_checks[index].text = "Seat %d" % (index + 1)
			_seat_checks[index].disabled = index < 2
			_seat_checks[index].button_pressed = true if index < 2 else _seat_checks[index].button_pressed
			_name_inputs[index].editable = true
			if _name_inputs[index].text in computer_names or _name_inputs[index].text == "":
				_name_inputs[index].text = human_names[index]


func _on_deal_pressed() -> void:
	_error.text = ""
	if not _seed_input.text.is_valid_int():
		_error.text = "Enter a whole-number seed, zero or greater."
		_sync_error_line()
		return
	var seed := int(_seed_input.text)
	var names: Array[String] = []
	var bot_names: Array[String] = []
	for index in range(4):
		if index >= 2 and not _seat_checks[index].button_pressed:
			continue
		if index == 1 and _vs_bots.button_pressed and not _seat_checks[index].button_pressed:
			continue
		var nickname := _name_inputs[index].text.strip_edges()
		if nickname == "":
			_error.text = "Every included seat needs a display name."
			_sync_error_line()
			return
		names.append(nickname)
		if _vs_bots.button_pressed and index > 0:
			bot_names.append(nickname)
	if _vs_bots.button_pressed and bot_names.is_empty():
		_error.text = "Add at least one computer."
		_sync_error_line()
		return
	if _vs_bots.button_pressed:
		BotPolicy.set_difficulty(_selected_difficulty())
	else:
		BotPolicy.set_difficulty("normal")
	var created = OfflineMatch.create(seed, names, bot_names)
	if created == null:
		_error.text = "Use 2 to 4 unique names, 1–24 characters: letters, numbers, spaces, hyphens, or underscores. The seed must be zero or greater."
		_sync_error_line()
		return
	_begin_match(created)


func _begin_match(table: OfflineMatch) -> void:
	_match = table
	_selected = ""
	_seen_ready = false
	if _standings != null:
		_standings.visible = false
	_setup.visible = false
	_play.visible = false
	_order.visible = true
	_concealed = true
	var lines: PackedStringArray = []
	var solo := _solo()
	for index in range(_match.players.size()):
		var info: Dictionary = _match.players[index]
		var kind := "computer, %s, tiles hidden" % BotPolicy.difficulty_label() if bool(info.get("bot", false)) else "you, tiles face down" if solo else "five tiles face down"
		lines.append("%d. %s (%s) — %s" % [index + 1, str(info["display_name"]), str(info["id"]), kind])
	_order_list.text = "\n".join(lines)
	var first: Dictionary = _match.active_player()
	if solo:
		_order_help.text = "The seed shuffled the seats. Computers play at %s. Your hand is the only one shown." % BotPolicy.difficulty_label()
		if bool(first.get("bot", false)):
			_order_go.text = "Start — computers play first"
			_status.text = "Seed %d. %s plays first and will not show a hand." % [_match.seed, str(first["display_name"])]
		else:
			_order_go.text = "Look at your tiles"
			_status.text = "Seed %d. Your tiles stay on this device. Computers play when it is their turn." % _match.seed
	else:
		_order_help.text = "Seats were shuffled before the bag. Tiles stay covered until the first player takes the device."
		_order_go.text = "Pass the device"
		_status.text = "Seed %d. Bag holds %d tiles. Pass the device to %s before anyone looks at a hand." % [_match.seed, _match.bag.size(), str(first["display_name"])]
	_error.text = ""
	_sync_error_line()
	_sync_dock()


func _reveal() -> void:
	if _match == null:
		return
	_concealed = false
	_selected = ""
	_order.visible = false
	_play.visible = true
	if _solo() and _match.phase != "completed" and bool(_match.active_player().get("bot", false)):
		_run_bots()
		return
	_refresh()
	_fit_board()


func _solo() -> bool:
	if _match == null:
		return false
	for player in _match.players:
		if bool(player.get("bot", false)):
			return true
	return false


func _viewing_bot() -> bool:
	return _solo() and _match.phase != "completed" and bool(_match.active_player().get("bot", false))


func _run_bots() -> void:
	var before := 0 if _match == null else _match.log.size()
	var guard := 0
	while _match != null and _match.phase != "completed" and bool(_match.active_player().get("bot", false)) and guard < 48:
		guard += 1
		var result := BotPolicy.act(_match)
		if not bool(result.get("ok", false)):
			_error.text = str(result.get("error", "The computer could not move."))
			break
	if guard >= 48 and _match != null and bool(_match.active_player().get("bot", false)) and _match.phase != "completed":
		_error.text = "The computer turn did not finish."
	_computer_note = _recent_log(before)
	_concealed = false
	_selected = ""
	_order.visible = false
	_play.visible = true
	_refresh()
	_fit_board()


func _on_cell_pressed(coordinate: String) -> void:
	if _concealed or _match == null:
		return
	_selected = coordinate
	_place_selected()


func _place_selected() -> void:
	if _match == null or _concealed or _match.phase != "place":
		return
	var player := _match.active_player()
	var hand: Array = player["hand"]
	if hand.is_empty():
		_apply(_match.pass_turn())
		return
	if _selected == "":
		_error.text = "Select a tile in the active hand, or press its cell on the grid."
		_sync_error_line()
		return
	_apply(_match.place(_selected))
	_selected = ""


func _apply(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_error.text = str(result.get("error", "That action was rejected."))
		_refresh()
		return
	_error.text = ""
	var placed := str(result.get("placed", ""))
	if _feedback != null:
		if placed != "":
			_feedback.placed(placed, _board)
			if _match.phase == "market":
				_feedback.market_opened(_dock)
		elif _match.phase == "market":
			_feedback.ui_tick()
	if _match.phase == "place":
		_conceal_for_next(str(result["log"]))
	else:
		_refresh()


func _conceal_for_next(last_log: String) -> void:
	_selected = ""
	if _solo() and bool(_match.active_player().get("bot", false)):
		_run_bots()
		return
	if _solo():
		_concealed = false
		_order.visible = false
		_play.visible = true
		_refresh()
		return
	_concealed = true
	var nxt := str(_match.active_player()["display_name"])
	_banner_label.text = "Pass the device to %s. Their tiles stay covered. %s" % [nxt, last_log]
	_refresh()


func _refresh() -> void:
	_sync_error_line()
	if _match == null:
		return
	var player := _match.active_player()
	var hand: Array = player["hand"]
	var placing := _match.phase == "place" and not _concealed and not _viewing_bot()
	var legal: Array = hand.duplicate() if placing else []
	_board.set_state(_match.occupied, _match.company_of, legal, "" if not placing else _selected)
	_banner.visible = _concealed
	_rebuild_hand(hand)
	_rebuild_actions()
	var finished := _match.bag.is_empty() and _hands_empty() and _match.phase == "place"
	_place_button.visible = placing and _match.phase != "completed"
	if hand.is_empty():
		_place_button.text = "Skip placement"
	else:
		_place_button.text = "Place selected"
	var market_open := _match.phase == "market" and not _concealed and not _viewing_bot()
	if _match.phase == "completed":
		_status.text = _winner_line()
	elif _viewing_bot():
		_status.text = "%s is a computer (%s). The tiles stay hidden while that seat plays." % [str(player["display_name"]), BotPolicy.difficulty_label()]
	elif _concealed:
		_status.text = "Hand covered. Prices stay visible. The next player continues when they have the device."
	elif _match.phase == "choose_founder":
		_status.text = "%s chooses a company for the new cluster. The founder receives one share if the bank has one." % str(player["display_name"])
	elif _match.phase == "choose_survivor":
		_status.text = "%s chooses which tied company survives. The others are bought out at the prices shown." % str(player["display_name"])
	elif market_open:
		_status.text = "Tile placed. %d market action%s left — trade, or pass the market to end the turn." % [
			_match.market_actions_left, "" if _match.market_actions_left == 1 else "s"
		]
	elif hand.is_empty():
		_status.text = "%s has no tile to place. Skip placement, then take up to two market actions." % str(player["display_name"])
	else:
		if _solo():
			_status.text = "Your turn, %s. Place one tile. The market opens after the tile, and computers play after you pass." % str(player["display_name"])
		else:
			_status.text = "%s places one tile. A chain of two or more can found a company. Connecting two companies merges them." % str(player["display_name"])
	if finished and _match.phase != "completed":
		_status.text = "No tiles remain. Market actions are still available on an empty hand."
	if _match.final_round and _match.phase != "completed":
		_status.text = "Final round. " + _status.text
	_fill_chrome(player)
	_fill_watch(player)
	_show_feed()
	_sync_change_feedback()
	_show_standings()
	_refresh_event()
	_refresh_score()
	_sync_merger_modal()
	_sync_founder_modal()
	_sync_error()
	if _match.phase != "market":
		_confirm_layer.visible = false
	if _viewing_bot():
		_hand_note.text = "%d hidden" % hand.size()
	elif _concealed:
		_hand_note.text = "Covered"
	elif _solo():
		_hand_note.text = "Your tiles · %d" % hand.size()
	else:
		_hand_note.text = "%d tile%s" % [hand.size(), "" if hand.size() == 1 else "s"]
	_fill_dock(player, market_open)
	_status.visible = false
	_sync_landing_preview()
	_sync_dock()
	if _play.visible:
		_fit_board()


func _fill_dock(player: Dictionary, market_open: bool) -> void:
	if _dock_title == null:
		return
	_paint_steps()
	_place_button.visible = _match.phase == "place" and not _concealed and not _viewing_bot() and _match.phase != "completed"
	_finish_market.visible = market_open
	if _match.phase == "completed":
		_dock_title.text = "Match over"
		_dock_detail.text = _winner_line()
	elif _viewing_bot():
		_dock_title.text = "%s is playing" % str(player["display_name"])
		_dock_detail.text = "Computer, %s. This seat does not use the device." % BotPolicy.difficulty_label()
	elif _concealed:
		_dock_title.text = "Pass the device"
		_dock_detail.text = "Tiles stay covered until the next player continues."
	elif _match.phase == "choose_founder":
		_dock_title.text = "Name the company"
		_dock_detail.text = "The cluster is on the board. Pick a brand in the dialog."
	elif _match.phase == "choose_survivor":
		_dock_title.text = "Choose the survivor"
		_dock_detail.text = "Two companies tied. The dialog lists the buyout."
	elif market_open:
		_dock_title.text = "Your tile is on the board"
		var follow := "Computers play after you pass." if _solo() else "The next player takes the device after you pass."
		_dock_detail.text = "%d trade%s left. Buy or sell, or pass the market. %s" % [
			_match.market_actions_left, "" if _match.market_actions_left == 1 else "s", follow
		]
	elif (player["hand"] as Array).is_empty():
		_dock_title.text = "No tile to place"
		_dock_detail.text = "Skip placement. The market still opens."
	else:
		_dock_title.text = "Place one tile"
		if _computer_note != "":
			_dock_detail.text = _computer_note
		elif _solo():
			_dock_detail.text = "Click a tile or its district. The market opens next, before anyone else plays."
		else:
			_dock_detail.text = "Click a tile or its district. A chain of two can found a company."
	_dock_detail.tooltip_text = _dock_detail.text


func _recent_log(start: int) -> String:
	if _match == null:
		return ""
	var placed := PackedStringArray()
	for index in range(start, _match.log.size()):
		var line := str(_match.log[index])
		if " placed " in line or " founded " in line or " grew " in line or " merger " in line:
			placed.append(line)
	if not placed.is_empty():
		return " ".join(placed)
	var parts: PackedStringArray = []
	var from := start
	if _match.log.size() - from > 2:
		from = _match.log.size() - 2
	for index in range(from, _match.log.size()):
		parts.append(str(_match.log[index]))
	return " ".join(parts)


func _hands_empty() -> bool:
	for player in _match.players:
		if not (player["hand"] as Array).is_empty():
			return false
	return true


func _rebuild_hand(hand: Array) -> void:
	for child in _hand_row.get_children():
		child.queue_free()
	if _match.phase == "completed":
		_hand_row.add_child(_label("The match is over. Standings show cash, portfolio, and net.", 14, MUTED))
		return
	if _viewing_bot():
		_hand_row.add_child(_label("%s is a computer (%s). %d tiles stay hidden. This seat does not use the device." % [str(_match.active_player()["display_name"]), BotPolicy.difficulty_label(), hand.size()], 14, MUTED))
		return
	if _concealed:
		_hand_row.add_child(_label("Tiles stay face down until this player continues.", 14, MUTED))
		return
	if hand.is_empty():
		var empty := _button("No tile left — end turn", true)
		empty.pressed.connect(_place_selected)
		_hand_row.add_child(empty)
		return
	for coordinate in hand:
		var chosen := str(coordinate) == _selected
		var tile := preload("res://scenes/components/tile_chip.tscn").instantiate() as TileChip
		tile.setup(str(coordinate), chosen)
		tile.chosen.connect(_select_tile)
		_hand_row.add_child(tile)


func _select_tile(coordinate: String) -> void:
	_selected = "" if _selected == coordinate else coordinate
	_error.text = ""
	_refresh()


func _rebuild_actions() -> void:
	if _action_row == null:
		return
	for child in _action_row.get_children():
		child.queue_free()
	if _concealed or _viewing_bot() or _match == null or _match.phase == "completed":
		return
	if _match.phase == "choose_founder" or _match.phase == "choose_survivor":
		_action_row.add_child(_label("Choose in the dialog. Esc does not cancel a required choice.", 13, MUTED))
		return
	if _match.phase != "market":
		return
	var active_ids: Array[String] = []
	for corp in _match.corporations:
		if bool(corp["active"]):
			active_ids.append(str(corp["id"]))
	if not active_ids.is_empty() and not active_ids.has(_market_corp):
		_market_corp = active_ids[0]
	for corp_id in active_ids:
		var picked := corp_id == _market_corp
		var choice := _button(str(BoardGrid.MARKS.get(corp_id, corp_id)), picked)
		choice.pressed.connect(_select_corp.bind(corp_id))
		_action_row.add_child(choice)
	if not active_ids.is_empty():
		var buy := _button("Buy share", true)
		buy.pressed.connect(func() -> void: _open_confirm("buy_share"))
		var sell := _button("Sell share", false)
		sell.pressed.connect(func() -> void: _open_confirm("sell_share"))
		_action_row.add_child(buy)
		_action_row.add_child(sell)
	var buy_byte := _button("Buy BYTE", true)
	buy_byte.pressed.connect(func() -> void: _open_confirm("buy_byte"))
	var sell_byte := _button("Sell BYTE", false)
	sell_byte.pressed.connect(func() -> void: _open_confirm("sell_byte"))
	var pass_action := _button("Pass one", false)
	pass_action.pressed.connect(func() -> void: _open_confirm("pass"))
	_action_row.add_child(buy_byte)
	_action_row.add_child(sell_byte)
	_action_row.add_child(pass_action)


func _choose_brand(corp_id: String) -> void:
	if _match == null:
		return
	_apply(_match.choose_founder(corp_id))


func _select_corp(corp_id: String) -> void:
	_market_corp = corp_id
	_refresh()


func _buy_share() -> void:
	if _match != null:
		_apply(_match.buy_share(_market_corp))


func _sell_share() -> void:
	if _match != null:
		_apply(_match.sell_share(_market_corp))


func _buy_byte() -> void:
	if _match != null:
		_apply(_match.buy_byte())


func _sell_byte() -> void:
	if _match != null:
		_apply(_match.sell_byte())


func _pass_market() -> void:
	if _match != null:
		_apply(_match.pass_market())


func _show_feed() -> void:
	if _feed == null or _match == null:
		return
	var events := PackedStringArray()
	var start := maxi(0, _match.log.size() - 4)
	for index in range(_match.log.size() - 1, start - 1, -1):
		events.append(ActionFeed.shorten(str(_match.log[index])))
	var round_note := "final" if _match.final_round else str(_match.round_number)
	_feed.show_events(events, "Round %s · bag %d · seed %d" % [round_note, _match.bag.size(), _match.seed])


func _sync_change_feedback() -> void:
	if _match == null:
		return
	var prices := _price_snapshot()
	var round_hit := false
	if _seen_ready:
		for index in range(_seen_log, _match.log.size()):
			var line := str(_match.log[index])
			if line.begins_with("Round event:"):
				round_hit = true
			for mark in _marks_in_line(line):
				if _watch != null:
					_watch.flash(mark)
		for player in _match.players:
			var seat_id := str(player["id"])
			var cash := int(player["cash"])
			var book := _book_line(player)
			var changed := int(_seen_cash.get(seat_id, cash)) != cash or str(_seen_book.get(seat_id, book)) != book
			if (changed or round_hit) and _seats != null:
				_seats.pulse(str(player["display_name"]))
		for mark in prices.keys():
			var before := int(_seen_price[mark]) if _seen_price.has(mark) else -1
			if before != int(prices[mark]) and _watch != null:
				_watch.flash(mark)
	_seen_cash.clear()
	_seen_book.clear()
	_seen_price = prices
	for player in _match.players:
		var seat_id := str(player["id"])
		_seen_cash[seat_id] = int(player["cash"])
		_seen_book[seat_id] = _book_line(player)
	_seen_log = _match.log.size()
	_seen_ready = true


func _price_snapshot() -> Dictionary:
	var prices := {"BYTE": _match.byte_price}
	for corp in _match.corporations:
		prices[str(BoardGrid.MARKS.get(corp["id"], ""))] = int(corp["share_price"])
	return prices


func _marks_in_line(line: String) -> PackedStringArray:
	var marks := PackedStringArray()
	var trade := " bought " in line or " sold " in line or " grew " in line or " founded " in line
	if not trade:
		return marks
	if " BYTE " in line:
		marks.append("BYTE")
	for corp_id in BoardGrid.NAMES.keys():
		if str(BoardGrid.NAMES[corp_id]) in line:
			marks.append(str(BoardGrid.MARKS[corp_id]))
	return marks


func _show_standings() -> void:
	if _standings == null or _match == null:
		return
	var open := _match.phase == "completed" and not _match.ranking.is_empty()
	_standings.visible = open
	if not open:
		return
	var rows: Array = []
	var rank := 1
	for player_id in _match.ranking:
		var row := _ledger_row(str(player_id))
		if row.is_empty():
			continue
		var book_bits: PackedStringArray = []
		for holding in row["holdings"]:
			book_bits.append("%s %d × $%d" % [str(holding["name"]), int(holding["count"]), int(holding["price"])])
		if int(row["byte_count"]) > 0:
			book_bits.append("BYTE %d × $%d" % [int(row["byte_count"]), _match.byte_price])
		rows.append({
			"rank": rank,
			"name": str(row["display_name"]),
			"role": _standing_role(str(row["id"])),
			"cash": int(row["cash"]),
			"portfolio": int(row["share_value"]) + int(row["byte_value"]),
			"net": int(row["net_worth"]),
			"book": " · ".join(book_bits),
		})
		rank += 1
	_standings.present(_winner_line(), rows)
	_standings.move_to_front()


func _standing_role(player_id: String) -> String:
	for player in _match.players:
		if str(player["id"]) != player_id:
			continue
		if bool(player.get("bot", false)):
			return "computer · %s" % BotPolicy.difficulty_label()
		if _solo():
			return "you"
		return "player"
	return "player"


func _activity_bbcode() -> String:
	var lines: PackedStringArray = []
	var round_note := "final" if _match.final_round else str(_match.round_number)
	lines.append("[color=#93a0b8]Round[/color] %s   [color=#93a0b8]Bag[/color] %d   [color=#93a0b8]Seed[/color] %d" % [
		round_note, _match.bag.size(), _match.seed
	])
	if _match.log.is_empty():
		lines.append("[color=#93a0b8]No actions yet.[/color]")
	else:
		var start := maxi(0, _match.log.size() - 4)
		for index in range(start, _match.log.size()):
			lines.append(str(_match.log[index]))
	return "\n".join(lines)


func _fill_chrome(player: Dictionary) -> void:
	var covered := " · hand covered" if _concealed else ""
	var turn := " · playing" if _match.phase != "completed" else " · finished"
	var role := ""
	if bool(player.get("bot", false)):
		role = " · computer · %s" % BotPolicy.difficulty_label()
	elif _solo():
		role = " · you"
	_badge.text = "%s  %s%s%s%s" % [str(player["display_name"]), str(player["id"]), role, turn, covered]
	_cash_label.text = "Cash $%d" % int(player["cash"])
	_net_label.text = "Net $%d" % _player_net(player)
	var place_mark := "Now" if _match.phase == "place" else "Done" if _match.phase != "choose_founder" and _match.phase != "choose_survivor" else "Wait"
	var resolve_mark := "Now" if _match.phase == "choose_founder" or _match.phase == "choose_survivor" else "After place"
	var market_mark := "Now %d left" % _match.market_actions_left if _match.phase == "market" else "Up to 2"
	_checklist.text = "1 %s place   ·   2 %s resolve   ·   3 %s market" % [place_mark, resolve_mark, market_mark]
	if _seats == null:
		return
	var tone := _turn_tone()
	_apply_turn_banner(player, tone)
	var active_id := str(player["id"])
	var rows: Array = []
	var acting_row: Dictionary = {}
	for other in _match.players:
		var acting := str(other["id"]) == active_id and _match.phase != "completed"
		var row := {
			"name": str(other["display_name"]),
			"meta": _seat_meta(other, acting),
			"cash": "$%d" % int(other["cash"]),
			"book": _book_line(other),
			"acting": acting,
			"tone": tone,
		}
		if acting:
			acting_row = row
		else:
			rows.append(row)
	if not acting_row.is_empty():
		rows.push_front(acting_row)
	_seats.show_opponents(rows)


func _turn_tone() -> String:
	if _match.phase == "completed":
		return "over"
	if _concealed or _viewing_bot():
		return "wait"
	if _match.phase == "market":
		return "market"
	if _match.phase == "choose_founder" or _match.phase == "choose_survivor":
		return "resolve"
	return "place"


func _apply_turn_banner(player: Dictionary, tone: String) -> void:
	var step := "PLACE"
	var who := ""
	var detail := ""
	var seat_name := str(player["display_name"])
	match tone:
		"over":
			step = "OVER"
			who = "Match over"
			detail = _winner_line()
		"wait":
			step = "WAITING"
			if _viewing_bot():
				who = "%s is playing" % seat_name
				detail = "Computer, %s. This seat does not use the device." % BotPolicy.difficulty_label()
			else:
				who = "Pass the device to %s" % seat_name
				detail = "Tiles stay covered until they continue."
		"resolve":
			step = "RESOLVE"
			if _match.phase == "choose_founder":
				who = "%s names the company" % seat_name
				detail = "Pick a brand in the dialog."
			else:
				who = "%s chooses the survivor" % seat_name
				detail = "Two companies tied. Choose in the dialog."
		"market":
			step = "MARKET"
			if _solo() and not bool(player.get("bot", false)):
				who = "Your market · %s" % seat_name
			else:
				who = "%s trades" % seat_name
			if _solo():
				detail = "%d left. Pass before computers play." % _match.market_actions_left
			else:
				detail = "%d left. Then pass the device." % _match.market_actions_left
		_:
			step = "PLACE"
			if bool(player.get("bot", false)):
				who = "%s places" % seat_name
				detail = "Computer, %s." % BotPolicy.difficulty_label()
			elif _solo():
				who = "Your turn · %s" % seat_name
				detail = "Computers play after you pass."
			else:
				who = "%s places" % seat_name
				detail = "The market opens after the tile."
	if _match.final_round and tone != "over":
		detail = "Final round. " + detail
	_seats.show_turn(step, who, detail, tone)


func _seat_meta(seat: Dictionary, acting: bool) -> String:
	var kind := "seat"
	if bool(seat.get("bot", false)):
		kind = "computer · %s" % BotPolicy.difficulty_label()
	elif _solo():
		kind = "you"
	else:
		kind = "player"
	var tiles := (seat["hand"] as Array).size()
	var tile_word := "1 tile" if tiles == 1 else "%d tiles" % tiles
	if acting and _concealed:
		return "%s · hand covered" % kind
	if acting:
		return "%s · acting · %s" % [kind, tile_word]
	return "%s · %s" % [kind, tile_word]


func _book_line(seat: Dictionary) -> String:
	var shares: Dictionary = seat["shares"]
	var parts: PackedStringArray = []
	for corp in _match.corporations:
		parts.append("%s %d" % [str(BoardGrid.MARKS.get(corp["id"], "")), int(shares.get(corp["id"], 0))])
	parts.append("BYTE %d" % int(seat["byte_count"]))
	return " · ".join(parts)


func _fill_watch(player: Dictionary) -> void:
	var shares: Dictionary = player["shares"]
	var rows: Array = []
	rows.append({
		"active": true,
		"symbol": "¤",
		"mark": "BYTE",
		"name": "BYTE coin",
		"detail": "$%d   exchange %d   you %d" % [_match.byte_price, _match.byte_exchange, int(player["byte_count"])],
	})
	for corp in _match.corporations:
		var sector := str(corp["sector"])
		var sentiment := int(_match.sentiment.get(sector, 0))
		var shown := "+%d" % sentiment if sentiment > 0 else str(sentiment)
		rows.append({
			"active": bool(corp["active"]),
			"symbol": str(BoardGrid.SYMBOLS.get(corp["id"], "")),
			"mark": str(BoardGrid.MARKS.get(corp["id"], "")),
			"name": str(corp["name"]),
			"price": int(corp["share_price"]),
			"sentiment": "%s %s" % [sector, shown],
			"size": int(corp["size"]),
			"bank": int(corp["bank_shares"]),
			"yours": int(shares.get(corp["id"], 0)),
		})
	_watch.show_rows(rows)


func _on_cell_hovered(coordinate: String) -> void:
	_hover = coordinate
	if _board != null:
		_board.set_hover(coordinate)
	_sync_landing_preview()


func _sync_landing_preview() -> void:
	if _preview == null:
		return
	var coordinate := _hover if _hover != "" else _selected
	if coordinate == "" or _match == null or _board == null or not _play.visible:
		_preview.text = "Hover a district. A tile in your hand shows where it will land."
		_preview.add_theme_color_override("font_color", MUTED)
		return
	var occupied := bool(_match.occupied.get(coordinate, false))
	var corp_id := str(_match.company_of.get(coordinate, ""))
	var legal := _board._legal.has(coordinate)
	var from_hand := _hover == "" and _selected == coordinate
	if legal and not occupied:
		var lead := "Selected %s." % coordinate if from_hand else "Lands on %s." % coordinate
		_preview.text = "%s Empty district — your tile will sit here." % lead
		_preview.add_theme_color_override("font_color", AMBER)
	elif corp_id != "":
		_preview.text = "%s is %s %s (%s)." % [
			coordinate,
			str(BoardGrid.SYMBOLS.get(corp_id, "")),
			str(BoardGrid.NAMES.get(corp_id, corp_id)),
			str(BoardGrid.MARKS.get(corp_id, "")),
		]
		_preview.add_theme_color_override("font_color", TEXT)
	elif occupied:
		_preview.text = "%s is taken. The district is unincorporated." % coordinate
		_preview.add_theme_color_override("font_color", TEXT)
	else:
		_preview.text = "%s is empty. It is not in the active hand." % coordinate
		_preview.add_theme_color_override("font_color", MUTED)
	_preview.tooltip_text = _preview.text


func _cycle_text() -> void:
	Palette.cycle_scale()
	Palette.restyle(self)
	_fit_board()


func _toggle_motion() -> void:
	Palette.toggle_motion()
	_status.text = "Reduced motion is on. Hover no longer brightens." if Palette.reduced_motion else "Motion is on. Hover brightens a cell."
	if _match != null:
		_refresh()


func _nudge_zoom(step: int) -> void:
	_zoom_steps = clampi(_zoom_steps + step, 0, 3)
	_fit_board()
	_preview.text = "Zoom step %d. Scroll the page to pan when the grid is larger than the window." % _zoom_steps


func _open_confirm(kind: String) -> void:
	if _match == null or _match.phase != "market":
		return
	_confirm_kind = kind
	var corp_name := _corp_name(_market_corp)
	var price := 0
	for corp in _match.corporations:
		if str(corp["id"]) == _market_corp:
			price = int(corp["share_price"])
	var cash := int(_match.active_player()["cash"])
	match kind:
		"buy_share":
			_confirm_copy.text = "Buy 1 %s at the posted $%d? Cash is $%d. This does not change the price." % [corp_name, price, cash]
		"sell_share":
			_confirm_copy.text = "Sell 1 %s at the posted $%d? Cash is $%d." % [corp_name, price, cash]
		"buy_byte":
			_confirm_copy.text = "Buy 1 BYTE at the posted $%d? Cash is $%d. The exchange holds %d." % [_match.byte_price, cash, _match.byte_exchange]
		"sell_byte":
			_confirm_copy.text = "Sell 1 BYTE at the posted $%d? Cash is $%d." % [_match.byte_price, cash]
		"pass":
			_confirm_copy.text = "Pass this market action? %d remain after this pass, counting the one you are skipping." % _match.market_actions_left
	_confirm_layer.visible = true
	_confirm_layer.move_to_front()


func _apply_confirm() -> void:
	_confirm_layer.visible = false
	var kind := _confirm_kind
	_confirm_kind = ""
	if _match == null:
		return
	match kind:
		"buy_share":
			_apply(_match.buy_share(_market_corp))
		"sell_share":
			_apply(_match.sell_share(_market_corp))
		"buy_byte":
			_apply(_match.buy_byte())
		"sell_byte":
			_apply(_match.sell_byte())
		"pass":
			_apply(_match.pass_market())


func _corp_name(corp_id: String) -> String:
	for corp in _match.corporations:
		if str(corp["id"]) == corp_id:
			return str(corp["name"])
	return corp_id


func _sync_error() -> void:
	var message := _error.text.strip_edges()
	_error_layer.visible = message != ""
	_error_body.text = message
	if message != "":
		_error_title.text = "Action not applied"
		_error_layer.move_to_front()


func _dismiss_error() -> void:
	_error.text = ""
	_sync_error_line()
	_error_layer.visible = false


func _sentiment_line() -> String:
	var labels := {"ai": "AI", "fintech": "Fintech", "energy": "Energy", "media": "Media", "retail": "Retail"}
	var parts: PackedStringArray = []
	for sector in ["ai", "fintech", "energy", "media", "retail"]:
		var value := int(_match.sentiment[sector])
		var shown := "+%d" % value if value > 0 else str(value)
		parts.append("%s %s" % [str(labels[sector]), shown])
	return "[color=#93a0b8]Sentiment[/color]  %s" % " · ".join(parts)


func _player_net(player: Dictionary) -> int:
	var net := int(player["cash"]) + int(player["byte_count"]) * _match.byte_price
	var shares: Dictionary = player["shares"]
	for corp in _match.corporations:
		if bool(corp["active"]):
			net += int(shares[str(corp["id"])]) * int(corp["share_price"])
	return net


func _winner_line() -> String:
	if _match.ranking.is_empty():
		return "The match is over."
	for row in _match.ledger:
		if str(row["id"]) == str(_match.ranking[0]):
			return "%s wins with $%d fictional." % [str(row["display_name"]), int(row["net_worth"])]
	return "The match is over."


func _refresh_event() -> void:
	var latest := ""
	for line in _match.log:
		if str(line).begins_with("Round event:"):
			latest = str(line)
	var choosing := _match.phase == "choose_founder" or _match.phase == "choose_survivor"
	var show_overlay := latest != "" and latest != _dismissed_event and _match.phase != "completed" and not choosing
	_event_label.visible = false
	_event_layer.visible = show_overlay
	_event_copy.text = latest
	if show_overlay:
		_event_layer.move_to_front()


func _refresh_score() -> void:
	for child in _score_box.get_children():
		child.queue_free()
	_score_card.visible = false
	if _match.phase != "completed" or _match.ranking.is_empty():
		return
	_score_box.add_child(_label("Final ledger", 20, TEXT))
	var place_number := 1
	for player_id in _match.ranking:
		var row := _ledger_row(str(player_id))
		if row.is_empty():
			continue
		var color := TEAL if place_number == 1 else TEXT
		_score_box.add_child(_label(
			"%d. %s    $%d net" % [place_number, str(row["display_name"]), int(row["net_worth"])],
			16, color
		))
		_score_box.add_child(_label(
			"Cash $%d · active shares %d worth $%d · BYTE %d × $%d = $%d" % [
				int(row["cash"]), int(row["active_shares"]), int(row["share_value"]),
				int(row["byte_count"]), _match.byte_price, int(row["byte_value"])
			],
			14, MUTED
		))
		var holdings: Array = row["holdings"]
		if holdings.is_empty():
			_score_box.add_child(_label("No active shares.", 14, MUTED))
		for holding in holdings:
			_score_box.add_child(_label(
				"%s  %d × $%d = $%d" % [
					str(holding["name"]), int(holding["count"]), int(holding["price"]), int(holding["value"])
				],
				14, MUTED
			))
		place_number += 1


func _ledger_row(player_id: String) -> Dictionary:
	for row in _match.ledger:
		if str(row["id"]) == player_id:
			return row
	return {}


func _fit_board() -> void:
	if _board == null or not _play.visible:
		return
	var window := get_viewport_rect().size
	if window.x < 2.0 or window.y < 2.0:
		return
	var wide := window.x >= 980.0
	_ensure_table(wide)
	var side_reserve := 300.0 if wide else 0.0
	var board_width := window.x - 56.0 - side_reserve
	var cell_w := int((board_width - 27.0) / 10.0)
	var dock_h := 0.0
	if _dock != null and _dock.visible:
		dock_h = -_dock.offset_top + 16.0
	# Header, seat line, and the board card sit above the grid. The dock covers
	# the bottom of the window, so the grid has to finish above it.
	# Header, status, seat chips, and the board card's tool row. An empty error
	# line is hidden so it does not steal a row from the grid.
	var chrome := 270.0 if _banner.visible else 236.0
	var cell_h := int((window.y - dock_h - chrome) / 10.0)
	cell_h = clampi(cell_h, 24, 46)
	_cell_px = mini(maxi(cell_w, 24), cell_h) + _zoom_steps * 6
	if window.x < 720.0:
		_cell_px = maxi(_cell_px, 28)
	_board.set_cell_size(_cell_px)
	_sync_touch_targets(window.x < 720.0)
	call_deferred("_trim_board_to_viewport")


func _trim_board_to_viewport() -> void:
	if _scroll == null or _board == null or _play == null or not _play.visible:
		return
	var bar := _scroll.get_v_scroll_bar()
	var overflow := int(bar.max_value - bar.page)
	if overflow <= 1:
		_scroll.scroll_vertical = 0
		return
	var floor_px := 28 if get_viewport_rect().size.x < 720.0 else 24
	var next := _cell_px - int(ceil(float(overflow) / 9.0))
	next = clampi(next, floor_px, 58)
	if next >= _cell_px:
		return
	_cell_px = next
	_board.set_cell_size(next)
	_scroll.scroll_vertical = 0


func _sync_touch_targets(phone: bool) -> void:
	var height := 48.0 if phone else 40.0
	if _dock == null:
		return
	for node in _dock.find_children("*", "Button", true, false):
		if node is Button:
			(node as Button).custom_minimum_size.y = height


func _ensure_table(wide: bool) -> void:
	if _table != null and wide == _wide:
		return
	_wide = wide
	var index := 1
	if _table != null:
		index = _table.get_index()
		_table.remove_child(_column)
		_table.remove_child(_side)
		_play.remove_child(_table)
		_table.queue_free()
	var created: Container = (HBoxContainer.new() if wide else VBoxContainer.new()) as Container
	created.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	created.size_flags_vertical = Control.SIZE_EXPAND_FILL
	created.add_theme_constant_override("separation", 10)
	created.add_child(_column)
	created.add_child(_side)
	_play.add_child(created)
	_play.move_child(created, mini(index, _play.get_child_count() - 1))
	_table = created
	_side.custom_minimum_size = Vector2(260, 0) if wide else Vector2(0, 0)
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.size_flags_stretch_ratio = 0.75
	_column.size_flags_stretch_ratio = 1.7


func _build_merger_modal() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(PRESET_FULL_RECT)
	layer.visible = false
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.12, 0.62)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var card := _card()
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)
	var box := _box_of(card)
	box.add_child(_label("Choose the surviving company", 20, TEXT))
	_merger_copy = _label("", 14, MUTED)
	_merger_copy.custom_minimum_size = Vector2(420, 0)
	box.add_child(_merger_copy)
	_merger_buttons = VBoxContainer.new()
	_merger_buttons.add_theme_constant_override("separation", 8)
	box.add_child(_merger_buttons)
	return layer


func _sync_merger_modal() -> void:
	if _merger_layer == null:
		return
	var open := _match != null and _match.phase == "choose_survivor" and not _concealed
	_merger_layer.visible = open
	if not open:
		return
	for child in _merger_buttons.get_children():
		child.queue_free()
	var names: PackedStringArray = []
	for corp_id in _match.pending_options:
		for corp in _match.corporations:
			if str(corp["id"]) == str(corp_id):
				names.append(str(corp["name"]))
	_merger_copy.text = "%s. The company you keep absorbs every connected district. Each company you leave pays its shareholders from the price on the button, then every losing share is sold back to the bank." % " and ".join(names)
	for corp_id in _match.pending_options:
		for corp in _match.corporations:
			if str(corp["id"]) != str(corp_id):
				continue
			var mark := str(BoardGrid.MARKS.get(corp_id, ""))
			var symbol := str(BoardGrid.SYMBOLS.get(corp_id, ""))
			var choice := _button("%s  %s   %s     size %d     $%d" % [
				symbol, str(corp["name"]), mark, int(corp["size"]), int(corp["share_price"])
			], true)
			choice.pressed.connect(_choose_survivor.bind(str(corp_id)))
			_merger_buttons.add_child(choice)


func _choose_survivor(corp_id: String) -> void:
	if _match != null:
		_apply(_match.choose_survivor(corp_id))


func _sync_founder_modal() -> void:
	if _founder_layer == null:
		return
	var open := _match != null and _match.phase == "choose_founder" and not _concealed
	_founder_layer.visible = open
	if not open:
		return
	for child in _founder_buttons.get_children():
		child.queue_free()
	_founder_copy.text = "This cluster is not part of a company yet. Pick an inactive brand. You receive one share when that bank has a share left. The symbol on the button is the same mark used on the grid."
	for corp in _match.corporations:
		if bool(corp["active"]):
			continue
		var corp_id := str(corp["id"])
		var choice := _button("%s  %s  %s" % [
			str(BoardGrid.SYMBOLS.get(corp_id, "")),
			str(corp["name"]),
			str(BoardGrid.MARKS.get(corp_id, "")),
		], true)
		choice.pressed.connect(_choose_brand.bind(corp_id))
		_founder_buttons.add_child(choice)
	_founder_layer.move_to_front()


func _build_choice_layer(title: String) -> Control:
	var layer := _dim_layer()
	var box := _modal_box(layer)
	box.add_child(_label(title, 20, TEXT))
	var copy := _label("", 14, MUTED)
	copy.custom_minimum_size = Vector2(420, 0)
	box.add_child(copy)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	return layer


func _choice_copy(layer: Control) -> Label:
	return _modal_box(layer).get_child(1) as Label


func _choice_buttons(layer: Control) -> VBoxContainer:
	return _modal_box(layer).get_child(2) as VBoxContainer


func _build_confirm_layer() -> Control:
	var layer := _dim_layer()
	var box := _modal_box(layer)
	box.add_child(_label("Confirm market action", 20, TEXT))
	_confirm_copy = _label("", 14, TEXT)
	_confirm_copy.custom_minimum_size = Vector2(420, 0)
	box.add_child(_confirm_copy)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var yes := _button("Confirm", true)
	yes.pressed.connect(_apply_confirm)
	var no := _button("Cancel", false)
	no.pressed.connect(func() -> void: _confirm_layer.visible = false)
	row.add_child(yes)
	row.add_child(no)
	return layer


func _build_event_layer() -> Control:
	var layer := _dim_layer()
	var box := _modal_box(layer)
	box.add_child(_label("Round event", 20, AMBER))
	_event_copy = _label("", 15, TEXT)
	_event_copy.custom_minimum_size = Vector2(460, 0)
	box.add_child(_event_copy)
	box.add_child(_label("Prices moved because sector sentiment changed, or BYTE's posted price changed. Rules explains the formula. A trade does not do this.", 13, MUTED))
	var dismiss := _button("Continue", true)
	dismiss.pressed.connect(_dismiss_event)
	box.add_child(dismiss)
	return layer


func _dismiss_event() -> void:
	_dismissed_event = _event_copy.text
	_event_layer.visible = false


func _build_error_layer() -> Control:
	var layer := _dim_layer()
	var box := _modal_box(layer)
	_error_title = _label("Action not applied", 20, DANGER)
	box.add_child(_error_title)
	_error_body = _label("", 15, TEXT)
	_error_body.custom_minimum_size = Vector2(420, 0)
	box.add_child(_error_body)
	box.add_child(_label("Cash, tiles, and the board were not changed.", 13, MUTED))
	var dismiss := _button("Dismiss", true)
	dismiss.pressed.connect(_dismiss_error)
	box.add_child(dismiss)
	return layer


func _dim_layer() -> Control:
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
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var card := _card()
	card.custom_minimum_size = Vector2(480, 0)
	center.add_child(card)
	return layer


func _modal_box(layer: Control) -> VBoxContainer:
	var center := layer.get_child(1) as CenterContainer
	var card := center.get_child(0) as PanelContainer
	return _box_of(card)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (not event.pressed or event.echo):
		return
	var line_edit := get_viewport().gui_get_focus_owner()
	if line_edit is LineEdit or line_edit is TextEdit:
		return
	if event.is_action_pressed("ui_cancel"):
		if _rules.visible:
			_rules.hide_panel()
		elif _confirm_layer.visible:
			_confirm_layer.visible = false
		elif _event_layer.visible:
			_dismiss_event()
		elif _error_layer.visible:
			_dismiss_error()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("show_rules"):
		_rules.show_panel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("text_larger") or event.is_action_pressed("text_smaller"):
		if event.is_action_pressed("text_larger"):
			Palette.cycle_scale()
		else:
			var index := Palette.SCALES.find(Palette.text_scale)
			Palette.text_scale = Palette.SCALES[(index - 1 + Palette.SCALES.size()) % Palette.SCALES.size()]
			Palette.save_settings()
		Palette.restyle(self)
		_fit_board()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_motion"):
		_toggle_motion()
		get_viewport().set_input_as_handled()
		return
	if _rules.visible or _confirm_layer.visible or _event_layer.visible or _error_layer.visible or _founder_layer.visible or _merger_layer.visible:
		return
	if _match == null or _concealed or _viewing_bot() or not _play.visible or _online.visible:
		return
	var market_open := _match.phase == "market"
	if market_open and event.is_action_pressed("ui_accept"):
		_finish_market_turn()
		get_viewport().set_input_as_handled()
		return
	if _match.phase != "place":
		return
	var hand: Array = _match.active_player()["hand"]
	for slot in range(1, 6):
		if event.is_action_pressed("tile_%d" % slot):
			var index := slot - 1
			if index < hand.size():
				_select_tile(str(hand[index]))
				get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("hand_left") or event.is_action_pressed("hand_right"):
		if hand.is_empty():
			return
		var current := hand.find(_selected)
		var step := -1 if event.is_action_pressed("hand_left") else 1
		var next := 0 if current < 0 else (current + step + hand.size()) % hand.size()
		_selected = str(hand[next])
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_place_selected()
		get_viewport().set_input_as_handled()


func _shot_pull(coordinate: String) -> void:
	for player in _match.players:
		var hand: Array = player["hand"]
		var index := hand.find(coordinate)
		if index != -1:
			hand.remove_at(index)
			_match.active_player()["hand"].append(coordinate)
			return
	var bag_index: int = _match.bag.find(coordinate)
	_match.bag.remove_at(bag_index)
	_match.active_player()["hand"].append(coordinate)


func _shot_pass_market() -> void:
	while _match.phase == "market" and _match.market_actions_left > 0:
		_match.pass_market()


func _shot_founder() -> void:
	_shot_pull("A1")
	_match.place("A1")
	_shot_pass_market()
	_shot_pull("A2")
	_match.place("A2")
	_concealed = false
	_refresh()


func _shot_confirm() -> void:
	_shot_pull("A1")
	_match.place("A1")
	_shot_pass_market()
	_shot_pull("E9")
	_match.place("E9")
	_shot_pass_market()
	_shot_pull("A2")
	_match.place("A2")
	_match.choose_founder("nova_ai")
	_shot_pass_market()
	_shot_pull("C1")
	_match.place("C1")
	_shot_pass_market()
	_shot_pull("B1")
	_match.place("B1")
	_concealed = false
	_market_corp = "nova_ai"
	_refresh()
	_open_confirm("buy_share")


func _shot_economy() -> void:
	_shot_pull("A1")
	_match.place("A1")
	_shot_pass_market()
	_shot_pull("E9")
	_match.place("E9")
	_shot_pass_market()
	_shot_pull("A2")
	_match.place("A2")
	_match.choose_founder("nova_ai")
	_shot_pass_market()
	_shot_pull("C1")
	_match.place("C1")
	_shot_pass_market()
	_shot_pull("B1")
	_match.place("B1")
	_match.buy_share("nova_ai")
	_concealed = false
	_market_corp = "nova_ai"
	_refresh()


func _shot_chain(cells: Array, brand: String) -> void:
	for index in cells.size():
		var coordinate := str(cells[index])
		_shot_pull(coordinate)
		_match.place(coordinate)
		if index == 1:
			_match.choose_founder(brand)
		_shot_pass_market()


func _shot_assign(corp_id: String, counts: Dictionary) -> void:
	var outstanding := 0
	for player in _match.players:
		var count := int(counts.get(str(player["id"]), 0))
		player["shares"][corp_id] = count
		outstanding += count
	for corp in _match.corporations:
		if str(corp["id"]) == corp_id:
			corp["bank_shares"] = 20 - outstanding


func _shot_trim_hand() -> void:
	var hand: Array = _match.active_player()["hand"]
	while hand.size() > 5:
		_match.bag.append(str(hand[hand.size() - 1]))
		hand.remove_at(hand.size() - 1)


func _shot_merger() -> void:
	_shot_chain(["C1", "C2", "C3", "C4", "C5"], "nova_ai")
	_shot_chain(["A1", "A2", "A3"], "orbit_pay")
	_shot_assign("orbit_pay", {"p1": 0, "p2": 4})
	_shot_pull("B1")
	_match.place("B1")
	_shot_trim_hand()
	_concealed = false
	_refresh()


func _shot_online(match_id: String, token: String) -> void:
	var shot_args := OS.get_cmdline_user_args()
	_online._match_id = match_id
	_online._token = token
	_online._you = "p1"
	if shot_args.size() > 5:
		_online._join_code.text = str(shot_args[5])
	var port := 8741
	if shot_args.size() > 6:
		port = int(shot_args[6])
	var client := HTTPClient.new()
	var err := client.connect_to_host("127.0.0.1", port)
	if err != OK:
		push_error("online shot could not reach the server")
		get_tree().quit(1)
		return
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
	var body := JSON.stringify({
		"match_id": match_id,
		"client_action_id": "shot_%d" % Time.get_ticks_msec(),
		"expected_state_version": 0,
		"session_token": token,
		"command": "request_snapshot",
		"payload": {},
	})
	err = client.request(HTTPClient.METHOD_POST, "/v1/rooms/commands", ["Content-Type: application/json"], body)
	if err != OK:
		push_error("online shot request failed")
		get_tree().quit(1)
		return
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
	if not client.has_response() or client.get_response_code() != 200:
		push_error("online shot HTTP %s" % str(client.get_response_code()))
		get_tree().quit(1)
		return
	var read := PackedByteArray()
	var spins := 0
	while client.get_status() == HTTPClient.STATUS_BODY and spins < 2000:
		client.poll()
		spins += 1
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			read.append_array(chunk)
		var expected := client.get_response_body_length()
		if expected >= 0 and read.size() >= expected:
			break
	var parsed = JSON.parse_string(read.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("events"):
		push_error("online shot returned unreadable JSON")
		get_tree().quit(1)
		return
	_scroll.visible = false
	_online.set_anchors_preset(PRESET_FULL_RECT)
	_online.offset_left = 0
	_online.offset_top = 0
	_online.offset_right = 0
	_online.offset_bottom = 0
	_online.visible = true
	_online.move_to_front()
	for event in parsed["events"]:
		_online._on_event(event)


func _shot_event() -> void:
	var rowan: Array = _match.active_player()["hand"]
	_selected = str(rowan[0])
	_place_selected()
	_pass_market()
	_pass_market()
	_reveal()
	var quinn: Array = _match.active_player()["hand"]
	_selected = str(quinn[0])
	_place_selected()
	_pass_market()
	_pass_market()
	_concealed = false
	_refresh()


func _shot_trade() -> void:
	_shot_pull("A1")
	_match.place("A1")
	_shot_pass_market()
	_shot_pull("E9")
	_match.place("E9")
	_shot_pass_market()
	_shot_pull("A2")
	_match.place("A2")
	_match.choose_founder("nova_ai")
	_concealed = false
	_refresh()
	if _event_layer != null and _event_layer.visible:
		_dismiss_event()
	_apply(_match.buy_share("nova_ai"))


func _shot_resolve() -> void:
	_shot_pull("A1")
	_match.place("A1")
	_shot_pass_market()
	_shot_pull("E9")
	_match.place("E9")
	_shot_pass_market()
	_concealed = false
	_refresh()
	if _event_layer != null:
		_event_layer.visible = false


func _shot_score() -> void:
	_match.players[0]["cash"] = 9000
	for player in _match.players:
		var hand: Array = player["hand"]
		while not hand.is_empty():
			var cell := str(hand[0])
			hand.remove_at(0)
			_match.occupied[cell] = true
	while not _match.bag.is_empty():
		var cell := str(_match.bag[0])
		_match.bag.remove_at(0)
		_match.occupied[cell] = true
	for _seat in _match.players.size():
		_match.pass_turn()
		_shot_pass_market()
	_concealed = false
	_refresh()


func _shot_tie() -> void:
	_shot_chain(["A1", "A2"], "nova_ai")
	_shot_chain(["C1", "C2"], "orbit_pay")
	_shot_pull("B1")
	_match.place("B1")
	_shot_trim_hand()
	_concealed = false
	_refresh()


func _run_shot(path: String, phase: String) -> void:
	if phase == "online":
		var shot_args := OS.get_cmdline_user_args()
		_shot_online(str(shot_args[3]), str(shot_args[4]))
	elif phase == "bots-setup":
		_vs_bots.button_pressed = true
		_seat_checks[2].button_pressed = true
		_sync_seat_mode()
		_show_setup()
	elif phase == "bots" or phase == "preview" or phase == "standings":
		BotPolicy.set_difficulty("hard" if phase == "standings" else "normal")
		var created = OfflineMatch.create(7710, ["Rowan", "Ada", "Bo"], ["Ada", "Bo"])
		if created == null:
			push_error("screenshot deal failed")
			get_tree().quit(1)
			return
		_begin_match(created)
		_reveal()
	else:
		var created = OfflineMatch.create(7710, ["Rowan", "Quinn"])
		if created == null:
			push_error("screenshot deal failed")
			get_tree().quit(1)
			return
		_begin_match(created)
		_reveal()
	if phase == "preview":
		var preview_hand: Array = _match.active_player()["hand"]
		if not preview_hand.is_empty():
			_on_cell_hovered(str(preview_hand[0]))
	elif phase == "placed":
		var hand: Array = _match.active_player()["hand"]
		_selected = str(hand[0])
		_place_selected()
	elif phase == "economy":
		_shot_economy()
	elif phase == "merger":
		_shot_merger()
	elif phase == "tie":
		_shot_tie()
	elif phase == "founder":
		_shot_founder()
	elif phase == "event":
		_shot_event()
	elif phase == "score" or phase == "standings":
		_shot_score()
	elif phase == "resolve":
		_shot_resolve()
	elif phase == "trade":
		_shot_trade()
	elif phase == "rules":
		_rules.show_panel()
	elif phase == "confirm":
		_shot_confirm()
	elif phase == "error":
		_error.text = "That tile is not in the active hand."
		_sync_error()
	await get_tree().process_frame
	await get_tree().process_frame
	_fit_board()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var directory := path.get_base_dir()
	if directory != "" and not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var error := image.save_png(path)
	if error != OK:
		push_error("screenshot failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("SCREENSHOT %s" % path)
	get_tree().quit(0)


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "TableCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return panel


func _box_of(panel: PanelContainer) -> VBoxContainer:
	return panel.get_child(0).get_child(0) as VBoxContainer


func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.remember(label, size)
	label.add_theme_color_override("font_color", color)
	return label


func _selected_difficulty() -> String:
	if _difficulty == null:
		return "normal"
	var index := _difficulty.selected
	if index == 0:
		return "easy"
	if index == 2:
		return "hard"
	return "normal"


func _style_option(option: OptionButton) -> void:
	option.theme_type_variation = "GhostButton"
	option.focus_mode = Control.FOCUS_ALL


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 40)
	button.theme_type_variation = "PrimaryButton" if primary else "GhostButton"
	Palette.remember(button, 14)
	return button
