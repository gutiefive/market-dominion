extends Control
## Local pass-and-play table. Hands stay covered between seats.
## This is one device, not an online match.

const BG := Color("0e1525")
const CARD := Color("162033")
const TEAL := Color("2dd4bf")
const AMBER := Color("fbbf24")
const TEXT := Color("e8eef9")
const MUTED := Color("93a0b8")
const DANGER := Color("f0a0a0")

var _match: OfflineMatch
var _selected := ""
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
var _error: Label
var _side: PanelContainer
var _side_text: RichTextLabel
var _scroll: ScrollContainer
var _seed_input: LineEdit
var _name_inputs: Array[LineEdit] = []
var _seat_checks: Array[CheckBox] = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
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

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label("Market Dominion", 22, TEXT))
	titles.add_child(_label("Local pass-and-play on one device. Hands stay private.", 13, MUTED))
	var fresh := _button("New table", false)
	fresh.pressed.connect(_show_setup)
	header.add_child(fresh)

	_status = _label("", 14, MUTED)
	root.add_child(_status)
	_error = _label("", 14, DANGER)
	root.add_child(_error)

	_setup = _build_setup()
	_order = _build_order()
	_play = _build_play()
	root.add_child(_setup)
	root.add_child(_order)
	root.add_child(_play)
	_show_setup()


func _build_setup() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	var card := _card()
	panel.add_child(card)
	var box := _box_of(card)
	box.add_child(_label("Open a table", 20, TEXT))
	box.add_child(_label(
		"Two to four seats. The seed shuffles turn order, then the 81-tile bag, then deals five private tiles to each seat. The same seed deals the same hands. Nothing is sent to a server.",
		14, MUTED
	))
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
	return panel


func _build_order() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.visible = false
	panel.add_theme_constant_override("separation", 8)
	var card := _card()
	panel.add_child(card)
	var box := _box_of(card)
	box.add_child(_label("Turn order", 20, TEXT))
	box.add_child(_label(
		"Seats were shuffled before the bag. Tiles stay covered until the first player takes the device.",
		14, MUTED
	))
	_order_list = _label("", 16, TEXT)
	box.add_child(_order_list)
	var go := _button("Pass the device", true)
	go.pressed.connect(_reveal)
	box.add_child(go)
	return panel


func _build_play() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.visible = false
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)

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
	_column.add_theme_constant_override("separation", 8)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_board_card = _card()
	_column.add_child(_board_card)
	var board_box := _box_of(_board_card)
	board_box.add_child(_label("District grid  ·  A–I across, 1–9 down. Teal matches the hand. Amber is selected.", 14, TEXT))
	_board = BoardGrid.new()
	_board.cell_pressed.connect(_on_cell_pressed)
	board_box.add_child(_board)

	var hand_card := _card()
	_column.add_child(hand_card)
	var hand_box := _box_of(hand_card)
	var hand_header := HBoxContainer.new()
	hand_box.add_child(hand_header)
	hand_header.add_child(_label("Active hand", 14, TEXT))
	_hand_note = _label("", 13, MUTED)
	_hand_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand_header.add_child(_hand_note)
	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 8)
	_hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_box.add_child(_hand_row)
	_place_button = _button("Place selected", true)
	_place_button.pressed.connect(_place_selected)
	hand_box.add_child(_place_button)

	_side = _card()
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_box := _box_of(_side)
	side_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(_label("Market", 15, TEXT))
	_action_row = HFlowContainer.new()
	_action_row.add_theme_constant_override("separation", 6)
	_action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_child(_action_row)
	_side_text = RichTextLabel.new()
	_side_text.bbcode_enabled = true
	_side_text.fit_content = true
	_side_text.scroll_active = false
	_side_text.custom_minimum_size = Vector2(0, 160)
	_side_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(_side_text)
	var leave := _button("Leave table", false)
	leave.pressed.connect(_show_setup)
	side_box.add_child(leave)
	return panel


func _show_setup() -> void:
	_match = null
	_selected = ""
	_concealed = false
	_setup.visible = true
	_order.visible = false
	_play.visible = false
	_error.text = ""
	_status.text = "No table open. The deal stays on this device."


