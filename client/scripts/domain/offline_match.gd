extends RefCounted
class_name OfflineMatch

## Local deal and placement. Mirrors server/app/domain/offline.py.
## Placed cells stay unincorporated. Assumption A17.

var seed: int
var hand_size: int
var starting_cash: int
var players: Array = []
var bag: Array = []
var occupied: Dictionary = {}
var turn_index: int
var round_number: int
var log: Array[String] = []


static func create(seed_value: int, names: Array) -> OfflineMatch:
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	if rules == null:
		return null
	if seed_value < 0:
		return null
	var minimum := int(rules["players_min"])
	var maximum := int(rules["players_max"])
	if names.size() < minimum or names.size() > maximum:
		return null
	var seen := {}
	for name in names:
		var text := str(name)
		if not _nickname_ok(text) or seen.has(text):
			return null
		seen[text] = true
	var table := OfflineMatch.new()
	table.seed = seed_value
	table.hand_size = int(rules["starting_hand_size"])
	table.starting_cash = int(rules["starting_cash"])
	var rng := MatchRng.new(seed_value)
	var roster: Array = []
	for index in names.size():
		roster.append({
			"id": "p%d" % [index + 1],
			"display_name": str(names[index]),
			"hand": [],
		})
	table.players = MatchRng.shuffle(roster, rng)
	for index in table.players.size():
		table.players[index]["turn_order_index"] = index
		table.players[index]["cash"] = table.starting_cash
	var catalog: Array = []
	for coordinate in Coordinates.catalog():
		catalog.append(coordinate)
		table.occupied[coordinate] = false
	table.bag = MatchRng.shuffle(catalog, rng)
	for _round in range(table.hand_size):
		for player in table.players:
			if table.bag.is_empty():
				break
			player["hand"].append(table.bag[0])
			table.bag.remove_at(0)
	table.turn_index = 0
	table.round_number = 1
	return table


static func _nickname_ok(text: String) -> bool:
	if text.is_empty() or text.length() > 24:
		return false
	var first := text.unicode_at(0)
	if not _nickname_char(first, true):
		return false
	for index in range(1, text.length()):
		if not _nickname_char(text.unicode_at(index), false):
			return false
	return true


static func _nickname_char(code: int, first: bool) -> bool:
	var digit := code >= 48 and code <= 57
	var upper := code >= 65 and code <= 90
	var lower := code >= 97 and code <= 122
	if first:
		return digit or upper or lower
	return digit or upper or lower or code == 32 or code == 45 or code == 95


func active_player() -> Dictionary:
	return players[turn_index]


func place(coordinate: String) -> Dictionary:
	var player := active_player()
	var hand: Array = player["hand"]
	var found := hand.find(coordinate)
	if found == -1:
		return {"ok": false, "error": "tile not in hand"}
	if bool(occupied.get(coordinate, false)):
		return {"ok": false, "error": "cell occupied"}
	hand.remove_at(found)
	occupied[coordinate] = true
	var drew := false
	if not bag.is_empty():
		hand.append(bag[0])
		bag.remove_at(0)
		drew = true
	var message := ""
	if drew:
		message = "%s placed %s and drew from the bag." % [player["display_name"], coordinate]
	else:
		message = "%s placed %s. The bag is empty." % [player["display_name"], coordinate]
	log.append(message)
	_advance()
	return {"ok": true, "placed": coordinate, "drew": drew, "log": message}


func pass_turn() -> Dictionary:
	var player := active_player()
	var hand: Array = player["hand"]
	if not hand.is_empty():
		return {"ok": false, "error": "hand still has a tile"}
	var message := "%s has no tile to place." % player["display_name"]
	log.append(message)
	_advance()
	return {"ok": true, "passed": true, "log": message}


func _advance() -> void:
	turn_index += 1
	if turn_index >= players.size():
		turn_index = 0
		round_number += 1


func conservation() -> PackedStringArray:
	var hands: Array = []
	for player in players:
		hands.append(player["hand"])
	var filled: Array = []
	for coordinate in occupied.keys():
		if bool(occupied[coordinate]):
			filled.append(str(coordinate))
	return Tiles.conservation_errors(bag, hands, filled)
