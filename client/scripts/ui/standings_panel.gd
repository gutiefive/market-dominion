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
	title.text = "%d   %s" % [rank, str(info["name"])]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("fbbf24") if rank == 1 else Color("e8eef9"))
	box.add_child(title)
	var role := Label.new()
	role.text = str(info["role"])
	role.add_theme_font_size_override("font_size", 13)
	role.add_theme_color_override("font_color", Color("93a0b8"))
	box.add_child(role)
	var money := Label.new()
	money.text = "Cash $%d   ·   portfolio $%d   ·   net $%d" % [
		int(info["cash"]), int(info["portfolio"]), int(info["net"])
	]
	money.add_theme_font_size_override("font_size", 14)
	money.add_theme_color_override("font_color", Color("e8eef9"))
	box.add_child(money)
	var book := str(info.get("book", ""))
	if book != "":
		var holdings := Label.new()
		holdings.text = book
		holdings.add_theme_font_size_override("font_size", 13)
		holdings.add_theme_color_override("font_color", Color("93a0b8"))
		box.add_child(holdings)
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
