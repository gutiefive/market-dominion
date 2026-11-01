extends VBoxContainer
class_name MarketWatch

## Right-hand watchlist. Price, sentiment, size, and bank shares are text, not color alone.

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
	add_child(panel)


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
