extends Control

## M0 status screen. Numbers come from the shared contract. This is not a board.

const NAVY := Color(0.054902, 0.082353, 0.145098)
const CARD := Color(0.086275, 0.125490, 0.200000)
const TEAL := Color(0.176471, 0.831373, 0.749020)
const AMBER := Color(0.984314, 0.749020, 0.141176)
const TEXT := Color(0.909804, 0.933333, 0.968627)
const MUTED := Color(0.576471, 0.643137, 0.721569)
const DANGER := Color(0.941176, 0.443137, 0.403922)

var _status: Label
var _grid: GridContainer
var _margin: MarginContainer
var _values: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_reload()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	await _capture_screenshot_if_requested()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reload()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


func _build() -> void:
	var background := ColorRect.new()
	background.color = NAVY
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

	var kicker := _label("FICTIONAL GAME CURRENCY", 13, TEAL)
	column.add_child(kicker)
	var title := _label("Market Dominion", 36, TEXT)
	column.add_child(title)
	var subtitle := _label(
		"Foundation build. The 9×9 district board is the next milestone. Nothing on this screen moves real money.",
		16,
		MUTED
	)
	column.add_child(subtitle)
	_status = _label("Status: loading shared contract.", 16, TEXT)
	column.add_child(_status)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	column.add_child(_grid)

	for key in [
		"Board",
		"Table",
		"Opening book",
		"Corporations",
		"BYTE",
		"Market round",
		"How a game ends",
		"Protocol",
	]:
		_add_card(key)

	var hint := _label("R reloads the contract. Esc closes the window. Focus the button with Tab.", 14, MUTED)
	column.add_child(hint)
	var button := Button.new()
	button.text = "Reload shared contract"
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(_reload)
	column.add_child(button)
	button.grab_focus()


func _add_card(key: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 72)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.35)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label(key, 13, AMBER))
	var value := _label("—", 20, TEXT)
	box.add_child(value)
	_grid.add_child(panel)
	_values[key] = value


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_layout() -> void:
	var width := get_viewport_rect().size.x
	var inset := 28
	if width < 760:
		inset = 16
		_grid.columns = 1
	else:
		_grid.columns = 2
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_margin.add_theme_constant_override(side, inset)


func _reload() -> void:
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	var schema = SharedFiles.read_json("protocol/schema.json")
	var corporations = SharedFiles.read_json("fixtures/corporations.json")
	var events = SharedFiles.read_json("fixtures/round_events.json")
	if rules == null or schema == null or corporations == null or events == null:
		_status.text = "Status: ERROR. Shared contract could not be read beside the client folder."
		_status.add_theme_color_override("font_color", DANGER)
		for key in _values.keys():
			_values[key].text = "—"
		return
	_status.add_theme_color_override("font_color", TEAL)
	var info := Engine.get_version_info()
	var engine := "%s.%s.%s" % [info["major"], info["minor"], info["patch"]]
	var commands: Array = schema["$defs"]["command_name"]["enum"]
	_values["Board"].text = "%d × %d districts, %d unique coordinates" % [
		int(rules["board_columns"]), int(rules["board_rows"]), int(rules["tile_count"])
	]
	_values["Table"].text = "%d–%d players, opening hand %d" % [
		int(rules["players_min"]), int(rules["players_max"]), int(rules["starting_hand_size"])
	]
	_values["Opening book"].text = "%s fictional cash" % _dollars(int(rules["starting_cash"]))
	_values["Corporations"].text = "%d brands, %d shares each" % [
		corporations["corporations"].size(), int(rules["corporation_share_supply"])
	]
	_values["BYTE"].text = "%d coins, opens at %s" % [
		int(rules["byte_supply"]), _dollars(int(rules["byte_initial_price"]))
	]
	_values["Market round"].text = "%d actions, then 1 of %d events" % [
		int(rules["market_actions_per_turn"]), events["events"].size()
	]
	_values["How a game ends"].text = "Company size %d, or %d occupied squares" % [
		int(rules["end_company_size"]), int(rules["end_occupied_tiles"])
	]
	_values["Protocol"].text = "%d commands, contract %s" % [
		commands.size(), str(rules["protocol_version"])
	]
	var warning := ""
	if engine != "4.7.2":
		warning = " This window is not the pinned 4.7.2 build."
	_status.text = "Status: OK. Shared contract loaded on Godot %s.%s" % [engine, warning]


func _dollars(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	grouped = digits + grouped
	if amount < 0:
		return "-$" + grouped
	return "$" + grouped


func _capture_screenshot_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--screenshot")
	if index == -1 or index + 1 >= args.size():
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := str(args[index + 1])
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save screenshot to %s (%s)" % [path, err])
		get_tree().quit(1)
		return
	print("SCREENSHOT %s" % path)
	get_tree().quit(0)
