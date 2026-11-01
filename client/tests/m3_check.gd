extends SceneTree

var _failures: PackedStringArray = []


func _initialize() -> void:
	_check_bonus_math()
	_check_sole_holder()
	_check_tie_majority()
	_check_remainder()
	_check_three_companies()
	_check_tie_choice()
	_check_refound()
	if _failures.is_empty():
		print("M3_CLIENT_OK")
		quit(0)
		return
	print("M3_CLIENT_FAIL %d" % _failures.size())
	for line in _failures:
		print(line)
	quit(1)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _check_bonus_math() -> void:
	var sole: Dictionary = Mergers.bonus_payouts(400, {"p1": 4, "p2": 0})
	if int(sole.get("p1", 0)) != 1200 or sole.has("p2"):
		_fail("sole bonus")
	var tied: Dictionary = Mergers.bonus_payouts(300, {"p1": 2, "p2": 2, "p3": 1})
	if int(tied.get("p1", 0)) != 450 or int(tied.get("p2", 0)) != 450 or tied.has("p3"):
		_fail("tie bonus")
	var second: Dictionary = Mergers.bonus_payouts(250, {"p1": 4, "p2": 1, "p3": 1, "p4": 1})
	if int(second["p1"]) != 500 or int(second["p2"]) != 84 or int(second["p3"]) != 83 or int(second["p4"]) != 83:
		_fail("remainder bonus")
	if not Mergers.bonus_payouts(300, {"p1": 0}).is_empty():
		_fail("empty bonus")


func _check_sole_holder() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_chain(table, ["C1", "C2", "C3", "C4", "C5"], "nova_ai")
	_chain(table, ["A1", "A2", "A3"], "orbit_pay")
	_assign(table, "orbit_pay", {"p2": 4})
	_pull(table, "B1")
	var resolved: Dictionary = table.place("B1")
	if str(resolved["log"]) != "Rowan placed B1. NOVA AI survives the merger at size 9. Share price is $550.":
		_fail("size 5 survivor log")
	if not _has(table, "Quinn received a $750 bonus on ORBIT PAY."):
		_fail("sole bonus log")
	if not _has(table, "Quinn liquidated 4 ORBIT PAY shares for $1000."):
		_fail("sole sale log")
	if _cash(table, "p2") != 7750 or _cash(table, "p1") != 6000:
		_fail("sole cash")
	if bool(_corp(table, "orbit_pay")["active"]) or int(_corp(table, "nova_ai")["share_price"]) != 550:
		_fail("sole inventory")
	if table.economy_errors().size() != 0:
		_fail("sole economy")


func _check_tie_majority() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn", "Avery"])
	_chain(table, ["C1", "C2", "C3", "C4", "C5"], "nova_ai")
	_chain(table, ["A1", "A2", "A3", "A4"], "orbit_pay")
	_assign(table, "orbit_pay", {"p1": 2, "p2": 2, "p3": 1})
	_pull(table, "B1")
	table.place("B1")
	if _cash(table, "p1") != 7050 or _cash(table, "p2") != 7050 or _cash(table, "p3") != 6300:
		_fail("tie cash")
	if not _has(table, "Avery liquidated 1 ORBIT PAY shares for $300."):
		_fail("lower holder sale")
	if table.economy_errors().size() != 0:
		_fail("tie economy")


func _check_remainder() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn", "Avery", "Blake"])
	_chain(table, ["C1", "C2", "C3", "C4"], "nova_ai")
	_chain(table, ["A1", "A2", "A3"], "orbit_pay")
	_assign(table, "orbit_pay", {"p1": 4, "p2": 1, "p3": 1, "p4": 1})
	_pull(table, "B1")
	table.place("B1")
	if _cash(table, "p1") != 7500 or _cash(table, "p2") != 6334 or _cash(table, "p3") != 6333 or _cash(table, "p4") != 6333:
		_fail("remainder cash")
	if table.economy_errors().size() != 0:
		_fail("remainder economy")


