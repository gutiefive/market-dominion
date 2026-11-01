extends PanelContainer
class_name PricePanel

## Share and BYTE prices, then the short activity log.

var watch: MarketWatch
var activity: RichTextLabel


func _ready() -> void:
	grab()
	theme_type_variation = "TableCard"


func grab() -> void:
	if watch != null:
		return
	watch = get_node("%Watch") as MarketWatch
	activity = get_node("%Activity") as RichTextLabel
	custom_minimum_size = Vector2(280, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
