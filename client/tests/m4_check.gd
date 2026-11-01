extends SceneTree

## Round events, final-round turns, and the scoreboard.


var _failed := false


func _initialize() -> void:
	_check_deck()
	if _failed:
		quit(1)
		return
	_check_round()
	if _failed:
		quit(1)
		return
	_check_clamp()
	if _failed:
		quit(1)
		return
	_check_size()
	if _failed:
		quit(1)
		return
	_check_empty()
	if _failed:
		quit(1)
		return
	_check_ties()
	if _failed:
		quit(1)
		return
	print("M4_CLIENT_OK")
	quit(0)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("M4_CLIENT_FAIL %s" % message)


func _check_deck() -> void:
	var golden = SharedFiles.read_json("fixtures/golden_events.json")
	var names: PackedStringArray = []
	for name in golden["names"]:
		names.append(str(name))
	var table = OfflineMatch.create(int(golden["seed"]), names)
	var again = OfflineMatch.create(int(golden["seed"]), names)
	var expected: Array = golden["deck"]
	if table.events.size() != expected.size():
		_fail("deck size")
		return
	for index in expected.size():
		if str(table.events[index]["id"]) != str(expected[index]):
			_fail("deck order")
			return
		if str(again.events[index]["id"]) != str(expected[index]):
			_fail("deck replay")
			return
	var eleven: Array = golden["eleven"]
	for _step in 11:
		table._apply_round_event()
	if table.event_ids.size() != eleven.size():
		_fail("eleven size")
		return
	for index in eleven.size():
		if str(table.event_ids[index]) != str(eleven[index]):
			_fail("reshuffle %s" % str(table.event_ids[index]))
			return


func _check_round() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	table.place("C1")
	_finish(table)
	if table.event_ids.size() != 0 or table.byte_price != 500:
		_fail("event fired early")
		return
	table.place("F8")
	_finish(table)
	var replay = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	replay.place("C1")
	_finish(replay)
	replay.place("F8")
	_finish(replay)
	if table.round_number != 2 or str(table.event_ids[0]) != "grid_incentives":
		_fail("round event")
		return
	if int(table.sentiment["energy"]) != 1 or table.byte_price != 450:
		_fail("grid incentives price")
		return
	if str(table.log[table.log.size() - 1]) != "Round event: Grid Incentives. Energy +1. BYTE is $450.":
		_fail("event log %s" % str(table.log[table.log.size() - 1]))
		return
	if str(table.log) != str(replay.log):
		_fail("replay log")


func _check_clamp() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	var file = SharedFiles.read_json("fixtures/round_events.json")
	var adoption: Dictionary = {}
	var regulation: Dictionary = {}
	for event in file["events"]:
		if str(event["id"]) == "ai_adoption":
			adoption = event
		elif str(event["id"]) == "fintech_regulation":
			regulation = event
	table.sentiment["ai"] = 2
	table.byte_price = 2000
	table.events = [adoption]
	table._apply_round_event()
	if int(table.sentiment["ai"]) != 2 or table.byte_price != 2000:
		_fail("upper clamp")
		return
	if not str(table.log[table.log.size() - 1]).contains("AI +2"):
		_fail("clamp log")
		return
	table.byte_price = 100
	table.events = [regulation]
	table._apply_round_event()
	if int(table.sentiment["fintech"]) != -1 or table.byte_price != 100:
		_fail("lower clamp")


func _check_size() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	var cells: Array[String] = []
	for row in range(1, 10):
		cells.append("A%d" % row)
		cells.append("B%d" % row)
	cells.append("C1")
	cells.append("C2")
	cells.append("C3")
	_paint(table, cells, "nova_ai")
	_pull(table, "C4")
	var grew: Dictionary = table.place("C4")
	if str(grew["resolution"]) != "growth":
		_fail("size 22 growth")
		return
	_finish(table)
	if not table.final_round or table.phase != "place" or table.event_ids.size() != 0:
		_fail("final round should wait")
		return
	if str(table.active_player()["display_name"]) != "Quinn":
		_fail("quinn still plays")
		return
	_drain(table)
	table.pass_turn()
	_finish(table)
	if table.phase != "completed" or table.event_ids.size() != 1 or table.round_number != 1:
		_fail("scored too early or twice")
		return
	if str(table.log[table.log.size() - 1]) != "Rowan wins with $6000 fictional.":
		_fail("size winner %s" % str(table.log[table.log.size() - 1]))
		return
	var blocked: Dictionary = table.pass_turn()
	if bool(blocked["ok"]) or str(blocked["error"]) != "the match is over":
		_fail("completed match accepted a turn")