func _on_deal_pressed() -> void:
	_error.text = ""
	if not _seed_input.text.is_valid_int():
		_error.text = "Enter a whole-number seed, zero or greater."
		return
	var seed := int(_seed_input.text)
	var names: Array[String] = []
	for index in range(4):
		if index >= 2 and not _seat_checks[index].button_pressed:
			continue
		var nickname := _name_inputs[index].text.strip_edges()
		if nickname == "":
			_error.text = "Every included seat needs a display name."
			return
		names.append(nickname)
	var created = OfflineMatch.create(seed, names)
	if created == null:
		_error.text = "Use 2 to 4 unique names, 1–24 characters: letters, numbers, spaces, hyphens, or underscores. The seed must be zero or greater."
		return
	_begin_match(created)


func _begin_match(table: OfflineMatch) -> void:
	_match = table
	_selected = ""
	_setup.visible = false
	_play.visible = false
	_order.visible = true
	_concealed = true
	var lines: PackedStringArray = []
	for index in range(_match.players.size()):
		var info: Dictionary = _match.players[index]
		lines.append("%d. %s (%s) — five tiles face down" % [index + 1, str(info["display_name"]), str(info["id"])])
	_order_list.text = "\n".join(lines)
	var first := str(_match.active_player()["display_name"])
	_status.text = "Seed %d. Bag holds %d tiles. Pass the device to %s before anyone looks at a hand." % [_match.seed, _match.bag.size(), first]
	_error.text = ""


func _reveal() -> void:
	if _match == null:
		return
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
		return
	_apply(_match.place(_selected))
	_selected = ""


