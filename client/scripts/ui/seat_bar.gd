extends VBoxContainer
class_name SeatBar

## Active seat cash and the other seats. Filled by the table each refresh.

var badge: Label
var cash_label: Label
var net_label: Label
var opponents: HBoxContainer


func _ready() -> void:
	grab()


func grab() -> void:
	if badge != null:
		return
	badge = get_node("%Badge") as Label
	cash_label = get_node("%Cash") as Label
	net_label = get_node("%Net") as Label
	opponents = get_node("%Opponents") as HBoxContainer


func show_opponents(rows: Array) -> void:
	for child in opponents.get_children():
		child.queue_free()
	var chip_scene := preload("res://scenes/components/opponent_chip.tscn")
	for row in rows:
		var info: Dictionary = row
		var chip := chip_scene.instantiate() as OpponentChip
		opponents.add_child(chip)
		chip.show_seat(str(info["name"]), str(info["role"]), int(info["tiles"]))
