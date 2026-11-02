extends Control
class_name StandingsPanel

## End-of-match ranks. The table decides what Play again and the lobby do.

signal play_again_pressed
signal lobby_pressed

var winner_label: Label
var list: VBoxContainer
var again_button: Button
var lobby_button: Button


func _ready() -> void:
	grab()
	resized.connect(_fit)
	get_viewport().size_changed.connect(func() -> void: call_deferred("_fit"))
	_fit()
	if again_button != null and not again_button.pressed.is_connected(_emit_again):
		again_button.pressed.connect(_emit_again)
	if lobby_button != null and not lobby_button.pressed.is_connected(_emit_lobby):
		lobby_button.pressed.connect(_emit_lobby)


func grab() -> void:
	if winner_label != null:
		return
	winner_label = get_node("%Winner") as Label
	list = get_node("%List") as VBoxContainer
	again_button = get_node("%Again") as Button
	lobby_button = get_node("%Lobby") as Button
	Palette.remember(winner_label, 16)
	Palette.remember(get_node("Center/Card/Margin/Scroll/Body/Title") as Label, 22)
	for button in [again_button, lobby_button]:
		Palette.remember(button, 14)
		button.custom_minimum_size.y = 44


func present(winner: String, rows: Array) -> void:
	grab()
	visible = true
	winner_label.text = winner
	for child in list.get_children():
		child.queue_free()
	for row in rows:
		list.add_child(_row(row))


func _emit_again() -> void:
	play_again_pressed.emit()


func _emit_lobby() -> void:
	lobby_pressed.emit()


func _row(info: Dictionary) -> PanelContainer:
	var rank := int(info["rank"])
	var panel := PanelContainer.new()
	panel.theme_type_variation = "TableCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rank == 1:
		panel.add_theme_stylebox_override("panel", _winner_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = "%d   %s" % [rank, str(info["name"])]
	Palette.remember(title, 18)
	title.add_theme_color_override("font_color", Color("fbbf24") if rank == 1 else Color("e8eef9"))
	box.add_child(title)
	var role := Label.new()
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.text = str(info["role"])
	Palette.remember(role, 13)
	role.add_theme_color_override("font_color", Color("93a0b8"))
	box.add_child(role)
	var money := Label.new()
	money.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money.text = "Cash $%d   ·   portfolio $%d   ·   net $%d" % [
		int(info["cash"]), int(info["portfolio"]), int(info["net"])
	]
	Palette.remember(money, 14)
	money.add_theme_color_override("font_color", Color("e8eef9"))
	box.add_child(money)
	var book := str(info.get("book", ""))
	if book != "":
		var holdings := Label.new()
		holdings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		holdings.text = book
		Palette.remember(holdings, 13)
		holdings.add_theme_color_override("font_color", Color("93a0b8"))
		box.add_child(holdings)
	var analysis: Dictionary = info.get("analysis", {})
	if not analysis.is_empty():
		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Palette.remember(detail, 13)
		var change := int(analysis["net_change"])
		var shown_change := "%s$%d" % ["+" if change >= 0 else "-", absi(change)]
		detail.text = "Change from starting cash: %s. Placed %d tiles; founded %d companies.\nMarket: %d buys, %d sells; spent $%d, sale proceeds $%d.\nMerger bonuses $%d; buyouts $%d." % [shown_change, int(analysis.get("tiles_placed", 0)), int(analysis.get("companies_founded", 0)), int(analysis["buys"]), int(analysis["sells"]), int(analysis.get("spent", 0)), int(analysis.get("proceeds", 0)), int(analysis.get("merger_bonus", 0)), int(analysis.get("merger_buyout", 0))]
		if not bool(analysis["cash_reconciled"]):
			detail.text = "Detailed cash history is incomplete for this table. Closing values above remain authoritative."
		detail.accessibility_name = detail.text
		box.add_child(detail)
	return panel


func _winner_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("142033")
	box.border_color = Color("2dd4bf")
	box.set_border_width_all(1)
	box.border_width_left = 4
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _fit() -> void:
	# Follow the logical viewport even when a parent has not resized yet.
	for path in ["Dim", "Center"]:
		var surface := get_node(path) as Control
		surface.set_anchors_preset(Control.PRESET_TOP_LEFT)
		surface.position = Vector2.ZERO
		surface.size = get_viewport_rect().size
	var card := get_node("Center/Card") as PanelContainer
	var scroll := get_node("Center/Card/Margin/Scroll") as ScrollContainer
	card.custom_minimum_size.x = minf(560, maxf(240, get_viewport_rect().size.x - 24))
	scroll.custom_minimum_size.y = minf(620, maxf(180, get_viewport_rect().size.y - 80))
	scroll.accessibility_name = "Final standings and match analysis; scroll to review every player."
