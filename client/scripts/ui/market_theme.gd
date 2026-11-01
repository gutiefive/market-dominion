extends RefCounted
class_name MarketTheme

## Shared Theme resource for the table. Scenes and code-built controls both use it.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	var text := Color("e8eef9")
	var muted := Color("93a0b8")
	var ink := Color("06211c")
	var teal := Color("2dd4bf")
	var amber := Color("fbbf24")
	var card := Color("162033")
	var line := Color("2a3b56")
	var ghost := Color("243044")

	_button(theme, "Button", ghost, line, text, text)
	_button(theme, "PrimaryButton", teal, teal, ink, ink)
	_button(theme, "GhostButton", ghost, line, text, text)
	_button(theme, "TileChip", ghost, Color("3d4e6b"), text, text)
	_button(theme, "TileChipOn", amber, Color("f6d98a"), Color("1a1404"), Color("1a1404"))
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_type_variation("GhostButton", "Button")
	theme.set_type_variation("TileChip", "Button")
	theme.set_type_variation("TileChipOn", "Button")

	var panel := _flat(card, line, 10, 1)
	panel.shadow_color = Color(0, 0, 0, 0.28)
	panel.shadow_size = 8
	panel.shadow_offset = Vector2(0, 3)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "TableCard", panel)
	theme.set_type_variation("TableCard", "PanelContainer")

	var dock := _flat(Color("1a2744"), teal, 10, 1)
	dock.border_width_top = 2
	dock.content_margin_left = 0
	dock.content_margin_right = 0
	dock.content_margin_top = 0
	dock.content_margin_bottom = 0
	dock.shadow_color = Color(0, 0, 0, 0.35)
	dock.shadow_size = 12
	dock.shadow_offset = Vector2(0, -3)
	theme.set_stylebox("panel", "MarketDock", dock)
	theme.set_type_variation("MarketDock", "PanelContainer")

	var step_on := _flat(teal, teal, 8, 1)
	var step_off := _flat(Color("121a2e"), Color("2c3c58"), 8, 1)
	theme.set_stylebox("panel", "StepOn", step_on)
	theme.set_stylebox("panel", "StepOff", step_off)
	theme.set_type_variation("StepOn", "PanelContainer")
	theme.set_type_variation("StepOff", "PanelContainer")

	theme.set_color("font_color", "Label", text)
	theme.set_font_size("font_size", "Label", 14)
	theme.set_color("font_color", "DockTitle", text)
	theme.set_font_size("font_size", "DockTitle", 18)
	theme.set_type_variation("DockTitle", "Label")
	theme.set_color("font_color", "MutedLabel", muted)
	theme.set_font_size("font_size", "MutedLabel", 13)
	theme.set_type_variation("MutedLabel", "Label")
	theme.set_color("font_color", "StepOnText", ink)
	theme.set_font_size("font_size", "StepOnText", 12)
	theme.set_type_variation("StepOnText", "Label")
	theme.set_color("font_color", "StepOffText", muted)
	theme.set_font_size("font_size", "StepOffText", 12)
	theme.set_type_variation("StepOffText", "Label")
	theme.set_color("default_color", "RichTextLabel", text)
	theme.set_font_size("normal_font_size", "RichTextLabel", 13)

	var field := _flat(Color("10182a"), line, 6, 1)
	field.content_margin_left = 8
	field.content_margin_right = 8
	field.content_margin_top = 6
	field.content_margin_bottom = 6
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _flat(Color("10182a"), amber, 6, 1))
	theme.set_color("font_color", "LineEdit", text)
	theme.set_color("font_placeholder_color", "LineEdit", muted)
	theme.set_font_size("font_size", "LineEdit", 14)

	theme.set_color("font_color", "CheckBox", text)
	theme.set_color("font_hover_color", "CheckBox", text)
	theme.set_color("font_pressed_color", "CheckBox", text)
	theme.set_color("font_disabled_color", "CheckBox", muted)
	theme.set_font_size("font_size", "CheckBox", 14)
	theme.set_constant("h_separation", "CheckBox", 8)
	theme.set_icon("checked", "CheckBox", _check_icon(true, teal))
	theme.set_icon("unchecked", "CheckBox", _check_icon(false, line))
	theme.set_icon("checked_disabled", "CheckBox", _check_icon(true, muted))
	theme.set_icon("unchecked_disabled", "CheckBox", _check_icon(false, Color("243044")))

	_button(theme, "OptionButton", ghost, line, text, text)
	theme.set_color("font_color", "PopupMenu", text)
	theme.set_color("font_hover_color", "PopupMenu", ink)
	theme.set_stylebox("panel", "PopupMenu", _flat(card, line, 8, 1))
	theme.set_stylebox("hover", "PopupMenu", _flat(teal, teal, 4, 0))
	return theme


static func _button(theme: Theme, type_name: String, fill: Color, border: Color, font: Color, hover_font: Color) -> void:
	var normal := _flat(fill, border, 8, 1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := _flat(fill.lightened(0.08), border, 8, 1)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	var pressed := _flat(fill.darkened(0.08), border, 8, 1)
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	pressed.content_margin_top = 6
	pressed.content_margin_bottom = 6
	var focus := _flat(fill, Color("fbbf24"), 8, 2)
	focus.content_margin_left = 12
	focus.content_margin_right = 12
	focus.content_margin_top = 6
	focus.content_margin_bottom = 6
	theme.set_stylebox("normal", type_name, normal)
	theme.set_stylebox("hover", type_name, hover)
	theme.set_stylebox("pressed", type_name, pressed)
	theme.set_stylebox("focus", type_name, focus)
	theme.set_stylebox("disabled", type_name, normal)
	theme.set_color("font_color", type_name, font)
	theme.set_color("font_hover_color", type_name, hover_font)
	theme.set_color("font_pressed_color", type_name, hover_font)
	theme.set_color("font_focus_color", type_name, hover_font)
	theme.set_color("font_disabled_color", type_name, Color("93a0b8"))
	theme.set_font_size("font_size", type_name, 14)


static func _flat(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func _check_icon(on: bool, accent: Color) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var fill := Color("134e4a") if on else Color("10182a")
	for y in range(1, 15):
		for x in range(1, 15):
			var edge := x <= 2 or y <= 2 or x >= 13 or y >= 13
			image.set_pixel(x, y, accent if edge else fill)
	if on:
		var ink := Color("e8eef9")
		var mark: Array[Vector2i] = [
			Vector2i(4, 8), Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 9),
			Vector2i(8, 8), Vector2i(9, 7), Vector2i(10, 6), Vector2i(11, 5),
		]
		for point in mark:
			image.set_pixel(point.x, point.y, ink)
			image.set_pixel(point.x, point.y + 1, ink)
	return ImageTexture.create_from_image(image)
