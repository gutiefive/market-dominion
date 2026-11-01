extends SceneTree

var _failures: PackedStringArray = []


func _initialize() -> void:
	_check_founding_and_trade()
	_check_growth()
	_check_merger_and_diagonal()
	_check_rejections()
	if _failures.is_empty():
		print("M2_CLIENT_OK")
		quit(0)
		return
	print("M2_CLIENT_FAIL %d" % _failures.size())
	for line in _failures:
		print(line)
	quit(1)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _pull(table: OfflineMatch, coordinate: String) -> void:
	for player in table.players:
		var hand: Array = player["hand"]
		var index := hand.find(coordinate)
		if index != -1:
			hand.remove_at(index)
			table.active_player()["hand"].append(coordinate)
			return
	var bag_index: int = table.bag.find(coordinate)
	if bag_index == -1:
		_fail("missing tile %s" % coordinate)
		return
	table.bag.remove_at(bag_index)
	table.active_player()["hand"].append(coordinate)


func _finish(table: OfflineMatch) -> void:
	while table.phase == "market" and table.market_actions_left > 0:
		table.pass_market()


func _check_founding_and_trade() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_pull(table, "A1")
	var alone: Dictionary = table.place("A1")
	if str(alone["resolution"]) != "unincorporated" or table.phase != "market" or table.market_actions_left != 2:
		_fail("isolated place")
		return
	if table.bag.size() != 70:
		_fail("draw was early")
	_finish(table)
	if table.active_player()["display_name"] != "Quinn" or table.log[table.log.size() - 1] != "Rowan drew from the bag.":
		_fail("draw after market")
	_pull(table, "E9")
	table.place("E9")
	_finish(table)
	_pull(table, "A2")
	var pending: Dictionary = table.place("A2")
	if str(pending["resolution"]) != "choose_founder":
		_fail("expected a founding choice")
		return
	var unknown: Dictionary = table.choose_founder("not_a_brand")
	if bool(unknown["ok"]) or str(unknown["error"]) != "unknown company":
		_fail("unknown brand")
	var founded: Dictionary = table.choose_founder("nova_ai")
	var nova: Dictionary = table.corporations[0]
	if not bool(founded["granted"]) or int(nova["share_price"]) != 200 or int(nova["size"]) != 2:
		_fail("founder price")
	if int(nova["bank_shares"]) != 19 or int(table.active_player()["shares"]["nova_ai"]) != 1:
		_fail("founder share")
	if int(table.active_player()["cash"]) != 6000:
		_fail("founder cash")
	var buyer := table.active_player()
	var bought: Dictionary = table.buy_share("nova_ai")
	if not bool(bought["ok"]) or int(buyer["cash"]) != 5800 or int(nova["bank_shares"]) != 18:
		_fail("buy share")
	var sold: Dictionary = table.sell_share("nova_ai")
	if not bool(sold["turn_finished"]) or int(buyer["shares"]["nova_ai"]) != 1 or int(buyer["cash"]) != 6000:
		_fail("sell share")
	if table.economy_errors().size() != 0:
		_fail("founding economy %s" % str(table.economy_errors()))


func _check_growth() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_pull(table, "A1")
	table.place("A1")
	_finish(table)
	_pull(table, "E9")
	table.place("E9")
	_finish(table)
	_pull(table, "A2")
	table.place("A2")
	table.choose_founder("nova_ai")
	_finish(table)
	_pull(table, "C1")
	var single: Dictionary = table.place("C1")
	if str(single["resolution"]) != "unincorporated":
		_fail("C1 should stay loose")
	_finish(table)
	_pull(table, "B1")
	var grew: Dictionary = table.place("B1")
	var nova: Dictionary = table.corporations[0]
	var cells: Array = nova["cells"]
	if str(grew["resolution"]) != "growth" or cells.size() != 4 or int(nova["share_price"]) != 300:
		_fail("growth price %s" % str(nova["share_price"]))
		return
	if str(cells[0]) != "A1" or str(cells[1]) != "B1" or str(cells[2]) != "C1" or str(cells[3]) != "A2":
		_fail("growth cells")
	var bought: Dictionary = table.buy_share("nova_ai")
	if not str(bought["log"]).ends_with("for $300.") or int(table.active_player()["cash"]) != 5700:
		_fail("growth trade")
	if table.economy_errors().size() != 0:
		_fail("growth economy")


func _check_merger_and_diagonal() -> void:
	var diagonal = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_pull(diagonal, "A1")
	diagonal.place("A1")
	_finish(diagonal)
	_pull(diagonal, "B2")
	var apart: Dictionary = diagonal.place("B2")
	if str(apart["resolution"]) != "unincorporated":
		_fail("diagonal connected")
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_pull(table, "A1")
	table.place("A1")
	_finish(table)
	_pull(table, "C4")
	table.place("C4")
	_finish(table)
	_pull(table, "A2")
	table.place("A2")
	table.choose_founder("nova_ai")
	_finish(table)
	_pull(table, "C1")
	table.place("C1")
	_finish(table)
	_pull(table, "C2")
	table.place("C2")
	table.choose_founder("orbit_pay")
	_finish(table)
	_pull(table, "B1")
	var blocked: Dictionary = table.place("B1")
	if bool(blocked["ok"]) or str(blocked["error"]) != "merger is not in this build":
		_fail("merger stub")
	if table.active_player()["hand"].find("B1") == -1:
		_fail("merger consumed the tile")
	if table.economy_errors().size() != 0:
		_fail("merger economy")


func _check_rejections() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Quinn"])
	_pull(table, "A1")
	table.place("A1")
	var inactive: Dictionary = table.buy_share("nova_ai")
	if bool(inactive["ok"]) or str(inactive["error"]) != "company is not active":
		_fail("inactive trade")
	if table.market_actions_left != 2:
		_fail("failed trade spent an action")
	var shorted: Dictionary = table.sell_byte()
	if bool(shorted["ok"]) or str(shorted["error"]) != "no BYTE to sell":
		_fail("short byte")
	_finish(table)
	_pull(table, "A2")
	table.place("A2")
	table.choose_founder("nova_ai")
	table.active_player()["cash"] = 100
	var poor: Dictionary = table.buy_share("nova_ai")
	if bool(poor["ok"]) or str(poor["error"]) != "not enough cash" or int(table.active_player()["cash"]) != 100:
		_fail("negative cash guard")
	table.active_player()["cash"] = 6000
	table.buy_byte()
	table.buy_byte()
	if table.phase != "place" or int(table.players[0]["byte_count"]) + int(table.players[1]["byte_count"]) != 2:
		_fail("two byte buys")
	var third: Dictionary = table.buy_byte()
	if bool(third["ok"]) or str(third["error"]) != "not the market step":
		_fail("third action")
	if table.economy_errors().size() != 0:
		_fail("rejection economy %s" % str(table.economy_errors()))
