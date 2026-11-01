extends SceneTree

var _failures: PackedStringArray = []


func _initialize() -> void:
	_check_rng()
	_check_deals()
	_check_placement()
	_check_rejections()
	_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("M1_CLIENT_OK")
		quit(0)
		return
	print("M1_CLIENT_FAIL %d" % _failures.size())
	for line in _failures:
		print(line)
	quit(1)


func _check_rng() -> void:
	var rng := MatchRng.new(1)
	if rng.next_u32() != 270369:
		_fail("rng literal %s" % str(rng.state))
	var golden = SharedFiles.read_json("fixtures/golden_rng.json")
	if golden == null:
		_fail("rng fixture missing")
		return
	for case in golden["cases"]:
		var generator := MatchRng.new(int(case["seed"]))
		var values: Array = case["values"]
		for index in values.size():
			var got := generator.next_u32()
			if got != int(values[index]):
				_fail("rng seed %s index %s got %s" % [str(case["seed"]), str(index), str(got)])
				return


func _check_deals() -> void:
	var rowan = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	if rowan == null or rowan.players[0]["hand"][0] != "C1":
		_fail("opening hand literal")
		return
	var swapped = OfflineMatch.create(2, ["Rowan", "Quinn"])
	if swapped.players[0]["display_name"] != "Quinn" or swapped.players[0]["id"] != "p2":
		_fail("seat swap")
	if swapped.players[0]["hand"][0] != "I9":
		_fail("swapped hand")
	var golden = SharedFiles.read_json("fixtures/golden_deals.json")
	if golden == null:
		_fail("deal fixture missing")
		return
	for case in golden["cases"]:
		var table = OfflineMatch.create(int(case["seed"]), case["names"])
		if table == null:
			_fail("deal create %s" % str(case["seed"]))
			continue
		var order: Array = case["turn_order"]
		if table.players.size() != order.size():
			_fail("deal size")
			continue
		for index in order.size():
			if table.players[index]["display_name"] != str(order[index]):
				_fail("order %s" % str(case["seed"]))
			if table.players[index]["id"] != str(case["ids"][index]):
				_fail("id %s" % str(case["seed"]))
			var expected_hand: Array = case["hands"][order[index]]
			var actual: Array = table.players[index]["hand"]
			if actual.size() != expected_hand.size():
				_fail("hand size %s" % str(order[index]))
				continue
			for tile_index in expected_hand.size():
				if str(actual[tile_index]) != str(expected_hand[tile_index]):
					_fail("hand %s %s" % [str(order[index]), str(case["seed"])])
					break
		if table.bag.size() != int(case["bag_size"]):
			_fail("bag size %s" % str(case["seed"]))
		var expected_bag: Array = case["bag"]
		if table.bag.size() == expected_bag.size():
			for index in expected_bag.size():
				if str(table.bag[index]) != str(expected_bag[index]):
					_fail("bag order %s at %s" % [str(case["seed"]), str(index)])
					break
		if table.conservation().size() != 0:
			_fail("deal conservation %s" % str(table.conservation()))
		if table.round_number != 1 or table.active_player()["display_name"] != str(case["active_player"]):
			_fail("opening seat %s" % str(case["seed"]))


func _check_placement() -> void:
	var golden = SharedFiles.read_json("fixtures/golden_placement.json")
	if golden == null:
		_fail("placement fixture missing")
		return
	var table = OfflineMatch.create(int(golden["seed"]), golden["names"])
	for step in golden["steps"]:
		var actor := str(table.active_player()["display_name"])
		var tile := str(table.active_player()["hand"][0])
		var result: Dictionary = table.place(tile)
		if not bool(result["ok"]) or actor != str(step["actor"]) or tile != str(step["placed"]):
			_fail("place %s" % tile)
			return
		if table.round_number != int(step["round_number"]):
			_fail("round")
		if table.active_player()["display_name"] != str(step["active_player"]):
			_fail("next player")
		if table.bag.size() != int(step["bag_size"]):
			_fail("bag after place")
		var occupied: Array = step["occupied"]
		for coordinate in occupied:
			if not bool(table.occupied[str(coordinate)]):
				_fail("missing occupied %s" % str(coordinate))
		for player_name in step["hands"].keys():
			var expected: Array = step["hands"][player_name]
			var actual := _hand_named(table, str(player_name))
			if actual.size() != expected.size():
				_fail("hand after %s" % str(player_name))
				continue
			for index in expected.size():
				if str(actual[index]) != str(expected[index]):
					_fail("tiles after %s" % str(player_name))
					break
		var expected_log: Array = step["log"]
		if table.log.size() != expected_log.size():
			_fail("log size")
		else:
			for index in expected_log.size():
				if table.log[index] != str(expected_log[index]):
					_fail("log %s" % table.log[index])
		if table.conservation().size() != 0:
			_fail("placement conservation")
	if table.round_number != 3 or table.active_player()["display_name"] != "Rowan":
		_fail("after four placements")


func _check_rejections() -> void:
	var rejected = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	var foreign: Dictionary = rejected.place("A1")
	if bool(foreign["ok"]) or str(foreign["error"]) != "tile not in hand":
		_fail("foreign tile")
	var early: Dictionary = rejected.pass_turn()
	if bool(early["ok"]) or str(early["error"]) != "hand still has a tile":
		_fail("early pass")
	if OfflineMatch.create(7710, ["Rowan"]) != null:
		_fail("one player accepted")
	if OfflineMatch.create(-3, ["Rowan", "Quinn"]) != null:
		_fail("negative seed accepted")
	var placed := 0
	var long_match = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	while placed < 12:
		var tile := str(long_match.active_player()["hand"][0])
		var result: Dictionary = long_match.place(tile)
		if not bool(result["ok"]):
			_fail("scripted run")
			return
		placed += 1
	if long_match.conservation().size() != 0:
		_fail("twelve conservation")
	if long_match.round_number != 7 or long_match.active_player()["display_name"] != "Rowan":
		_fail("twelve turns round %s player %s" % [str(long_match.round_number), long_match.active_player()["display_name"]])


func _hand_named(table: OfflineMatch, player_name: String) -> Array:
	for player in table.players:
		if str(player["display_name"]) == player_name:
			return player["hand"]
	return []
