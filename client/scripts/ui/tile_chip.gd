extends Button
class_name TileChip

## One coordinate in the hand. The dock owns the row. The table hears the signal.

signal chosen(coordinate: String)

var coordinate := ""


func setup(cell: String, selected: bool) -> void:
	coordinate = cell
	text = cell
	theme_type_variation = "TileChipOn" if selected else "TileChip"
	custom_minimum_size = Vector2(78, 44)
	tooltip_text = "Tile %s" % cell
	accessibility_name = tooltip_text
	if not pressed.is_connected(_emit):
		pressed.connect(_emit)


func _emit() -> void:
	chosen.emit(coordinate)
