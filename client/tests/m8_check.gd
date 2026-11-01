extends SceneTree

## Local computers play a finished match from the seed, and the same seed plays it again.


var _failures: PackedStringArray = []


func _initialize() -> void:
	_check_founding_beats_an_isolated_tile()
	_check_isolated_tiles_use_autopass_order()
	_check_growth_does_not_feed_a_large_opponent()
	_check_founder_and_survivor_choices()
	_check_market_buys_at_most_once()
	_check_full_matches()
	_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("M8_CLIENT_OK")
		quit(0)
		return
	print("M8_CLIENT_FAIL %d" % _failures.size())
	for line in _failures:
		print(line)
	quit(1)


func _check_founding_beats_an_isolated_tile() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	ada["hand"] = ["A1", "A2"]
	table.occupied["A3"] = true
	var decision := BotPolicy.decide(table)
	if str(decision.get("coordinate", "")) != "A2":
		_fail("founding tile %s" % str(decision))


func _check_isolated_tiles_use_autopass_order() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	ada["hand"] = ["E9", "A1"]
	var decision := BotPolicy.decide(table)
	if str(decision.get("coordinate", "")) != "A1":
		_fail("lex tile %s" % str(decision))


func _check_growth_does_not_feed_a_large_opponent() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	var rowan := _seat(table, "Rowan")
	table.turn_index = int(ada["turn_order_index"])
	ada["hand"] = ["C3", "I9"]
	rowan["shares"]["nova_ai"] = 5
	table.occupied["C1"] = true
	table.occupied["C2"] = true
	table.company_of["C1"] = "nova_ai"
	table.company_of["C2"] = "nova_ai"
	var nova: Dictionary = table.corporations[0]
	nova["active"] = true
	nova["size"] = 2
	nova["share_price"] = 200
	var decision := BotPolicy.decide(table)
	if str(decision.get("coordinate", "")) != "I9":
		_fail("fed opponent %s" % str(decision))


func _check_founder_and_survivor_choices() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	table.phase = "choose_founder"
	table.sentiment["energy"] = 2
	var founder := BotPolicy.decide(table)
	if str(founder.get("corporation_id", "")) != "volt_grid":
		_fail("founder %s" % str(founder))
	table.sentiment["energy"] = 0
	var fallback := BotPolicy.decide(table)
	if str(fallback.get("corporation_id", "")) != "nova_ai":
		_fail("founder default %s" % str(fallback))
	table.phase = "choose_survivor"
	var options: Array[String] = ["nova_ai", "orbit_pay"]
	table.pending_options = options
	ada["shares"]["orbit_pay"] = 3
	var survivor := BotPolicy.decide(table)
	if str(survivor.get("corporation_id", "")) != "orbit_pay":
		_fail("survivor %s" % str(survivor))
	ada["shares"]["orbit_pay"] = 0
	var tied := BotPolicy.decide(table)
	if str(tied.get("corporation_id", "")) != "nova_ai":
		_fail("survivor default %s" % str(tied))


func _check_market_buys_at_most_once() -> void:
	var table = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	table.phase = "market"
	table.market_actions_left = 2
	var passed := BotPolicy.decide(table)
	if str(passed.get("command", "")) != "pass_market":
		_fail("empty market %s" % str(passed))
	var nova: Dictionary = table.corporations[0]
	nova["active"] = true
	nova["size"] = 2
	nova["share_price"] = 200
	nova["bank_shares"] = 20
	var orbit: Dictionary = table.corporations[1]
	orbit["active"] = true
	orbit["size"] = 4
	orbit["share_price"] = 400
	orbit["bank_shares"] = 20
	var bought := BotPolicy.decide(table)
	if str(bought.get("command", "")) != "buy_share" or str(bought.get("corporation_id", "")) != "nova_ai":
		_fail("cheap share %s" % str(bought))
	var applied := BotPolicy.apply(table, bought)
	if not bool(applied.get("ok", false)):
		_fail("buy failed %s" % str(applied))
	var second := BotPolicy.decide(table)
	if str(second.get("command", "")) != "pass_market":
		_fail("second market %s" % str(second))
	ada["shares"]["orbit_pay"] = 2
	table.market_actions_left = 2
	var held := BotPolicy.decide(table)
	if str(held.get("corporation_id", "")) != "orbit_pay":
		_fail("held share %s" % str(held))


func _check_full_matches() -> void:
	var first := _play(7710, ["Rowan", "Ada", "Bo"], ["Ada", "Bo"])
	var second := _play(7710, ["Rowan", "Ada", "Bo"], ["Ada", "Bo"])
	if not bool(first.get("ok", false)):
		_fail("match %s" % str(first.get("error", first)))
		return
	if str(first["trace"]) != str(second["trace"]) or str(first["ranking"]) != str(second["ranking"]):
		_fail("replay diverged")
	if str(first["events"]) != str(second["events"]) or str(first["log"]) != str(second["log"]):
		_fail("log diverged")
	var wider := _play(4, ["Rowan", "Ada", "Bo", "Cy"], ["Ada", "Bo", "Cy"])
	if not bool(wider.get("ok", false)):
		_fail("four seats %s" % str(wider.get("error", wider)))
		return
	if int(first["steps"]) < 20 or int(wider["steps"]) < 20:
		_fail("short match")


func _play(seed_value: int, names: Array, bots: Array) -> Dictionary:
	var table = OfflineMatch.create(seed_value, names, bots)
	if table == null:
		return {"ok": false, "error": "deal"}
	var trace: PackedStringArray = []
	var steps := 0
	while table.phase != "completed" and steps < 900:
		steps += 1
		var decision := BotPolicy.decide(table)
		if not bool(decision.get("ok", false)):
			return {"ok": false, "error": str(decision.get("error", decision)), "at": steps}
		trace.append("%s:%s" % [str(decision["command"]), str(decision.get("coordinate", decision.get("corporation_id", "")))])
		var result := BotPolicy.apply(table, decision)
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": str(result.get("error", result)), "at": trace[trace.size() - 1]}
	if table.phase != "completed":
		return {"ok": false, "error": "step cap %d" % steps}
	var economy := table.economy_errors()
	if not economy.is_empty():
		return {"ok": false, "error": "economy %s" % str(economy)}
	if table.conservation().size() != 0:
		return {"ok": false, "error": "tiles"}
	if table.ranking.is_empty():
		return {"ok": false, "error": "ranking"}
	return {
		"ok": true,
		"steps": steps,
		"trace": "\n".join(trace),
		"ranking": ",".join(table.ranking),
		"events": ",".join(table.event_ids),
		"log": "\n".join(table.log),
	}


func _seat(table: OfflineMatch, display_name: String) -> Dictionary:
	for player in table.players:
		if str(player["display_name"]) == display_name:
			return player
	_fail("missing %s" % display_name)
	return {}
