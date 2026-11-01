extends PanelContainer
class_name PricePanel

## Share and BYTE prices, then the last few actions.

var watch: MarketWatch
var feed: ActionFeed


func _ready() -> void:
	grab()
	theme_type_variation = "TableCard"


func grab() -> void:
	if watch != null:
		return
	watch = get_node("%Watch") as MarketWatch
	feed = get_node("%Feed") as ActionFeed
	custom_minimum_size = Vector2(280, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
