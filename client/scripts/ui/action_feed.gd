extends VBoxContainer
class_name ActionFeed

## Last few table events, newest first. The match log is not rewritten.

var _slots: Array[Label] = []
var _footer: Label


func _ready() -> void:
	_bind()


func _bind() -> void:
	if not _slots.is_empty():
		return
	for index in range(1, 5):
		_slots.append(get_node("%Line" + str(index)) as Label)
	_footer = get_node("%Footer") as Label


func show_events(events: PackedStringArray, footer: String) -> void:
	_bind()
	var shown := PackedStringArray()
	if events.is_empty():
		shown.append("No actions yet.")
	else:
		var count := mini(4, events.size())
		for index in count:
			shown.append(events[index])
	for index in _slots.size():
		var label := _slots[index]
		if index < shown.size():
			label.visible = true
			label.text = shown[index]
			var color := Color("fbbf24") if index == 0 and not events.is_empty() else Color("93a0b8")
			label.add_theme_color_override("font_color", color)
		else:
			label.visible = false
			label.text = ""
	_footer.text = footer


static func shorten(line: String) -> String:
	var text := line.strip_edges()
	if text.begins_with("Round event:"):
		var body := text.trim_prefix("Round event:").strip_edges()
		var dot := body.find(". ")
		if dot >= 0:
			body = body.substr(dot + 2)
		body = body.replace(". BYTE is $", " · BYTE $")
		body = body.trim_suffix(".")
		return "Round resolved: %s" % body
	if text.ends_with(" passed a market action."):
		return "%s passed the market" % _actor(text)
	if " bought 1 BYTE for $" in text:
		return "%s bought 1 BYTE @ $%s" % [_actor(text), _money(text)]
	if " sold 1 BYTE for $" in text:
		return "%s sold 1 BYTE @ $%s" % [_actor(text), _money(text)]
	if " bought 1 " in text and " share for $" in text:
		return "%s bought 1 %s @ $%s" % [_actor(text), _mark(_between(text, " bought 1 ", " share for $")), _money(text)]
	if " sold 1 " in text and " share for $" in text:
		return "%s sold 1 %s @ $%s" % [_actor(text), _mark(_between(text, " sold 1 ", " share for $")), _money(text)]
	if " drew from the bag." in text:
		return "%s drew a tile" % _actor(text)
	if " drew nothing." in text:
		return "%s drew nothing" % _actor(text)
	if " has no tile to place." in text:
		return "%s skipped placement" % _actor(text)
	if " wins with $" in text:
		return "%s wins · $%s" % [_actor(text), _money(text)]
	if " founded " in text:
		return "%s founded %s" % [_actor(text), _mark(_between(text, " founded ", " on "))]
	if " and grew " in text:
		var grown := _mark(_between(text, " and grew ", " to size "))
		var size := _between(text, " to size ", ".")
		var price := _money(text) if "Share price is $" in text else ""
		if price == "":
			return "%s grew %s to size %s" % [_actor(text), grown, size]
		return "%s grew %s to size %s · $%s" % [_actor(text), grown, size, price]
	if " placed " in text:
		return "%s placed %s" % [_actor(text), _between(text, " placed ", ".")]
	if text.begins_with("Final round"):
		return "Final round"
	return text.trim_suffix(".")


static func _actor(text: String) -> String:
	var space := text.find(" ")
	if space < 0:
		return text
	return text.substr(0, space)


static func _between(text: String, start: String, end: String) -> String:
	var from := text.find(start)
	if from < 0:
		return ""
	from += start.length()
	var to := text.find(end, from)
	if to < 0:
		return text.substr(from).trim_suffix(".")
	return text.substr(from, to - from)


static func _money(text: String) -> String:
	var mark := text.rfind("$")
	if mark < 0:
		return ""
	var tail := text.substr(mark + 1)
	var digits := ""
	for index in tail.length():
		var ch := tail.substr(index, 1)
		if ch < "0" or ch > "9":
			break
		digits += ch
	return digits


static func _mark(company_name: String) -> String:
	var cleaned := company_name.strip_edges()
	for corp_id in BoardGrid.NAMES.keys():
		if str(BoardGrid.NAMES[corp_id]) == cleaned:
			return str(BoardGrid.MARKS[corp_id])
	return cleaned
