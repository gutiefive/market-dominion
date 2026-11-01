class_name BoardGrid
extends GridContainer
## Labeled 9×9 district grid. Every cell shows its coordinate.

signal cell_pressed(coordinate: String)

const MARKS := {
	"nova_ai": "NA",
	"orbit_pay": "OP",
	"volt_grid": "VG",
	"pulse_media": "PM",
	"evermart": "EM",
}
const NAMES := {
	"nova_ai": "NOVA AI",
	"orbit_pay": "ORBIT PAY",
	"volt_grid": "VOLT GRID",
	"pulse_media": "PULSE MEDIA",
	"evermart": "EVERMART",
}

var _buttons: Dictionary = {}
var _legal: Dictionary = {}
var _cell_size: int = 52


func _init() -> void:
	columns = 10
	add_theme_constant_override("h_separation", 3)
	add_theme_constant_override("v_separation", 3)
	_build()
	set_state({}, {}, [], "")


func _build() -> void:
	var coords := Coordinates.catalog()
	_add_label("")
	for column in range(9):
		_add_label(str(coords[column]).substr(0, 1) if coords.size() == 81 else "")
	for row in range(9):
		_add_label(str(row + 1))
		for column in range(9):
			var coordinate := str(coords[row * 9 + column]) if coords.size() == 81 else ""
			var button := Button.new()
			button.text = coordinate
			button.focus_mode = Control.FOCUS_ALL
			button.pressed.connect(_on_cell.bind(coordinate))
			_buttons[coordinate] = button
			add_child(button)
	set_cell_size(_cell_size)


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("93a0b8"))
	label.custom_minimum_size = Vector2(_cell_size, 22)
	add_child(label)


func set_cell_size(px: int) -> void:
	_cell_size = clampi(px, 24, 58)
	var font := 13 if _cell_size >= 46 else 11
	for child in get_children():
		if child is Label:
			child.custom_minimum_size = Vector2(_cell_size, 22)
	for button in _buttons.values():
		button.custom_minimum_size = Vector2(_cell_size, _cell_size)
		button.add_theme_font_size_override("font_size", 9 if _cell_size < 44 else font)


func set_state(occupied: Dictionary, companies: Dictionary, legal: Array, selected: String) -> void:
	_legal.clear()
	for coordinate in legal:
		_legal[str(coordinate)] = true
	for coordinate in Coordinates.catalog():
		var button: Button = _buttons[coordinate]
		var is_occupied := bool(occupied.get(coordinate, false))
		var corp_id := str(companies.get(coordinate, ""))
		var is_legal := _legal.has(coordinate)
		var is_selected := coordinate == selected and is_legal
		button.disabled = false
		button.focus_mode = Control.FOCUS_ALL if is_legal else Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_legal else Control.CURSOR_ARROW
		button.text = coordinate if corp_id == "" else "%s\n%s" % [coordinate, str(MARKS.get(corp_id, corp_id))]
		button.tooltip_text = _tip(coordinate, is_occupied, is_legal, corp_id)
		_paint(button, is_occupied, is_legal, is_selected, corp_id)


func _tip(coordinate: String, is_occupied: bool, is_legal: bool, corp_id: String) -> String:
	if corp_id != "":
		return "%s · %s (%s)." % [coordinate, str(NAMES.get(corp_id, corp_id)), str(MARKS.get(corp_id, ""))]
	if is_occupied:
		return "%s is an unincorporated district." % coordinate
	if is_legal:
		return "Place %s. It matches a tile in the active hand." % coordinate
	return "%s is empty. The active player does not hold this tile." % coordinate


func _paint(button: Button, is_occupied: bool, is_legal: bool, is_selected: bool, corp_id: String) -> void:
	var fill := Color("10182a")
	var border := Color("243044")
	var text := Color("66758c")
	var width := 1
	if corp_id != "":
		var style: Dictionary = _company_style(corp_id)
		fill = style["fill"]
		border = style["border"]
		text = style["text"]
		width = 2
	elif is_occupied:
		fill = Color("1a3d42")
		border = Color("2dd4bf")
		text = Color("e8eef9")
		width = 2
	elif is_selected:
		fill = Color("3a3014")
		border = Color("fbbf24")
		text = Color("fbbf24")
		width = 2
	elif is_legal:
		fill = Color("132a36")
		border = Color("2dd4bf")
		text = Color("d7fff6")
		width = 2
	var normal := _box(fill, border, width)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), border, width))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.08), border, width))
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("focus", _box(fill, Color("fbbf24"), 3))
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_disabled_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_focus_color", text)


func _company_style(corp_id: String) -> Dictionary:
	match corp_id:
		"nova_ai":
			return {"fill": Color("2a2150"), "border": Color("c4b5fd"), "text": Color("e8e0ff")}
		"orbit_pay":
			return {"fill": Color("123044"), "border": Color("7dd3fc"), "text": Color("e0f6ff")}
		"volt_grid":
			return {"fill": Color("3a3014"), "border": Color("fbbf24"), "text": Color("fff4d6")}
		"pulse_media":
			return {"fill": Color("3f1d2a"), "border": Color("fb7185"), "text": Color("ffe4ea")}
		"evermart":
			return {"fill": Color("143024"), "border": Color("4ade80"), "text": Color("e5ffef")}
	return {"fill": Color("1a3d42"), "border": Color("2dd4bf"), "text": Color("e8eef9")}


func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


func _on_cell(coordinate: String) -> void:
	if _legal.has(coordinate):
		cell_pressed.emit(coordinate)
