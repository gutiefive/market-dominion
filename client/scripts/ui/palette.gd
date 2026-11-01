extends Object
class_name Palette

## Shared colors, type scale, and the reduced-motion flag. No logos.

const BG := Color("0e1525")
const CARD := Color("162033")
const LINE := Color("243044")
const TEAL := Color("2dd4bf")
const AMBER := Color("fbbf24")
const TEXT := Color("e8eef9")
const MUTED := Color("93a0b8")
const DANGER := Color("f0a0a0")
const SCALES: Array[float] = [1.0, 1.15, 1.3]

static var text_scale := 1.0
static var reduced_motion := false


static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://market_ui.cfg") != OK:
		return
	text_scale = float(config.get_value("ui", "text_scale", 1.0))
	reduced_motion = bool(config.get_value("ui", "reduced_motion", false))
	if not SCALES.has(text_scale):
		text_scale = 1.0


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "text_scale", text_scale)
	config.set_value("ui", "reduced_motion", reduced_motion)
	config.save("user://market_ui.cfg")


static func cycle_scale() -> float:
	var index := SCALES.find(text_scale)
	text_scale = SCALES[(index + 1) % SCALES.size()]
	save_settings()
	return text_scale


static func toggle_motion() -> bool:
	reduced_motion = not reduced_motion
	save_settings()
	return reduced_motion


static func px(size: int) -> int:
	return maxi(11, int(round(float(size) * text_scale)))


static func remember(control: Control, size: int) -> void:
	control.set_meta("md_font", size)
	if control is RichTextLabel:
		(control as RichTextLabel).add_theme_font_size_override("normal_font_size", px(size))
	else:
		control.add_theme_font_size_override("font_size", px(size))


static func restyle(node: Node) -> void:
	if node is Control and (node as Control).has_meta("md_font"):
		remember(node as Control, int((node as Control).get_meta("md_font")))
	for child in node.get_children():
		restyle(child)


static func flat(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
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
