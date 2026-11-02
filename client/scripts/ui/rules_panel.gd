extends Control
class_name RulesPanel

## Short original tutorial. Not a copy of any published board-game rulebook.

signal closed

const SECTION_TITLES: PackedStringArray = [
	"A turn",
	"Glossary",
	"Why prices change",
	"Merger payouts",
]


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.12, 0.78)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Palette.flat(Palette.CARD, Palette.LINE, 1, 10))
	margin.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title := _line("How Market Dominion plays", 22, Palette.TEXT)
	box.add_child(title)
	box.add_child(_line("Fictional dollars only. Keys: 1–5 choose a tile, Enter places it, arrow keys move along the hand, R opens this panel, Esc closes it, [ and ] change text size, M toggles reduced motion.", 14, Palette.MUTED))
	box.add_child(_line(SECTION_TITLES[0], 18, Palette.AMBER))
	box.add_child(_line("1. Place one tile from your hand onto the matching empty cell, or skip when the hand is empty.\n2. Resolve a founding, growth, or a merger before anyone trades.\n3. Take up to two market actions, or pass them.\n4. Draw back toward five tiles. After every seat has finished, one event card is drawn.", 14, Palette.TEXT))
	box.add_child(_line("A chain, drawn with symbols rather than color alone:", 14, Palette.MUTED))
	box.add_child(_line("A1 —— A2 —— A3\n◆ NA   ◆ NA   ◆ NA\nThree orthogonal districts. Diagonals do not connect.", 16, Palette.TEAL))
	box.add_child(_line(SECTION_TITLES[1], 18, Palette.AMBER))
	box.add_child(_line("Tile — a coordinate still in a hand. Bag — tiles not dealt and not on the board. Chain — orthogonal occupied cells. Found — turn a chain of size 2+ into a company and take one founder share when the bank has one. Bank — shares not held by a player. BYTE — the only coin. 30 exist. Sentiment — a sector score from −2 to +2. Final round — one last turn for seats that have not acted, then the ledger.", 14, Palette.TEXT))
	box.add_child(_line(SECTION_TITLES[2], 18, Palette.AMBER))
	box.add_child(_line("A new company's posted price starts at $100 + $50 × size, before sentiment. Sentiment then moves that price in 10% steps. The result is rounded to the nearest $10. Events add or subtract 1 from the sectors they name, never past −2 or +2, and they also move BYTE by −20%, −10%, +10%, or +20% from its previous price, again to the nearest $10. BYTE opens at $500.\nA trade uses the price already on the watchlist. Buying or selling does not change sentiment or the posted price. Founding, growth, a merger, and a round event do reprice. Growth absorbs connected unincorporated districts and reprices once. Size is the number of districts the company holds.", 14, Palette.TEXT))
	box.add_child(_line(SECTION_TITLES[3], 18, Palette.AMBER))
	box.add_child(_line("The largest company in the chain, measured before the new tile, survives. A tie among those largest companies waits for the player who placed the tile. Smaller companies in that chain are bought out.\nFor each company that does not survive, the majority pool is 2 × its price and the minority pool is 1 × its price. One holder of the most shares receives both pools. A tie for the most shares splits the combined pools. Otherwise the minority pool goes to the tied second place. Leftover $1 bills are dealt one at a time by ascending player id.\nAfter the bonus, every losing share is sold back to the bank at that same snapshotted price. The survivor is repriced once. Inactive shares are worth nothing at the end.", 14, Palette.TEXT))
	var close_button := Button.new()
	close_button.text = "Close rules"
	close_button.custom_minimum_size.y = 44
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(hide_panel)
	Palette.remember(close_button, 15)
	box.add_child(close_button)
	DialogFocus.install(self)


func show_panel() -> void:
	visible = true
	set_anchors_preset(PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	move_to_front()


func hide_panel() -> void:
	visible = false
	closed.emit()


func _line(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.remember(label, size)
	return label
