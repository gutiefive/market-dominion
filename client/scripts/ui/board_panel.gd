extends PanelContainer
class_name BoardPanel

## District grid plus the hover line and zoom. Cells still come from BoardGrid.

signal zoom_out_pressed
signal zoom_in_pressed

var preview: Label
var grid: BoardGrid


func _ready() -> void:
	grab()
	theme_type_variation = "TableCard"


func grab() -> void:
	if grid != null:
		return
	preview = get_node("%Preview") as Label
	grid = get_node("%Grid") as BoardGrid
	(get_node("%ZoomOut") as Button).pressed.connect(func() -> void: zoom_out_pressed.emit())
	(get_node("%ZoomIn") as Button).pressed.connect(func() -> void: zoom_in_pressed.emit())
