extends PanelContainer
class_name OpponentChip

## One seat at the table: name, cash, and the share book.

var name_label: Label
var cash_label: Label
var meta_label: Label
var book_label: Label


func show_seat(seat_name: String, meta: String, cash: String, book: String, acting: bool, tone: String) -> void:
	if name_label == null:
		name_label = get_node("%Name") as Label
		cash_label = get_node("%Cash") as Label
		meta_label = get_node("%Meta") as Label
		book_label = get_node("%Book") as Label
	name_label.text = seat_name
	cash_label.text = cash
	meta_label.text = meta
	book_label.text = book
	tooltip_text = "%s. %s. %s. %s." % [seat_name, meta, cash, book]
	var accent := _accent(tone)
	if acting:
		add_theme_stylebox_override("panel", _card_style(accent))
		name_label.add_theme_color_override("font_color", accent)
	else:
		remove_theme_stylebox_override("panel")
		name_label.add_theme_color_override("font_color", Color("e8eef9"))
	theme_type_variation = "TableCard"


func _accent(tone: String) -> Color:
	if tone == "market" or tone == "resolve":
		return Color("fbbf24")
	if tone == "wait":
		return Color("93a0b8")
	return Color("2dd4bf")


func _card_style(accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("142033")
	box.border_color = accent
	box.set_border_width_all(1)
	box.border_width_left = 4
	box.set_corner_radius_all(10)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box
