extends SceneTree

## Local computers play a finished match from the seed, and the same seed plays it again.


var _failures: PackedStringArray = []


func _initialize() -> void:
	_check_founding_beats_an_isolated_tile()
	_check_isolated_tiles_use_autopass_order()
	_check_lookahead_sets_up_a_founding()
	_check_three_plies_prefer_a_longer_setup()
	_check_growth_does_not_feed_a_large_opponent()
	_check_merger_uses_holdings()
	_check_founder_and_survivor_choices()
	_check_survivor_prefers_the_higher_payout()
	_check_market_buys_sells_and_trades_byte()
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


func _check_lookahead_sets_up_a_founding() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	ada["hand"] = ["A1", "C1", "C2"]
	var decision := BotPolicy.decide(table)
	if str(decision.get("coordinate", "")) != "C1":
		_fail("lookahead %s" % str(decision))
	var again := BotPolicy.decide(table)
	if str(again.get("coordinate", "")) != "C1":
		_fail("lookahead drifted %s" % str(again))


func _check_three_plies_prefer_a_longer_setup() -> void:
	# One tile ahead scores B1 highest. It grows NOVA immediately (150).
	# E3 scores 100 on that rule, because the next tile only founds a size-2 company.
	# Three plies see E3, then E4 founds, then D3 merges that company into NOVA.
	var table = _chain_table()
	var started := Time.get_ticks_usec()
	var decision := BotPolicy.decide(table)
	for _repeat in range(49):
		BotPolicy.decide(table)
	var elapsed := Time.get_ticks_usec() - started
	if str(decision.get("coordinate", "")) != "E3":
		_fail("deep setup %s" % str(decision))
	var again := BotPolicy.decide(table)
	if str(again.get("coordinate", "")) != "E3":
		_fail("deep setup drifted %s" % str(again))
	if elapsed > 1500000:
		_fail("placement search %d us" % elapsed)
	print("M8_PLACEMENT_50_US %d" % elapsed)


func _chain_table():
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	ada["hand"] = ["B1", "D3", "E3", "E4"]
	ada["shares"]["nova_ai"] = 2
	for cell in ["C1", "C2", "C3", "C4"]:
		table.occupied[cell] = true
		table.company_of[cell] = "nova_ai"
	var nova: Dictionary = table.corporations[0]
	nova["active"] = true
	nova["size"] = 4
	nova["share_price"] = 300
	return table


func _check_merger_uses_holdings() -> void:
	var helpful = _merger_table()
	var ada := _seat(helpful, "Ada")
	ada["shares"]["nova_ai"] = 5
	ada["hand"] = ["D1", "I9"]
	var taken := BotPolicy.decide(helpful)
	if str(taken.get("coordinate", "")) != "D1":
		_fail("skipped own merger %s" % str(taken))
	var harmful = _merger_table()
	var rowan := _seat(harmful, "Rowan")
	rowan["shares"]["nova_ai"] = 5
	var ada_harm := _seat(harmful, "Ada")
	ada_harm["hand"] = ["D1", "I9"]
	var avoided := BotPolicy.decide(harmful)
	if str(avoided.get("coordinate", "")) != "I9":
		_fail("fed merger %s" % str(avoided))


func _merger_table():
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	for cell in ["C1", "C2"]:
		table.occupied[cell] = true
		table.company_of[cell] = "nova_ai"
	for cell in ["E1", "E2"]:
		table.occupied[cell] = true
		table.company_of[cell] = "orbit_pay"
	var nova: Dictionary = table.corporations[0]
	nova["active"] = true
	nova["size"] = 2
	nova["share_price"] = 200
	var orbit: Dictionary = table.corporations[1]
	orbit["active"] = true
	orbit["size"] = 2
	orbit["share_price"] = 200
	return table


func _check_survivor_prefers_the_higher_payout() -> void:
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	table.phase = "choose_survivor"
	var options: Array[String] = ["orbit_pay", "nova_ai"]
	table.pending_options = options
	table.pending = ["A1", "A2", "A3", "B1", "B2", "B3"]
	ada["shares"]["nova_ai"] = 2
	ada["shares"]["orbit_pay"] = 2
	var nova: Dictionary = table.corporations[0]
	nova["active"] = true
	nova["size"] = 3
	nova["share_price"] = 100
	var orbit: Dictionary = table.corporations[1]
	orbit["active"] = true
	orbit["size"] = 3
	orbit["share_price"] = 500
	var survivor := BotPolicy.decide(table)
	if str(survivor.get("corporation_id", "")) != "nova_ai":
		_fail("payout survivor %s" % str(survivor))


