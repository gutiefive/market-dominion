extends RefCounted
class_name OfflineMatch

## Local deal, founding, growth, mergers, and two market actions.
## Assumption A19: the largest pre-placement company survives. A tie waits
## for the placer. Losers are bought out in fixture order, then the survivor
## is repriced once.
## Assumption A20: the event deck is shuffled after the deal. One event is
## applied when a round completes. A final round scores instead of starting
## another round.

var seed: int
var hand_size: int
var starting_cash: int
var market_limit: int
var share_supply: int
var byte_supply: int
var byte_price: int
var byte_exchange: int
var sentiment: Dictionary = {}
var corporations: Array = []
var players: Array = []
var bag: Array = []
var occupied: Dictionary = {}
var company_of: Dictionary = {}
var turn_index: int
var round_number: int
var phase: String = "place"
var final_round := false
var market_actions_left: int
var pending: Array = []
var pending_options: Array[String] = []
var pending_tile := ""
var events: Array = []
var event_ids: Array[String] = []
var rng: MatchRng
var ranking: Array[String] = []
var ledger: Array = []
var end_size: int
var end_occupied: int
var log: Array[String] = []


static func create(seed_value: int, names: Array) -> OfflineMatch:
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	var roster_file = SharedFiles.read_json("fixtures/corporations.json")
	if rules == null or roster_file == null or seed_value < 0:
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
	table.market_limit = int(rules["market_actions_per_turn"])
	table.share_supply = int(rules["corporation_share_supply"])
	table.byte_supply = int(rules["byte_supply"])
	table.byte_price = int(rules["byte_initial_price"])
	table.byte_exchange = table.byte_supply
	table.end_size = int(rules["end_company_size"])
	table.end_occupied = int(rules["end_occupied_tiles"])
	var share_template := {}
	for sector in rules["sectors"]:
		table.sentiment[str(sector)] = 0
	for source in roster_file["corporations"]:
		var corp_id := str(source["id"])
		table.corporations.append({
			"id": corp_id,
			"name": str(source["name"]),
			"sector": str(source["sector"]),
			"active": false,
			"bank_shares": table.share_supply,
			"share_price": 0,
			"size": 0,
			"cells": [],
		})
		share_template[corp_id] = 0
	var rng := MatchRng.new(seed_value)
	var roster: Array = []
	for index in names.size():
		roster.append({
			"id": "p%d" % [index + 1],
			"display_name": str(names[index]),
			"hand": [],
			"shares": share_template.duplicate(true),
			"byte_count": 0,
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
	var deck: Array = []
	var event_file = SharedFiles.read_json("fixtures/round_events.json")
	for event in event_file["events"]:
		deck.append((event as Dictionary).duplicate(true))
	table.rng = rng
	table.events = MatchRng.shuffle(deck, rng)
	table.turn_index = 0
	table.round_number = 1
	table.phase = "place"
	table.final_round = false
	table.market_actions_left = 0
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
	if phase == "completed":
		return {"ok": false, "error": "the match is over"}
	if phase != "place":
		return {"ok": false, "error": "not the placement step"}
	var player := active_player()
	var hand: Array = player["hand"]
	if hand.find(coordinate) == -1:
		return {"ok": false, "error": "tile not in hand"}
	if bool(occupied.get(coordinate, false)):
		return {"ok": false, "error": "cell occupied"}
	var filled := {}
	for cell in occupied.keys():
		if bool(occupied[cell]):
			filled[str(cell)] = true
	filled[coordinate] = true
	var touched := BoardGraph.component(coordinate, filled)
	var company_ids: Array[String] = []
	for cell in touched:
		var corp_id := str(company_of.get(str(cell), ""))
		if corp_id != "" and not company_ids.has(corp_id):
			company_ids.append(corp_id)
	hand.remove_at(hand.find(coordinate))
	occupied[coordinate] = true
	if company_ids.size() >= 2:
		var involved: Array = []
		for corp in corporations:
			if company_ids.has(str(corp["id"])):
				involved.append(corp)
		return _begin_merger(coordinate, player, touched, involved)
	if company_ids.size() == 1:
		var grown = _corp(company_ids[0])
		for cell in touched:
			company_of[str(cell)] = grown["id"]
		_reprice(grown)
		_enter_market()
		var growth_message := "%s placed %s and grew %s to size %d. Share price is $%d." % [
			player["display_name"], coordinate, grown["name"], int(grown["size"]), int(grown["share_price"])
		]
		log.append(growth_message)
		return {"ok": true, "placed": coordinate, "resolution": "growth", "log": growth_message}
	if touched.size() >= 2 and not _inactive().is_empty():
		pending = []
		for cell in touched:
			pending.append(str(cell))
		phase = "choose_founder"
		var choice_message := "%s placed %s. Choose a company for the %d-district cluster." % [
			player["display_name"], coordinate, touched.size()
		]
		log.append(choice_message)
		return {"ok": true, "placed": coordinate, "resolution": "choose_founder", "log": choice_message}
	var message := ""
	if touched.size() >= 2:
		message = "%s placed %s. The %d-district cluster stays unincorporated." % [
			player["display_name"], coordinate, touched.size()
		]
	else:
		message = "%s placed %s. The district stays unincorporated." % [player["display_name"], coordinate]
	_enter_market()
	log.append(message)
	return {"ok": true, "placed": coordinate, "resolution": "unincorporated", "log": message}


func choose_founder(corp_id: String) -> Dictionary:
	if phase == "completed":
		return {"ok": false, "error": "the match is over"}
	if phase != "choose_founder":
		return {"ok": false, "error": "no company choice is pending"}
	var corp := _corp(corp_id)
	if corp.is_empty():
		return {"ok": false, "error": "unknown company"}
	if bool(corp["active"]):
		return {"ok": false, "error": "company is already active"}
	var player := active_player()
	for cell in pending:
		company_of[str(cell)] = corp["id"]
	pending = []
	pending_options = []
	pending_tile = ""
	_reprice(corp)
	var granted := false
	if int(corp["bank_shares"]) > 0:
		corp["bank_shares"] = int(corp["bank_shares"]) - 1
		var shares: Dictionary = player["shares"]
		shares[corp["id"]] = int(shares[corp["id"]]) + 1
		granted = true
	_enter_market()
	var message := ""
	if granted:
		message = "%s founded %s on %d districts and received one founder share." % [
			player["display_name"], corp["name"], int(corp["size"])
		]
	else:
		message = "%s founded %s on %d districts. The bank had no share to grant." % [
			player["display_name"], corp["name"], int(corp["size"])
		]
	log.append(message)
	return {"ok": true, "founded": corp["id"], "granted": granted, "log": message}


func choose_survivor(corp_id: String) -> Dictionary:
	if phase == "completed":
		return {"ok": false, "error": "the match is over"}
	if phase != "choose_survivor":
		return {"ok": false, "error": "no survivor choice is pending"}
	var corp := _corp(corp_id)
	if corp.is_empty():
		return {"ok": false, "error": "unknown company"}
	if not pending_options.has(corp_id):
		return {"ok": false, "error": "company is not a tied survivor"}
	return _resolve_merger(corp_id, pending_tile, active_player(), true)


func pass_turn() -> Dictionary:
	if phase == "completed":
		return {"ok": false, "error": "the match is over"}
	if phase != "place":
		return {"ok": false, "error": "not the placement step"}
	var player := active_player()
	var hand: Array = player["hand"]
	if not hand.is_empty():
		return {"ok": false, "error": "hand still has a tile"}
	var message := "%s has no tile to place." % player["display_name"]
	log.append(message)
	_enter_market()
	return {"ok": true, "passed": true, "log": message}


func buy_share(corp_id: String) -> Dictionary:
	var opened: Dictionary = _open_share_trade(corp_id)
	if not bool(opened["ok"]):
		return opened
	var player: Dictionary = opened["player"]
	var corp: Dictionary = opened["corp"]
	var price := int(opened["price"])
	if int(corp["bank_shares"]) < 1:
		return {"ok": false, "error": "no share in the bank"}
	if int(player["cash"]) < price:
		return {"ok": false, "error": "not enough cash"}
	player["cash"] = int(player["cash"]) - price
	corp["bank_shares"] = int(corp["bank_shares"]) - 1
	var shares: Dictionary = player["shares"]
	shares[corp["id"]] = int(shares[corp["id"]]) + 1
	return _spend_action("%s bought 1 %s share for $%d." % [player["display_name"], corp["name"], price])


func sell_share(corp_id: String) -> Dictionary:
	var opened: Dictionary = _open_share_trade(corp_id)
	if not bool(opened["ok"]):
		return opened
	var player: Dictionary = opened["player"]
	var corp: Dictionary = opened["corp"]
	var price := int(opened["price"])
	var shares: Dictionary = player["shares"]
	if int(shares[corp["id"]]) < 1:
		return {"ok": false, "error": "no share to sell"}
	shares[corp["id"]] = int(shares[corp["id"]]) - 1
	corp["bank_shares"] = int(corp["bank_shares"]) + 1
	player["cash"] = int(player["cash"]) + price
	return _spend_action("%s sold 1 %s share for $%d." % [player["display_name"], corp["name"], price])


func buy_byte() -> Dictionary:
	var player = _open_market()
	if player == null:
		return {"ok": false, "error": _market_error()}
	if byte_exchange < 1:
		return {"ok": false, "error": "no BYTE in the exchange"}
	if int(player["cash"]) < byte_price:
		return {"ok": false, "error": "not enough cash"}
	player["cash"] = int(player["cash"]) - byte_price
	player["byte_count"] = int(player["byte_count"]) + 1
	byte_exchange -= 1
	return _spend_action("%s bought 1 BYTE for $%d." % [player["display_name"], byte_price])


func sell_byte() -> Dictionary:
	var player = _open_market()
	if player == null:
		return {"ok": false, "error": _market_error()}
	if int(player["byte_count"]) < 1:
		return {"ok": false, "error": "no BYTE to sell"}
	player["byte_count"] = int(player["byte_count"]) - 1
	player["cash"] = int(player["cash"]) + byte_price
	byte_exchange += 1
	return _spend_action("%s sold 1 BYTE for $%d." % [player["display_name"], byte_price])


func pass_market() -> Dictionary:
	var player = _open_market()
	if player == null:
		return {"ok": false, "error": _market_error()}
	return _spend_action("%s passed a market action." % player["display_name"])


func economy_errors() -> PackedStringArray:
	var errors := conservation()
	var catalog := Coordinates.catalog()
	var filled := {}
	for cell in occupied.keys():
		if bool(occupied[cell]):
			filled[str(cell)] = true
	var holdings := {}
	for corp in corporations:
		holdings[str(corp["id"])] = 0
	var byte_held := 0
	for player in players:
		if int(player["cash"]) < 0:
			errors.append("negative cash:%s" % player["id"])
		if int(player["byte_count"]) < 0:
			errors.append("negative byte:%s" % player["id"])
		byte_held += int(player["byte_count"])
		var shares: Dictionary = player["shares"]
		for corp_id in shares.keys():
			if int(shares[corp_id]) < 0:
				errors.append("negative shares:%s:%s" % [player["id"], str(corp_id)])
			holdings[str(corp_id)] = int(holdings.get(str(corp_id), 0)) + int(shares[corp_id])
	if byte_exchange + byte_held != byte_supply:
		errors.append("byte supply")
	if byte_exchange < 0:
		errors.append("negative exchange")
	for corp in corporations:
		var corp_id := str(corp["id"])
		var cells: Array[String] = []
		for cell in catalog:
			if str(company_of.get(str(cell), "")) == corp_id:
				cells.append(str(cell))
		var stored: Array = corp["cells"]
		if stored.size() != cells.size():
			errors.append("%s: cells" % corp_id)
		else:
			for index in cells.size():
				if str(stored[index]) != cells[index]:
					errors.append("%s: cells" % corp_id)
					break
		if int(corp["size"]) != cells.size():
			errors.append("%s: size" % corp_id)
		var outstanding := int(holdings.get(corp_id, 0))
		if int(corp["bank_shares"]) + outstanding != share_supply:
			errors.append("%s: supply" % corp_id)
		if int(corp["bank_shares"]) < 0:
			errors.append("%s: negative bank" % corp_id)
		var expected_price := 0
		if not cells.is_empty():
			expected_price = Pricing.share_price(cells.size(), int(sentiment[str(corp["sector"])]))
		if int(corp["share_price"]) != expected_price:
			errors.append("%s: price" % corp_id)
		if bool(corp["active"]) != (cells.size() >= 2):
			errors.append("%s: active flag" % corp_id)
		if not bool(corp["active"]) and (not cells.is_empty() or outstanding != 0 or int(corp["bank_shares"]) != share_supply):
			errors.append("%s: inactive inventory" % corp_id)
	var seen := {}
	for coordinate in catalog:
		if not filled.has(str(coordinate)) or seen.has(str(coordinate)):
			continue
		var touched := BoardGraph.component(str(coordinate), filled)
		for cell in touched:
			seen[str(cell)] = true
		var present: Array[String] = []
		for cell in touched:
			var owner := str(company_of.get(str(cell), ""))
			if owner != "" and not present.has(owner):
				present.append(owner)
		if present.size() > 1 and not (phase == "choose_survivor" and _same_cells(touched, pending)):
			errors.append("mixed:%s" % ",".join(present))
	for cell in company_of.keys():
		if not bool(occupied.get(str(cell), false)):
			errors.append("empty company cell:%s" % str(cell))
	return errors


func conservation() -> PackedStringArray:
	var hands: Array = []
	for player in players:
		hands.append(player["hand"])
	var filled: Array = []
	for coordinate in occupied.keys():
		if bool(occupied[coordinate]):
			filled.append(str(coordinate))
	return Tiles.conservation_errors(bag, hands, filled)


func _corp(corp_id: String) -> Dictionary:
	for corp in corporations:
		if str(corp["id"]) == corp_id:
			return corp
	return {}


func _inactive() -> Array:
	var open: Array = []
	for corp in corporations:
		if not bool(corp["active"]):
			open.append(corp)
	return open


func _reprice(corp: Dictionary) -> void:
	var cells: Array = []
	for cell in Coordinates.catalog():
		if str(company_of.get(str(cell), "")) == str(corp["id"]):
			cells.append(str(cell))
	corp["cells"] = cells
	corp["size"] = cells.size()
	corp["active"] = cells.size() >= 2
	if bool(corp["active"]):
		corp["share_price"] = Pricing.share_price(cells.size(), int(sentiment[str(corp["sector"])]))
	else:
		corp["share_price"] = 0


func _same_cells(touched: PackedStringArray, pending_cells: Array) -> bool:
	if touched.size() != pending_cells.size():
		return false
	for cell in touched:
		if pending_cells.find(str(cell)) == -1:
			return false
	return true


func _begin_merger(coordinate: String, player: Dictionary, touched: PackedStringArray, involved: Array) -> Dictionary:
	var top := 0
	for corp in involved:
		top = maxi(top, int(corp["size"]))
	var tied: Array = []
	for corp in involved:
		if int(corp["size"]) == top:
			tied.append(corp)
	pending = []
	for cell in touched:
		pending.append(str(cell))
	pending_tile = coordinate
	if tied.size() > 1:
		pending_options = []
		for corp in tied:
			pending_options.append(str(corp["id"]))
		phase = "choose_survivor"
		var names: PackedStringArray = []
		for corp in tied:
			names.append(str(corp["name"]))
		var message := "%s placed %s. Choose the survivor. %s are tied at size %d." % [
			player["display_name"], coordinate, _join_names(names), top
		]
		log.append(message)
		return {"ok": true, "placed": coordinate, "resolution": "choose_survivor", "log": message}
	pending_options = []
	pending_options.append(str(tied[0]["id"]))
	return _resolve_merger(str(tied[0]["id"]), coordinate, player, false)


func _resolve_merger(survivor_id: String, coordinate: String, player: Dictionary, chosen: bool) -> Dictionary:
	var involved_ids: Array[String] = []
	for cell in pending:
		var owner := str(company_of.get(str(cell), ""))
		if owner != "" and not involved_ids.has(owner):
			involved_ids.append(owner)
	var losers: Array = []
	for corp in corporations:
		var corp_id := str(corp["id"])
		if involved_ids.has(corp_id) and corp_id != survivor_id:
			losers.append(corp)
	var snapshots := {}
	for corp in losers:
		var holdings := {}
		for holder in players:
			holdings[str(holder["id"])] = int(holder["shares"][str(corp["id"])])
		snapshots[str(corp["id"])] = {"price": int(corp["share_price"]), "holdings": holdings}
	var loser_ids := {}
	for corp in losers:
		loser_ids[str(corp["id"])] = true
	for cell in pending:
		company_of[str(cell)] = survivor_id
	var leftovers: Array[String] = []
	for cell in company_of.keys():
		if loser_ids.has(str(company_of[cell])):
			leftovers.append(str(cell))
	for cell in leftovers:
		company_of.erase(cell)
	var messages: Array[String] = []
	var ordered: Array = []
	for holder in players:
		var placed := false
		for index in ordered.size():
			if str(holder["id"]) < str(ordered[index]["id"]):
				ordered.insert(index, holder)
				placed = true
				break
		if not placed:
			ordered.append(holder)
	for corp in losers:
		var corp_id := str(corp["id"])
		var price := int(snapshots[corp_id]["price"])
		var holdings: Dictionary = snapshots[corp_id]["holdings"]
		var payouts := Mergers.bonus_payouts(price, holdings)
		var any_holder := false
		for count in holdings.values():
			if int(count) > 0:
				any_holder = true
		if not any_holder:
			messages.append("%s paid no merger bonus." % str(corp["name"]))
		else:
			for holder in ordered:
				var amount := int(payouts.get(str(holder["id"]), 0))
				if amount <= 0:
					continue
				holder["cash"] = int(holder["cash"]) + amount
				messages.append("%s received a $%d bonus on %s." % [holder["display_name"], amount, str(corp["name"])])
		for holder in ordered:
			var count := int(holdings[str(holder["id"])])
			if count <= 0:
				continue
			var proceeds := count * price
			var shares: Dictionary = holder["shares"]
			shares[corp_id] = 0
			holder["cash"] = int(holder["cash"]) + proceeds
			messages.append("%s liquidated %d %s shares for $%d." % [
				holder["display_name"], count, str(corp["name"]), proceeds
			])
		corp["bank_shares"] = share_supply
		_reprice(corp)
	var survivor := _corp(survivor_id)
	_reprice(survivor)
	pending = []
	pending_options = []
	pending_tile = ""
	_enter_market()
	var summary := ""
	if chosen:
		summary = "%s kept %s. %s is size %d. Share price is $%d." % [
			player["display_name"], survivor["name"], survivor["name"], int(survivor["size"]), int(survivor["share_price"])
		]
	else:
		summary = "%s placed %s. %s survives the merger at size %d. Share price is $%d." % [
			player["display_name"], coordinate, survivor["name"], int(survivor["size"]), int(survivor["share_price"])
		]
	log.append(summary)
	for line in messages:
		log.append(line)
	return {"ok": true, "placed": coordinate, "resolution": "merger", "survivor": survivor_id, "log": summary}


func _join_names(names: PackedStringArray) -> String:
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var head := ""
	for index in range(names.size() - 1):
		if index > 0:
			head += ", "
		head += names[index]
	return "%s, and %s" % [head, names[names.size() - 1]]


func _enter_market() -> void:
	phase = "market"
	market_actions_left = market_limit


func _market_error() -> String:
	if phase == "completed":
		return "the match is over"
	if phase != "market":
		return "not the market step"
	return "no market action left"


func _open_market():
	if phase != "market" or market_actions_left <= 0:
		return null
	return active_player()


func _open_share_trade(corp_id: String) -> Dictionary:
	var player = _open_market()
	if player == null:
		return {"ok": false, "error": _market_error()}
	var corp := _corp(corp_id)
	if corp.is_empty():
		return {"ok": false, "error": "unknown company"}
	if not bool(corp["active"]) or int(corp["share_price"]) <= 0:
		return {"ok": false, "error": "company is not active"}
	return {"ok": true, "player": player, "corp": corp, "price": int(corp["share_price"])}


func _spend_action(message: String) -> Dictionary:
	log.append(message)
	market_actions_left -= 1
	var finished := false
	if market_actions_left == 0:
		_finish_turn()
		finished = true
	return {"ok": true, "log": message, "turn_finished": finished}


func _finish_turn() -> void:
	var player := active_player()
	if not bag.is_empty():
		player["hand"].append(bag[0])
		bag.remove_at(0)
		log.append("%s drew from the bag." % player["display_name"])
	else:
		log.append("%s drew nothing. The bag is empty." % player["display_name"])
	phase = "place"
	market_actions_left = 0
	pending = []
	pending_options = []
	pending_tile = ""
	var closing := turn_index + 1 >= players.size()
	if not final_round and _end_triggered():
		final_round = true
		if closing:
			log.append("Final round. The round is complete.")
		else:
			log.append("Final round. Everyone who has not acted this round still takes one turn.")
	turn_index += 1
	if turn_index >= players.size():
		turn_index = 0
		_apply_round_event()
		if final_round:
			_score_game()
			return
		round_number += 1


func _end_triggered() -> bool:
	for corp in corporations:
		if bool(corp["active"]) and int(corp["size"]) >= end_size:
			return true
	var occupied_count := 0
	for filled in occupied.values():
		if bool(filled):
			occupied_count += 1
	if occupied_count >= end_occupied:
		return true
	if not bag.is_empty():
		return false
	for player in players:
		if not (player["hand"] as Array).is_empty():
			return false
	return true


func _apply_round_event() -> void:
	if events.is_empty():
		var deck: Array = []
		var event_file = SharedFiles.read_json("fixtures/round_events.json")
		for event in event_file["events"]:
			deck.append((event as Dictionary).duplicate(true))
		events = MatchRng.shuffle(deck, rng)
	var drawn: Dictionary = events[0]
	events.remove_at(0)
	event_ids.append(str(drawn["id"]))
	var updated := SectorEvents.apply_sector_deltas(sentiment, drawn["sector_deltas"])
	sentiment = updated
	for corp in corporations:
		_reprice(corp)
	byte_price = Pricing.byte_price_after_delta(byte_price, int(drawn["byte_delta_percent"]))
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	var parts: PackedStringArray = []
	var deltas: Dictionary = drawn["sector_deltas"]
	for sector in rules["sectors"]:
		var key := str(sector)
		if not deltas.has(key):
			continue
		var value := int(sentiment[key])
		var shown := "+%d" % value if value > 0 else str(value)
		parts.append("%s %s" % [_sector_label(key), shown])
	log.append("Round event: %s. %s. BYTE is $%d." % [str(drawn["name"]), ", ".join(parts), byte_price])


func _score_game() -> void:
	var rows: Array = []
	for player in players:
		var holdings: Array = []
		var share_value := 0
		var active_shares := 0
		var shares: Dictionary = player["shares"]
		for corp in corporations:
			var count := int(shares[str(corp["id"])])
			if not bool(corp["active"]) or count <= 0:
				continue
			var value := count * int(corp["share_price"])
			active_shares += count
			share_value += value
			holdings.append({
				"id": str(corp["id"]),
				"name": str(corp["name"]),
				"count": count,
				"price": int(corp["share_price"]),
				"value": value,
			})
		var byte_count := int(player["byte_count"])
		var byte_value := byte_count * byte_price
		var net_worth := int(player["cash"]) + share_value + byte_value
		rows.append({
			"id": str(player["id"]),
			"display_name": str(player["display_name"]),
			"cash": int(player["cash"]),
			"share_value": share_value,
			"active_shares": active_shares,
			"byte_count": byte_count,
			"byte_value": byte_value,
			"net_worth": net_worth,
			"turn_order_index": int(player["turn_order_index"]),
			"holdings": holdings,
		})
	ranking.clear()
	for player_id in Ranking.rank_players(rows):
		ranking.append(str(player_id))
	ledger = rows
	phase = "completed"
	market_actions_left = 0
	var winner_name := ""
	var winner_net := 0
	for row in rows:
		if str(row["id"]) == str(ranking[0]):
			winner_name = str(row["display_name"])
			winner_net = int(row["net_worth"])
	log.append("%s wins with $%d fictional." % [winner_name, winner_net])


func _sector_label(sector: String) -> String:
	match sector:
		"ai":
			return "AI"
		"fintech":
			return "Fintech"
		"energy":
			return "Energy"
		"media":
			return "Media"
		"retail":
			return "Retail"
	return sector
