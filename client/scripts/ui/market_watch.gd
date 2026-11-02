extends VBoxContainer
class_name MarketWatch

## Right-hand watchlist. Price, sentiment, size, and bank shares are text, not color alone.

var _cards: Dictionary = {}
var _expanded: Dictionary = {}

const _ACCENTS := {
	"BYTE": Color("7dd3fc"),
	"NA": Color("c4b5fd"),
	"OP": Color("7dd3fc"),
	"VG": Color("fbbf24"),
	"PM": Color("fb7185"),
	"EM": Color("4ade80"),
}


func _init() -> void:
	add_theme_constant_override("separation", 4)


func show_rows(rows: Array) -> void:
	_cards.clear()
	for child in get_children():
		child.queue_free()
	if rows.is_empty():
		_add("No companies are active yet. A chain of two can found one.", Palette.MUTED, 13)
		return
	for row in rows:
		var info: Dictionary = row
		_add_card(info)


func _add_card(info: Dictionary) -> void:
	var mark := str(info.get("mark", ""))
	var accent: Color = _ACCENTS.get(mark, Palette.TEAL)
	var active := bool(info.get("active", true))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style(accent, active))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	var title_text := "%s  %s  %s" % [str(info["symbol"]), mark, str(info["name"])]
	if not active:
		title_text += "   ·   available"
	var title := _add(title_text, Palette.TEXT if active else Palette.MUTED, 14)
	box.add_child(title)
	if active and str(info.get("detail", "")) != "":
		box.add_child(_add(str(info["detail"]), Palette.MUTED, 13))
	elif active:
		box.add_child(_add("$%d" % int(info["price"]), accent, 18))
		box.add_child(_add("sentiment %s   ·   size %d   ·   bank %d   ·   you %d" % [
			str(info["sentiment"]), int(info["size"]), int(info["bank"]), int(info["yours"])
		], Palette.MUTED, 12))
	var history: Array = info.get("history", [])
	var quoted := false
	for point in history:
		if point["price"] != null:
			quoted = true
	if quoted:
		var copy := QuoteHistory.description(history)
		var history_box := VBoxContainer.new()
		history_box.visible = bool(_expanded.get(mark, false))
		var toggle := Button.new()
		toggle.text = "Price history"
		Palette.remember(toggle, 14)
		toggle.theme_type_variation = "GhostButton"
		toggle.custom_minimum_size.y = 44
		toggle.focus_mode = Control.FOCUS_ALL
		toggle.accessibility_name = "Show or hide recorded price history for " + str(info["name"])
		toggle.pressed.connect(func() -> void:
			history_box.visible = not history_box.visible
			_expanded[mark] = history_box.visible
		)
		box.add_child(toggle)
		box.add_child(history_box)
		if history.size() > 1:
			var chart := QuoteHistory.new()
			chart.points = history
			chart.tooltip_text = copy + "\n" + str(info.get("coverage", "Actual local quote changes; evenly spaced observations, not elapsed time."))
			chart.accessibility_name = copy + ". Quote-change order, not elapsed time."
			history_box.add_child(chart)
		history_box.add_child(_add(copy, Palette.MUTED, 12))
		history_box.add_child(_add("Change order, not elapsed time.", Palette.MUTED, 12))
		var latest: Dictionary = history.back()
		var source := "Round %d · %s" % [int(latest["round"]), str(latest["reason"])]
		history_box.add_child(_add(source, Palette.MUTED, 12))
	add_child(panel)
	if mark != "":
		_cards[mark] = panel


func flash(mark: String) -> void:
	var panel: PanelContainer = _cards.get(mark)
	if panel == null or Palette.reduced_motion:
		return
	var base := panel.get_theme_stylebox("panel")
	var saved: StyleBox = base.duplicate() if base != null else null
	if saved is StyleBoxFlat:
		var hot := (saved as StyleBoxFlat).duplicate() as StyleBoxFlat
		hot.bg_color = Color("3a2a12")
		hot.border_color = Color("fbbf24")
		panel.add_theme_stylebox_override("panel", hot)
	panel.modulate = Color(1.35, 1.22, 0.7)
	var tween := panel.create_tween()
	tween.tween_interval(0.32)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.4)
	tween.tween_callback(func() -> void:
		if is_instance_valid(panel) and saved != null:
			panel.add_theme_stylebox_override("panel", saved)
	)


func _card_style(accent: Color, active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("121a2c") if active else Color("10182a")
	box.border_color = accent if active else Color("2a3b56")
	box.set_border_width_all(1)
	box.border_width_left = 4
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


func _add(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.remember(label, size)
	return label