func _check_market_buys_sells_and_trades_byte() -> void:
	var quiet = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(quiet, "Ada")
	quiet.turn_index = int(ada["turn_order_index"])
	quiet.phase = "market"
	quiet.market_actions_left = 2
	var passed := BotPolicy.decide(quiet)
	if str(passed.get("command", "")) != "pass_market":
		_fail("empty market %s" % str(passed))
	var nova: Dictionary = quiet.corporations[0]
	nova["active"] = true
	nova["size"] = 2
	nova["share_price"] = 200
	nova["bank_shares"] = 20
	var orbit: Dictionary = quiet.corporations[1]
	orbit["active"] = true
	orbit["size"] = 4
	orbit["share_price"] = 400
	orbit["bank_shares"] = 20
	var bought := BotPolicy.decide(quiet)
	if str(bought.get("command", "")) != "buy_share" or str(bought.get("corporation_id", "")) != "nova_ai":
		_fail("cheap share %s" % str(bought))
	if not bool(BotPolicy.apply(quiet, bought).get("ok", false)):
		_fail("buy failed")
	var second := BotPolicy.decide(quiet)
	if str(second.get("command", "")) != "buy_share" or str(second.get("corporation_id", "")) != "nova_ai":
		_fail("second buy %s" % str(second))
	if not bool(BotPolicy.apply(quiet, second).get("ok", false)):
		_fail("second buy failed")
	if int(ada["cash"]) < 0 or int(ada["shares"]["nova_ai"]) != 2 or int(nova["bank_shares"]) < 0:
		_fail("two buys left cash %d shares %s bank %d" % [int(ada["cash"]), str(ada["shares"]["nova_ai"]), int(nova["bank_shares"])])
	var held_table = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var holder := _seat(held_table, "Ada")
	held_table.turn_index = int(holder["turn_order_index"])
	held_table.phase = "market"
	held_table.market_actions_left = 2
	var held_nova: Dictionary = held_table.corporations[0]
	held_nova["active"] = true
	held_nova["size"] = 2
	held_nova["share_price"] = 200
	held_nova["bank_shares"] = 20
	var held_orbit: Dictionary = held_table.corporations[1]
	held_orbit["active"] = true
	held_orbit["size"] = 4
	held_orbit["share_price"] = 400
	held_orbit["bank_shares"] = 20
	holder["shares"]["orbit_pay"] = 2
	var held := BotPolicy.decide(held_table)
	if str(held.get("corporation_id", "")) != "orbit_pay":
		_fail("held share %s" % str(held))
	_check_sells_then_buys()
	_check_byte_round_trip()


func _check_sells_then_buys() -> void:
	var table = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	table.phase = "market"
	table.market_actions_left = 2
	table.sentiment["media"] = 2
	var pulse: Dictionary = table.corporations[3]
	pulse["active"] = true
	pulse["size"] = 18
	pulse["share_price"] = 1000
	pulse["bank_shares"] = 18
	ada["shares"]["pulse_media"] = 2
	var nova: Dictionary = table.corporations[0]
	nova["active"] = true
	nova["size"] = 2
	nova["share_price"] = 200
	nova["bank_shares"] = 20
	var first := BotPolicy.decide(table)
	var again := BotPolicy.decide(table)
	if str(first) != str(again):
		_fail("sell drifted")
	if str(first.get("command", "")) != "sell_share" or str(first.get("corporation_id", "")) != "pulse_media":
		_fail("sell share %s" % str(first))
	if not bool(BotPolicy.apply(table, first).get("ok", false)):
		_fail("sell failed")
	var follow := BotPolicy.decide(table)
	if str(follow.get("command", "")) != "buy_share" or str(follow.get("corporation_id", "")) != "nova_ai":
		_fail("buy after sell %s" % str(follow))
	if not bool(BotPolicy.apply(table, follow).get("ok", false)):
		_fail("buy after sell failed")
	if int(ada["cash"]) != 6800 or int(ada["shares"]["pulse_media"]) != 1 or int(ada["shares"]["nova_ai"]) != 1:
		_fail("sell inventory cash %d pulse %s nova %s" % [int(ada["cash"]), str(ada["shares"]["pulse_media"]), str(ada["shares"]["nova_ai"])])
	if int(ada["cash"]) < 0 or int(ada["byte_count"]) < 0:
		_fail("sell went negative")
	var thin = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var broke := _seat(thin, "Ada")
	thin.turn_index = int(broke["turn_order_index"])
	thin.phase = "market"
	thin.market_actions_left = 1
	broke["cash"] = 400
	broke["shares"]["nova_ai"] = 1
	var small: Dictionary = thin.corporations[0]
	small["active"] = true
	small["size"] = 2
	small["share_price"] = 200
	small["bank_shares"] = 19
	var liquid := BotPolicy.decide(thin)
	if str(liquid.get("command", "")) != "sell_share" or str(liquid.get("corporation_id", "")) != "nova_ai":
		_fail("liquidity sell %s" % str(liquid))
	if not bool(BotPolicy.apply(thin, liquid).get("ok", false)):
		_fail("liquidity sell failed")
	if int(broke["cash"]) != 600 or int(broke["shares"]["nova_ai"]) != 0:
		_fail("liquidity book cash %d shares %s" % [int(broke["cash"]), str(broke["shares"]["nova_ai"])])


