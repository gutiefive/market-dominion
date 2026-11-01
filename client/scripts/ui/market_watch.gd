extends VBoxContainer
class_name MarketWatch

## Right-hand watchlist. Price, sentiment, size, and bank shares are text, not color alone.

func show_rows(rows: Array) -> void:
	for child in get_children():
		child.queue_free()
	if rows.is_empty():
		_add("No companies are active yet. A chain of two can found one.", Palette.MUTED, 13)
		return
	for row in rows:
		var info: Dictionary = row
		if not bool(info.get("active", true)):
			_add("%s %s  %s  available to found" % [
				str(info["symbol"]), str(info["mark"]), str(info["name"])
			], Palette.MUTED, 13)
			continue
		_add("%s %s  %s" % [str(info["symbol"]), str(info["mark"]), str(info["name"])], Palette.TEXT, 15)
		if str(info.get("detail", "")) != "":
			_add(str(info["detail"]), Palette.MUTED, 13)
			continue
		_add("$%d   sentiment %s   size %d   bank %d   you %d" % [
			int(info["price"]), str(info["sentiment"]), int(info["size"]), int(info["bank"]), int(info["yours"])
		], Palette.MUTED, 13)


func _add(text: String, color: Color, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.remember(label, size)
	add_child(label)
