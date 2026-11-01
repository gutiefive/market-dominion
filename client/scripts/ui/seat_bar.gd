extends VBoxContainer
class_name SeatBar

## Turn banner plus every seat. The table fills both on each refresh.

var badge: Label
var cash_label: Label
var net_label: Label
var opponents: HBoxContainer
var step_label: Label
var who_label: Label
var detail_label: Label
var banner: PanelContainer


func _ready() -> void:
	grab()


func grab() -> void:
	if badge != null:
		return
	badge = get_node("%Badge") as Label
	cash_label = get_node("%Cash") as Label
	net_label = get_node("%Net") as Label
	opponents = get_node("%Opponents") as HBoxContainer
	step_label = get_node("%Step") as Label
	who_label = get_node("%Who") as Label
	detail_label = get_node("%Detail") as Label
	banner = get_node("%Banner") as PanelContainer


func pulse(seat_name: String) -> void:
	grab()
	for child in opponents.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is OpponentChip and (child as OpponentChip).seat_name == seat_name:
			(child as OpponentChip).pulse()


func show_turn(step: String, who: String, detail: String, tone: String) -> void:
	grab()
	step_label.text = step
	who_label.text = who
	detail_label.text = detail
	var accent := _accent(tone)
	step_label.add_theme_color_override("font_color", accent)
	banner.add_theme_stylebox_override("panel", _banner_style(accent))
	banner.tooltip_text = "%s. %s. %s." % [step, who, detail]


func show_opponents(rows: Array) -> void:
	grab()
	for child in opponents.get_children():
		child.queue_free()
	var chip_scene := preload("res://scenes/components/opponent_chip.tscn")
	for row in rows:
		var info: Dictionary = row
		var chip := chip_scene.instantiate() as OpponentChip
		opponents.add_child(chip)
		chip.show_seat(
			str(info["name"]),
			str(info["meta"]),
			str(info["cash"]),
			str(info["book"]),
			bool(info.get("acting", false)),
			str(info.get("tone", "place"))
		)


func _accent(tone: String) -> Color:
	if tone == "market" or tone == "resolve":
		return Color("fbbf24")
	if tone == "wait":
		return Color("93a0b8")
	return Color("2dd4bf")


func _banner_style(accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("121a2e")
	box.border_color = accent
	box.set_border_width_all(1)
	box.border_width_left = 4
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