func _check_byte_round_trip() -> void:
	var buying = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(buying, "Ada")
	buying.turn_index = int(ada["turn_order_index"])
	buying.phase = "market"
	buying.market_actions_left = 2
	buying.byte_price = 300
	var first := BotPolicy.decide(buying)
	if str(first.get("command", "")) != "buy_byte":
		_fail("buy byte %s" % str(first))
	if not bool(BotPolicy.apply(buying, first).get("ok", false)):
		_fail("buy byte failed")
	var second := BotPolicy.decide(buying)
	if str(second.get("command", "")) != "buy_byte":
		_fail("second byte %s" % str(second))
	if not bool(BotPolicy.apply(buying, second).get("ok", false)):
		_fail("second byte failed")
	if int(ada["byte_count"]) != 2 or int(ada["cash"]) != 5400 or buying.byte_exchange != 28:
		_fail("byte buy book byte %s cash %d exchange %d" % [str(ada["byte_count"]), int(ada["cash"]), buying.byte_exchange])
	if buying.phase != "place":
		_fail("byte buy did not close the market")
	var selling = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var seller := _seat(selling, "Ada")
	selling.turn_index = int(seller["turn_order_index"])
	selling.phase = "market"
	selling.market_actions_left = 2
	selling.byte_price = 1000
	seller["byte_count"] = 1
	selling.byte_exchange = 29
	var sold := BotPolicy.decide(selling)
	if str(sold.get("command", "")) != "sell_byte":
		_fail("sell byte %s" % str(sold))
	if not bool(BotPolicy.apply(selling, sold).get("ok", false)):
		_fail("sell byte failed")
	if int(seller["byte_count"]) != 0 or int(seller["cash"]) != 7000 or selling.byte_exchange != 30:
		_fail("byte sell book byte %s cash %d exchange %d" % [str(seller["byte_count"]), int(seller["cash"]), selling.byte_exchange])
	var done := BotPolicy.decide(selling)
	if str(done.get("command", "")) != "pass_market":
		_fail("byte sell follow %s" % str(done))
	var reserved_table = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var poor := _seat(reserved_table, "Ada")
	reserved_table.turn_index = int(poor["turn_order_index"])
	reserved_table.phase = "market"
	reserved_table.market_actions_left = 2
	reserved_table.byte_price = 300
	poor["cash"] = 600
	var reserved := BotPolicy.decide(reserved_table)
	if str(reserved.get("command", "")) != "pass_market":
		_fail("byte reserve %s" % str(reserved))
	poor["cash"] = 400
	poor["byte_count"] = 1
	reserved_table.byte_exchange = 29
	reserved_table.byte_price = 500
	var forced := BotPolicy.decide(reserved_table)
	if str(forced.get("command", "")) != "sell_byte":
		_fail("byte liquidity %s" % str(forced))
	if not bool(BotPolicy.apply(reserved_table, forced).get("ok", false)):
		_fail("byte liquidity failed")
	if int(poor["byte_count"]) != 0 or int(poor["cash"]) != 900 or reserved_table.byte_exchange != 30:
		_fail("byte liquidity book byte %s cash %d exchange %d" % [str(poor["byte_count"]), int(poor["cash"]), reserved_table.byte_exchange])


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
	var mixed := _play_mixed(7710, ["Rowan", "Ada", "Bo"], ["Ada", "Bo"])
	if not bool(mixed.get("ok", false)):
		_fail("mixed %s" % str(mixed.get("error", mixed)))
		return
	if int(mixed.get("computer_actions", 0)) < 10:
		_fail("mixed computers did not play")


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


func _play_mixed(seed_value: int, names: Array, bots: Array) -> Dictionary:
	var table = OfflineMatch.create(seed_value, names, bots)
	if table == null:
		return {"ok": false, "error": "deal"}
	var steps := 0
	var computer_actions := 0
	while table.phase != "completed" and steps < 900:
		steps += 1
		var result: Dictionary
		if bool(table.active_player().get("bot", false)):
			computer_actions += 1
			result = BotPolicy.act(table)
		else:
			result = _human_autopass(table)
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": str(result.get("error", result)), "at": steps}
	if table.phase != "completed":
		return {"ok": false, "error": "step cap %d" % steps}
	var economy := table.economy_errors()
	if not economy.is_empty():
		return {"ok": false, "error": "economy %s" % str(economy)}
	if table.ranking.is_empty():
		return {"ok": false, "error": "ranking"}
	return {"ok": true, "computer_actions": computer_actions, "steps": steps}


func _human_autopass(table: OfflineMatch) -> Dictionary:
	if table.phase == "choose_founder":
		for corp in table.corporations:
			if not bool(corp["active"]):
				return table.choose_founder(str(corp["id"]))
		return {"ok": false, "error": "no founder"}
	if table.phase == "choose_survivor":
		return table.choose_survivor(str(table.pending_options[0]))
	if table.phase == "place":
		var hand: Array = table.active_player()["hand"]
		if hand.is_empty():
			return table.pass_turn()
		var lowest := str(hand[0])
		for tile in hand:
			if str(tile) < lowest:
				lowest = str(tile)
		return table.place(lowest)
	if table.phase == "market":
		return table.pass_market()
	return {"ok": false, "error": table.phase}


func _seat(table: OfflineMatch, display_name: String) -> Dictionary:
	for player in table.players:
		if str(player["display_name"]) == display_name:
			return player
	_fail("missing %s" % display_name)
	return {}
