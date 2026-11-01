extends SceneTree

var _failures: PackedStringArray = []


func _initialize() -> void:
	_check_engine()
	_check_coordinates()
	_check_prices()
	_check_byte()
	_check_sentiment()
	_check_ranking()
	_check_tiles()
	_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("M0_CLIENT_OK")
		quit(0)
		return
	print("M0_CLIENT_FAIL %d" % _failures.size())
	for line in _failures:
		print(line)
	quit(1)


func _check_engine() -> void:
	# `godot --version` prints 4.7.2.stable.official.ed1daf0bf.
	# Engine.get_version_info() stores the same build as separate fields.
	var info := Engine.get_version_info()
	if int(info["major"]) != 4 or int(info["minor"]) != 7 or int(info["patch"]) != 2:
		_fail("engine version %s" % str(info))
	if str(info["status"]) != "stable":
		_fail("engine status %s" % str(info["status"]))
	if not str(info["hash"]).begins_with("ed1daf0bf"):
		_fail("engine hash %s" % str(info["hash"]))


func _check_coordinates() -> void:
	var catalog := Coordinates.catalog()
	var fixture = SharedFiles.read_json("fixtures/coordinates.json")
	if fixture == null:
		_fail("coordinates fixture missing")
		return
	if catalog.size() != 81 or fixture.size() != 81:
		_fail("coordinate count %d %d" % [catalog.size(), fixture.size()])
		return
	if catalog[0] != "A1" or catalog[1] != "B1" or catalog[8] != "I1" or catalog[9] != "A2" or catalog[80] != "I9":
		_fail("coordinate endpoints")
	var seen := {}
	for index in catalog.size():
		if catalog[index] != str(fixture[index]):
			_fail("coordinate mismatch at %d" % index)
			return
		if seen.has(catalog[index]):
			_fail("duplicate catalog entry")
			return
		seen[catalog[index]] = true


func _check_prices() -> void:
	if Pricing.div_nonneg(7, 2) != 3 or Pricing.div_nonneg(17000, 1000) != 17:
		_fail("integer division")
	if Pricing.share_price(4, 0) != 300 or Pricing.share_price(4, 2) != 360 or Pricing.share_price(4, -2) != 240:
		_fail("spec share prices")
	if Pricing.share_price(0, 99) != 0 or Pricing.share_price(-1, 0) != -1 or Pricing.share_price(1, 3) != -1:
		_fail("share price guards")
	var golden = SharedFiles.read_json("fixtures/golden_prices.json")
	if golden == null:
		_fail("price golden missing")
		return
	for case in golden["cases"]:
		var got := Pricing.share_price(int(case["size"]), int(case["sentiment"]))
		if got != int(case["price"]):
			_fail("price %s sentiment %s got %s" % [str(case["size"]), str(case["sentiment"]), str(got)])


func _check_byte() -> void:
	if Pricing.byte_price_after_delta(500, 20) != 600:
		_fail("spec byte price")
	if Pricing.byte_price_after_delta(50, 10) != -1 or Pricing.byte_price_after_delta(105, 10) != -1:
		_fail("byte guards")
	var golden = SharedFiles.read_json("fixtures/golden_byte.json")
	if golden == null:
		_fail("byte golden missing")
		return
	for case in golden["cases"]:
		var got := Pricing.byte_price_after_delta(int(case["prior"]), int(case["delta_percent"]))
		if got != int(case["price"]):
			_fail("byte %s %+d got %s" % [str(case["prior"]), int(case["delta_percent"]), str(got)])


func _check_sentiment() -> void:
	var golden = SharedFiles.read_json("fixtures/golden_sentiment.json")
	if golden == null:
		_fail("sentiment golden missing")
		return
	for case in golden["cases"]:
		var actual: Dictionary = SectorEvents.apply_sector_deltas(case["start"], case["deltas"])
		var expected: Dictionary = case["result"]
		if actual.is_empty():
			_fail("sentiment rejected %s" % str(case["name"]))
			continue
		for key in expected.keys():
			if int(actual[key]) != int(expected[key]):
				_fail("sentiment %s %s" % [str(case["name"]), str(key)])


func _check_ranking() -> void:
	var golden = SharedFiles.read_json("fixtures/golden_ranking.json")
	if golden == null:
		_fail("ranking golden missing")
		return
	for case in golden["cases"]:
		var order := Ranking.rank_players(case["players"])
		var expected: Array = case["order"]
		if order.size() != expected.size():
			_fail("rank size %s" % str(case["name"]))
			continue
		for index in expected.size():
			if order[index] != str(expected[index]):
				_fail("rank %s" % str(case["name"]))
	var rejected := Ranking.rank_players([
		{"id": "a", "net_worth": 1, "cash": 0, "active_shares": 0, "turn_order_index": 0},
		{"id": "b", "net_worth": 2, "cash": 0, "active_shares": 0, "turn_order_index": 0},
	])
	if rejected.size() != 0:
		_fail("duplicate turn index was accepted")


func _check_tiles() -> void:
	var catalog := Coordinates.catalog()
	var clean := Tiles.conservation_errors(catalog, [], [])
	if clean.size() != 0:
		_fail("clean bag %s" % str(clean))
	var bag: Array[String] = []
	for coordinate in catalog:
		bag.append(coordinate)
	bag.append("A1")
	var duplicated := Tiles.conservation_errors(bag, [], [])
	if duplicated.size() != 2 or duplicated[0] != "count:82" or duplicated[1] != "duplicate:A1":
		_fail("duplicate errors %s" % str(duplicated))
	var swapped: Array[String] = []
	for coordinate in catalog:
		if coordinate == "A1":
			swapped.append("Z9")
		else:
			swapped.append(coordinate)
	var unknown := Tiles.conservation_errors(swapped, [], [])
	if unknown.size() != 2 or unknown[0] != "missing:A1" or unknown[1] != "unknown:Z9":
		_fail("unknown errors %s" % str(unknown))