func _check_empty() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_fill(table)
	table.pass_turn()
	_finish(table)
	if not table.final_round or table.event_ids.size() != 0:
		_fail("empty supply should wait for the last seat")
		return
	table.pass_turn()
	_finish(table)
	if table.phase != "completed" or str(table.ranking[0]) != "p1":
		_fail("empty ranking")
		return
	if int(_row(table, "p1")["net_worth"]) != 6000 or int(_row(table, "p2")["net_worth"]) != 6000:
		_fail("empty nets")


func _check_ties() -> void:
	var richer = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	richer.players[1]["cash"] = 7000
	_fill(richer)
	_finish_both(richer)
	if str(richer.ranking[0]) != "p2" or int(_row(richer, "p2")["net_worth"]) != 7000:
		_fail("cash ranking")
		return
	var shares = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_paint(shares, ["A1", "A2"], "nova_ai")
	var orbit: Array[String] = []
	for row in range(1, 7):
		orbit.append("C%d" % row)
	_paint(shares, orbit, "orbit_pay")
	_assign(shares, "nova_ai", {"p2": 2})
	_assign(shares, "orbit_pay", {"p1": 1})
	shares.final_round = true
	_finish_both(shares)
	if str(shares.ranking[0]) != "p2":
		_fail("share-count ranking")
		return
	var quinn: Dictionary = _row(shares, "p2")
	if int(quinn["active_shares"]) != 2 or int(quinn["net_worth"]) != int(_row(shares, "p1")["net_worth"]):
		_fail("share tie values")
		return
	if shares.economy_errors().size() != 0:
		_fail("share tie economy %s" % str(shares.economy_errors()))


func _finish(table: OfflineMatch) -> void:
	while table.phase == "market":
		table.pass_market()


func _finish_both(table: OfflineMatch) -> void:
	var guard := 0
	while table.phase != "completed" and guard < 8:
		guard += 1
		if table.phase == "market":
			_finish(table)
			continue
		_drain(table)
		table.pass_turn()


func _drain(table: OfflineMatch) -> void:
	var hand: Array = table.active_player()["hand"]
	while not hand.is_empty():
		table.bag.append(hand[0])
		hand.remove_at(0)


func _fill(table: OfflineMatch) -> void:
	for player in table.players:
		var hand: Array = player["hand"]
		while not hand.is_empty():
			var cell := str(hand[0])
			hand.remove_at(0)
			if not bool(table.occupied[cell]):
				table.occupied[cell] = true
	while not table.bag.is_empty():
		var cell := str(table.bag[0])
		table.bag.remove_at(0)
		if not bool(table.occupied[cell]):
			table.occupied[cell] = true


func _pull(table: OfflineMatch, coordinate: String) -> void:
	var player: Dictionary = table.active_player()
	var hand: Array = player["hand"]
	if hand.find(coordinate) != -1:
		return
	var index := table.bag.find(coordinate)
	if index == -1:
		_fail("missing %s" % coordinate)
		return
	if hand.size() >= 5:
		table.bag.append(hand[0])
		hand.remove_at(0)
	hand.append(coordinate)
	table.bag.remove_at(index)


func _paint(table: OfflineMatch, cells: Array, corp_id: String) -> void:
	for cell in cells:
		var coordinate := str(cell)
		var found := false
		for player in table.players:
			var hand: Array = player["hand"]
			var index := hand.find(coordinate)
			if index != -1:
				hand.remove_at(index)
				found = true
				break
		if not found:
			table.bag.remove_at(table.bag.find(coordinate))
		table.occupied[coordinate] = true
		table.company_of[coordinate] = corp_id
	table._reprice(_corp(table, corp_id))


func _corp(table: OfflineMatch, corp_id: String) -> Dictionary:
	for corp in table.corporations:
		if str(corp["id"]) == corp_id:
			return corp
	return {}


func _assign(table: OfflineMatch, corp_id: String, counts: Dictionary) -> void:
	var outstanding := 0
	for player in table.players:
		var count := int(counts.get(str(player["id"]), 0))
		player["shares"][corp_id] = count
		outstanding += count
	var corp := _corp(table, corp_id)
	corp["bank_shares"] = table.share_supply - outstanding


func _row(table: OfflineMatch, player_id: String) -> Dictionary:
	for row in table.ledger:
		if str(row["id"]) == player_id:
			return row
	return {}
