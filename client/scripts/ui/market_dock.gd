extends PanelContainer
class_name MarketDock

## Bottom HUD for the hand and the market. The table listens to signals.
## It does not touch the match.

signal place_pressed
signal pass_market_pressed

var title_label: Label
var detail_label: Label
var hand_note: Label
var steps: HBoxContainer
var hand: HBoxContainer
var trades: ScrollContainer
var actions: HBoxContainer
var place_button: Button
var finish_button: Button


func _ready() -> void:
	grab()
	theme_type_variation = "MarketDock"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	if not place_button.pressed.is_connected(_emit_place):
		place_button.pressed.connect(_emit_place)
	if not finish_button.pressed.is_connected(_emit_pass):
		finish_button.pressed.connect(_emit_pass)


func grab() -> void:
	if title_label != null:
		return
	title_label = get_node("%Title") as Label
	detail_label = get_node("%Detail") as Label
	hand_note = get_node("%HandNote") as Label
	steps = get_node("%Steps") as HBoxContainer
	hand = get_node("%Hand") as HBoxContainer
	trades = get_node("%Trades") as ScrollContainer
	actions = get_node("%Actions") as HBoxContainer
	place_button = get_node("%Place") as Button
	finish_button = get_node("%Finish") as Button


func _emit_place() -> void:
	place_pressed.emit()


func _emit_pass() -> void:
	pass_market_pressed.emit()
