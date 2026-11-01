extends PanelContainer
class_name OpponentChip

## One other seat: name, role, and how many tiles they still hold.

var caption: Label


func show_seat(seat_name: String, role: String, tiles: int) -> void:
	if caption == null:
		caption = get_node("%Caption") as Label
	theme_type_variation = "TableCard"
	caption.text = "%s · %s · %d tiles" % [seat_name, role, tiles]
	tooltip_text = caption.text