func _apply(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_error.text = str(result.get("error", "That action was rejected."))
		_refresh()
		return
	_error.text = ""
	if _match.phase == "place":
		_conceal_for_next(str(result["log"]))
	else:
		_refresh()


func _conceal_for_next(last_log: String) -> void:
	_concealed = true
	_selected = ""
	var nxt := str(_match.active_player()["display_name"])
	_banner_label.text = "Pass the device to %s. Their tiles stay covered. %s" % [nxt, last_log]
	_refresh()


func _refresh() -> void:
	if _match == null:
		return
	var player := _match.active_player()
	var hand: Array = player["hand"]
	var placing := _match.phase == "place" and not _concealed
	var legal: Array = hand.duplicate() if placing else []
	_board.set_state(_match.occupied, _match.company_of, legal, "" if not placing else _selected)
	_banner.visible = _concealed
	_rebuild_hand(hand)
	_rebuild_actions()
	var finished := _match.bag.is_empty() and _hands_empty() and _match.phase == "place"
	_place_button.visible = placing
	if hand.is_empty():
		_place_button.text = "Skip placement"
	else:
		_place_button.text = "Place selected"
	if _concealed:
		_status.text = "Hand covered. Prices stay visible. The next player continues when they have the device."
	elif _match.phase == "choose_founder":
		_status.text = "%s chooses a company for the new cluster. The founder receives one share if the bank has one." % str(player["display_name"])
	elif _match.phase == "market":
		_status.text = "%s has %d market action%s left. Prices shown are the prices used for the next trade." % [
			str(player["display_name"]), _match.market_actions_left, "" if _match.market_actions_left == 1 else "s"
		]
	elif hand.is_empty():
		_status.text = "%s has no tile to place. Skip placement, then take up to two market actions." % str(player["display_name"])
	else:
		_status.text = "%s places one tile. A chain of two or more can found a company. Mergers are not in this build." % str(player["display_name"])
	if finished:
		_status.text = "No tiles remain. Market actions are still available on an empty hand."
	_side_text.text = _side_bbcode()
	if _concealed:
		_hand_note.text = "Covered"
	else:
		_hand_note.text = "%d tile%s" % [hand.size(), "" if hand.size() == 1 else "s"]
	if _play.visible:
		_fit_board()


func _hands_empty() -> bool:
	for player in _match.players:
		if not (player["hand"] as Array).is_empty():
			return false
	return true


func _rebuild_hand(hand: Array) -> void:
	for child in _hand_row.get_children():
		child.queue_free()
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
		var tile := _button(str(coordinate), chosen)
		if chosen:
			tile.add_theme_color_override("font_color", Color("1a1404"))
			tile.add_theme_color_override("font_hover_color", Color("1a1404"))
		tile.pressed.connect(_select_tile.bind(str(coordinate)))
		tile.accessibility_name = "Tile %s" % str(coordinate)
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
	if _concealed or _match == null:
		return
	if _match.phase == "choose_founder":
		for corp in _match.corporations:
			if bool(corp["active"]):
				continue
			var brand := _button("%s  %s" % [str(corp["name"]), str(BoardGrid.MARKS.get(corp["id"], ""))], true)
			brand.pressed.connect(_choose_brand.bind(str(corp["id"])))
			_action_row.add_child(brand)
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
		buy.pressed.connect(_buy_share)
		var sell := _button("Sell share", false)
		sell.pressed.connect(_sell_share)
		_action_row.add_child(buy)
		_action_row.add_child(sell)
	var buy_byte := _button("Buy BYTE", true)
	buy_byte.pressed.connect(_buy_byte)
	var sell_byte := _button("Sell BYTE", false)
	sell_byte.pressed.connect(_sell_byte)
	var pass_action := _button("Pass action", false)
	pass_action.pressed.connect(_pass_market)
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


func _side_bbcode() -> String:
	var lines: PackedStringArray = []
	var active: Dictionary = _match.active_player()
	var shares: Dictionary = active["shares"]
	lines.append("[color=#93a0b8]Seed[/color]  %d    [color=#93a0b8]Round[/color]  %d    [color=#93a0b8]Bag[/color]  %d" % [
		_match.seed, _match.round_number, _match.bag.size()
	])
	lines.append("[color=#93a0b8]BYTE[/color]  $%d    exchange %d    you %d" % [
		_match.byte_price, _match.byte_exchange, int(active["byte_count"])
	])
	if _match.phase == "market":
		lines.append("[color=#fbbf24]Market actions left[/color]  %d" % _match.market_actions_left)
	lines.append("")
	for corp in _match.corporations:
		var mark := str(BoardGrid.MARKS.get(corp["id"], ""))
		if bool(corp["active"]):
			lines.append("[b]%s[/b]  %s   $%d   size %d   bank %d   you %d" % [
				str(corp["name"]), mark, int(corp["share_price"]), int(corp["size"]),
				int(corp["bank_shares"]), int(shares.get(corp["id"], 0))
			])
	var available: PackedStringArray = []
	for corp in _match.corporations:
		if not bool(corp["active"]):
			available.append(str(corp["name"]))
	if not available.is_empty():
		lines.append("[color=#93a0b8]Available to found[/color]  %s" % ", ".join(available))
	lines.append("")
	for index in range(_match.players.size()):
		var info: Dictionary = _match.players[index]
		var playing := str(info["id"]) == str(active["id"])
		var mark := "  [color=#fbbf24]playing[/color]" if playing else ""
		lines.append("%d. %s  [color=#93a0b8]%s · $%d fictional[/color]%s" % [
			index + 1, str(info["display_name"]), str(info["id"]), int(info["cash"]), mark
		])
	if not _match.log.is_empty():
		lines.append("")
		var start := maxi(0, _match.log.size() - 3)
		for index in range(start, _match.log.size()):
			lines.append(_match.log[index])
	lines.append("")
	lines.append("[color=#93a0b8]Local only. A placement that would merge two companies is rejected. Round events are not drawn.[/color]")
	return "\n".join(lines)


func _fit_board() -> void:
	if _board == null or not _play.visible:
		return
	var window := get_viewport_rect().size
	if window.x < 2.0 or window.y < 2.0:
		return
	var wide := window.x >= 980.0
	_ensure_table(wide)
	var side_reserve := 268.0 if wide else 0.0
	var board_width := window.x - 24.0 - side_reserve - (10.0 if wide else 0.0) - 28.0
	var cell_w := int((board_width - 27.0) / 10.0)
	# 1280×720 must keep the hand on screen, including the pass banner.
	# Taller windows can use a larger cell; narrow windows are width-limited.
	var cell_h := 46
	if window.y < 760.0:
		cell_h = 30 if _banner.visible else 32
	elif window.y >= 900.0:
		cell_h = 52
	_board.set_cell_size(mini(cell_w, cell_h))


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


func _run_shot(path: String, phase: String) -> void:
	var created = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	if created == null:
		push_error("screenshot deal failed")
		get_tree().quit(1)
		return
	_begin_match(created)
	_reveal()
	if phase == "placed":
		var hand: Array = _match.active_player()["hand"]
		_selected = str(hand[0])
		_place_selected()
	elif phase == "economy":
		_shot_economy()
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
	panel.add_theme_stylebox_override("panel", _box(CARD, Color("243044"), 8))
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
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 36)
	var fill := TEAL if primary else Color("243044")
	var font := Color("06211c") if primary else TEXT
	button.add_theme_stylebox_override("normal", _box(fill, fill, 6))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), fill, 6))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.08), fill, 6))
	button.add_theme_stylebox_override("focus", _box(fill, AMBER, 6))
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_focus_color", font)
	return button