func _check_three_companies() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn", "Avery", "Blake"])
	_chain(table, ["A1", "A2", "A3", "A4", "A5", "B5"], "nova_ai")
	_chain(table, ["D5", "E5", "E6"], "orbit_pay")
	_chain(table, ["C3", "C4"], "volt_grid")
	_pull(table, "C6")
	table.place("C6")
	_finish(table)
	_assign(table, "orbit_pay", {"p1": 2, "p2": 2})
	_assign(table, "volt_grid", {"p3": 1})
	var before: int = table.log.size()
	_pull(table, "C5")
	var resolved: Dictionary = table.place("C5")
	if str(resolved["survivor"]) != "nova_ai" or int(_corp(table, "nova_ai")["size"]) != 13:
		_fail("three-company size")
	var prices := 0
	for index in range(before, table.log.size()):
		if "Share price is $" in str(table.log[index]):
			prices += 1
	if prices != 1 or int(_corp(table, "nova_ai")["share_price"]) != 750:
		_fail("one reprice")
	if bool(_corp(table, "orbit_pay")["active"]) or bool(_corp(table, "volt_grid")["active"]):
		_fail("losers still active")
	if table.economy_errors().size() != 0:
		_fail("three economy")


func _check_tie_choice() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_chain(table, ["A2", "A3"], "nova_ai")
	_chain(table, ["C2", "C3"], "orbit_pay")
	_pull(table, "B1")
	table.place("B1")
	_finish(table)
	_pull(table, "B2")
	var opened: Dictionary = table.place("B2")
	if str(opened["resolution"]) != "choose_survivor" or table.economy_errors().size() != 0:
		_fail("tie open")
	var rejected: Dictionary = table.choose_survivor("volt_grid")
	if bool(rejected["ok"]) or str(rejected["error"]) != "company is not a tied survivor":
		_fail("volt was selectable")
	var kept: Dictionary = table.choose_survivor("orbit_pay")
	if str(kept["log"]) != "Quinn kept ORBIT PAY. ORBIT PAY is size 6. Share price is $400.":
		_fail("kept orbit")
	if bool(_corp(table, "nova_ai")["active"]) or table.economy_errors().size() != 0:
		_fail("tie resolved economy")


func _check_refound() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_chain(table, ["A1", "A2", "A3"], "nova_ai")
	_chain(table, ["C1", "C2"], "orbit_pay")
	_assign(table, "orbit_pay", {})
	var before := _cash(table, "p1") + _cash(table, "p2")
	_pull(table, "B1")
	table.place("B1")
	if not _has(table, "ORBIT PAY paid no merger bonus."):
		_fail("no bonus line")
	if _cash(table, "p1") + _cash(table, "p2") != before:
		_fail("empty holder cash moved")
	_finish(table)
	_pull(table, "I8")
	table.place("I8")
	_finish(table)
	_pull(table, "I9")
	table.place("I9")
	var founded: Dictionary = table.choose_founder("orbit_pay")
	if not bool(founded["granted"]) or int(_corp(table, "orbit_pay")["bank_shares"]) != 19:
		_fail("refound")
	if table.economy_errors().size() != 0:
		_fail("refound economy")


func _chain(table: OfflineMatch, cells: Array, brand: String) -> void:
	for index in cells.size():
		_pull(table, str(cells[index]))
		var placed: Dictionary = table.place(str(cells[index]))
		if not bool(placed["ok"]):
			_fail("chain place %s" % str(cells[index]))
			return
		if index == 1:
			var founded: Dictionary = table.choose_founder(brand)
			if not bool(founded["ok"]):
				_fail("chain found %s" % brand)
				return
		_finish(table)


func _assign(table: OfflineMatch, corp_id: String, counts: Dictionary) -> void:
	var outstanding := 0
	for player in table.players:
		var count := int(counts.get(str(player["id"]), 0))
		player["shares"][corp_id] = count
		outstanding += count
	_corp(table, corp_id)["bank_shares"] = 20 - outstanding


func _pull(table: OfflineMatch, coordinate: String) -> void:
	for player in table.players:
		var hand: Array = player["hand"]
		var index := hand.find(coordinate)
		if index != -1:
			hand.remove_at(index)
			table.active_player()["hand"].append(coordinate)
			return
	var bag_index: int = table.bag.find(coordinate)
	table.bag.remove_at(bag_index)
	table.active_player()["hand"].append(coordinate)


func _finish(table: OfflineMatch) -> void:
	while table.phase == "market" and table.market_actions_left > 0:
		table.pass_market()


func _corp(table: OfflineMatch, corp_id: String) -> Dictionary:
	for corp in table.corporations:
		if str(corp["id"]) == corp_id:
			return corp
	return {}


func _cash(table: OfflineMatch, player_id: String) -> int:
	for player in table.players:
		if str(player["id"]) == player_id:
			return int(player["cash"])
	return -1


func _has(table: OfflineMatch, line: String) -> bool:
	return table.log.find(line) != -1
