extends SceneTree

## Local computers play a finished match from the seed, and the same seed plays it again.


var _failures: PackedStringArray = []


func _initialize() -> void:
	_check_founding_beats_an_isolated_tile()
	_check_isolated_tiles_use_autopass_order()
	_check_lookahead_sets_up_a_founding()
	_check_three_plies_prefer_a_longer_setup()
	_check_five_plies_beat_three_ahead()
	_check_growth_does_not_feed_a_large_opponent()
	_check_merger_uses_holdings()
	_check_founder_and_survivor_choices()
	_check_survivor_prefers_the_higher_payout()
	_check_market_buys_sells_and_trades_byte()
	_check_tuned_dollar_scores()
	_check_difficulties()
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
	print("M8_PLACEMENT_50_US %d nodes %d" % [elapsed, BotPolicy.last_placement_nodes])


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


func _check_five_plies_beat_three_ahead() -> void:
	# All five brands are already on the board, so the loose block cannot be founded.
	# B1 grows ORBIT at once (four shares). Three plies can grow NOVA along B8 and
	# two more tiles, but they never reach the block, so B1 wins that search.
	# Five plies follow B8, C8, and D8, then E8 takes the block into NOVA.
	var table = _blob_table()
	BotPolicy.placement_plies = 3
	var shallow := BotPolicy.decide(table)
	var shallow_nodes := BotPolicy.last_placement_nodes
	BotPolicy.placement_plies = 5
	var started := Time.get_ticks_usec()
	var deep := BotPolicy.decide(table)
	var deep_nodes := BotPolicy.last_placement_nodes
	for _repeat in range(19):
		BotPolicy.decide(table)
	var elapsed := Time.get_ticks_usec() - started
	var again := BotPolicy.decide(table)
	BotPolicy.placement_plies = 5
	print("M8_FIVE_PLIES shallow %s nodes %d deep %s nodes %d us %d" % [
		str(shallow.get("coordinate", "")),
		shallow_nodes,
		str(deep.get("coordinate", "")),
		deep_nodes,
		elapsed,
	])
	if str(shallow.get("coordinate", "")) != "B1":
		_fail("three-ahead greed %s" % str(shallow))
	if str(deep.get("coordinate", "")) != "B8":
		_fail("five-ahead setup %s" % str(deep))
	if str(again.get("coordinate", "")) != str(deep.get("coordinate", "")):
		_fail("five-ahead drifted %s" % str(again))
	if deep_nodes > BotPolicy.MAX_PLACEMENT_NODES or deep_nodes < 1:
		_fail("five-ahead nodes %d" % deep_nodes)
	if elapsed > 1600000:
		_fail("five-ply search %d us" % elapsed)


func _blob_table():
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	ada["hand"] = ["B1", "B8", "C8", "D8", "E8"]
	ada["shares"]["nova_ai"] = 2
	ada["shares"]["orbit_pay"] = 4
	_plant(table, "nova_ai", ["A8", "A9"])
	_plant(table, "orbit_pay", ["A1", "A2"])
	_plant(table, "volt_grid", ["C4", "C5"])
	_plant(table, "pulse_media", ["I1", "I2"])
	_plant(table, "evermart", ["A4", "A5"])
	for column in ["F", "G", "H", "I"]:
		for row in range(5, 10):
			table.occupied["%s%s" % [column, str(row)]] = true
	return table


func _plant(table, corp_id: String, cells: Array) -> void:
	for cell in cells:
		var text := str(cell)
		table.occupied[text] = true
		table.company_of[text] = corp_id
	for corp in table.corporations:
		if str(corp["id"]) != corp_id:
			continue
		corp["active"] = true
		corp["size"] = cells.size()
		corp["share_price"] = 100 + 50 * cells.size()


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
	if str(held.get("command", "")) != "buy_share" or str(held.get("corporation_id", "")) != "nova_ai":
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


func _check_tuned_dollar_scores() -> void:
	_check_byte_midrange_and_share_cap()
	_check_fair_byte_contest_and_one_share()
	_check_long_setup_beats_immediate_gain()
	_check_new_reply_outweighs_a_small_growth()
	_restore_score_defaults()


func _restore_score_defaults() -> void:
	BotPolicy.set_difficulty("normal")


func _check_byte_midrange_and_share_cap() -> void:
	var mid = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(mid, "Ada")
	mid.turn_index = int(ada["turn_order_index"])
	mid.phase = "market"
	mid.market_actions_left = 2
	mid.byte_price = 440
	var bought := BotPolicy.decide(mid)
	if str(bought.get("command", "")) != "buy_byte":
		_fail("mid byte buy %s" % str(bought))
	mid.byte_price = 640
	var quiet := BotPolicy.decide(mid)
	if str(quiet.get("command", "")) != "pass_market":
		_fail("near byte %s" % str(quiet))
	mid.byte_price = 720
	ada["byte_count"] = 1
	mid.byte_exchange = 29
	var sold := BotPolicy.decide(mid)
	if str(sold.get("command", "")) != "sell_byte":
		_fail("mid byte sell %s" % str(sold))
	var reserved = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var poor := _seat(reserved, "Ada")
	reserved.turn_index = int(poor["turn_order_index"])
	reserved.phase = "market"
	reserved.market_actions_left = 1
	reserved.byte_price = 440
	poor["cash"] = 900
	var held_cash := BotPolicy.decide(reserved)
	if str(held_cash.get("command", "")) != "pass_market":
		_fail("mid byte floor %s" % str(held_cash))
	var share_table = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var buyer := _seat(share_table, "Ada")
	share_table.turn_index = int(buyer["turn_order_index"])
	share_table.phase = "market"
	share_table.market_actions_left = 1
	share_table.byte_price = 440
	var nova: Dictionary = share_table.corporations[0]
	nova["active"] = true
	nova["size"] = 2
	nova["share_price"] = 200
	nova["bank_shares"] = 20
	var share := BotPolicy.decide(share_table)
	if str(share.get("command", "")) != "buy_share" or str(share.get("corporation_id", "")) != "nova_ai":
		_fail("share over mid byte %s" % str(share))
	buyer["shares"]["nova_ai"] = 3
	nova["bank_shares"] = 17
	share_table.byte_price = 500
	var capped := BotPolicy.decide(share_table)
	if str(capped.get("command", "")) != "pass_market":
		_fail("fourth share %s" % str(capped))
	var trim = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var holder := _seat(trim, "Ada")
	trim.turn_index = int(holder["turn_order_index"])
	trim.phase = "market"
	trim.market_actions_left = 1
	holder["shares"]["orbit_pay"] = 4
	var orbit: Dictionary = trim.corporations[1]
	orbit["active"] = true
	orbit["size"] = 12
	orbit["share_price"] = 700
	orbit["bank_shares"] = 16
	var trimmed := BotPolicy.decide(trim)
	if str(trimmed.get("command", "")) != "sell_share" or str(trimmed.get("corporation_id", "")) != "orbit_pay":
		_fail("trim modest %s" % str(trimmed))
	var hot = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var seller := _seat(hot, "Ada")
	hot.turn_index = int(seller["turn_order_index"])
	hot.phase = "market"
	hot.market_actions_left = 1
	hot.sentiment["energy"] = 2
	seller["shares"]["volt_grid"] = 2
	var volt: Dictionary = hot.corporations[2]
	volt["active"] = true
	volt["size"] = 8
	volt["share_price"] = 600
	volt["bank_shares"] = 18
	var locked := BotPolicy.decide(hot)
	if str(locked.get("command", "")) != "sell_share" or str(locked.get("corporation_id", "")) != "volt_grid":
		_fail("hot modest %s" % str(locked))


func _check_fair_byte_contest_and_one_share() -> void:
	var under = _market_table()
	under.byte_price = 460
	if str(BotPolicy.decide(under).get("command", "")) != "buy_byte":
		_fail("byte 460 %s" % str(BotPolicy.decide(under)))
	under.byte_price = 490
	if str(BotPolicy.decide(under).get("command", "")) != "buy_byte":
		_fail("byte 490 %s" % str(BotPolicy.decide(under)))
	under.byte_price = 500
	_seat(under, "Ada")["byte_count"] = 1
	under.byte_exchange = 29
	if str(BotPolicy.decide(under).get("command", "")) != "pass_market":
		_fail("byte 500 hold %s" % str(BotPolicy.decide(under)))
	for price in [510, 640, 690]:
		var selling = _market_table()
		selling.byte_price = price
		_seat(selling, "Ada")["byte_count"] = 1
		selling.byte_exchange = 29
		var decision := BotPolicy.decide(selling)
		if str(decision.get("command", "")) != "sell_byte":
			_fail("byte %d sell %s" % [price, str(decision)])
	var floor = _market_table()
	floor.byte_price = 460
	_seat(floor, "Ada")["cash"] = 950
	if str(BotPolicy.decide(floor).get("command", "")) != "pass_market":
		_fail("byte 460 floor %s" % str(BotPolicy.decide(floor)))
	var behind = _market_table()
	_plant_market(behind, "pulse_media", 18, 1000, 2)
	var ada := _seat(behind, "Ada")
	var rowan := _seat(behind, "Rowan")
	ada["shares"]["pulse_media"] = 1
	rowan["shares"]["pulse_media"] = 3
	var dumped := BotPolicy.decide(behind)
	if str(dumped.get("command", "")) != "sell_share" or str(dumped.get("corporation_id", "")) != "pulse_media":
		_fail("one share behind %s" % str(dumped))
	var sole = _market_table()
	_plant_market(sole, "pulse_media", 18, 1000, 2)
	_seat(sole, "Ada")["shares"]["pulse_media"] = 1
	if str(BotPolicy.decide(sole).get("command", "")) != "pass_market":
		_fail("one share sole %s" % str(BotPolicy.decide(sole)))
	var tied = _market_table()
	_plant_market(tied, "pulse_media", 18, 1000, 2)
	_seat(tied, "Ada")["shares"]["pulse_media"] = 2
	_seat(tied, "Rowan")["shares"]["pulse_media"] = 2
	if str(BotPolicy.decide(tied).get("command", "")) != "pass_market":
		_fail("tied large %s" % str(BotPolicy.decide(tied)))
	var fight = _market_table()
	_plant_market(fight, "nova_ai", 6, 400, 0)
	_seat(fight, "Ada")["shares"]["nova_ai"] = 3
	_seat(fight, "Rowan")["shares"]["nova_ai"] = 3
	var taken := BotPolicy.decide(fight)
	if str(taken.get("command", "")) != "buy_share" or str(taken.get("corporation_id", "")) != "nova_ai":
		_fail("contest buy %s" % str(taken))
	if not bool(BotPolicy.apply(fight, taken).get("ok", false)):
		_fail("contest buy failed")
	var lead := BotPolicy.decide(fight)
	if str(lead.get("command", "")) != "pass_market":
		_fail("contest stopped %s" % str(lead))
	if int(_seat(fight, "Ada")["shares"]["nova_ai"]) != 4:
		_fail("contest book %s" % str(_seat(fight, "Ada")["shares"]["nova_ai"]))


func _market_table():
	var table = OfflineMatch.create(4, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	table.phase = "market"
	table.market_actions_left = 2
	return table


func _plant_market(table, corp_id: String, size: int, price: int, sentiment: int) -> void:
	for corp in table.corporations:
		if str(corp["id"]) != corp_id:
			continue
		corp["active"] = true
		corp["size"] = size
		corp["share_price"] = price
		corp["bank_shares"] = 14
		var sector := str(corp["sector"])
		table.sentiment[sector] = sentiment


func _check_long_setup_beats_immediate_gain() -> void:
	# B1 grows ORBIT by one tile (four shares, $200) and does not lead into NOVA.
	# The NOVA path is B8, C8, D8, then E8 takes a 14-cell block.
	# Keeping half of each later tile still places B1. Three quarters places B8.
	var table = _discount_table()
	BotPolicy.continuation_num = 1
	BotPolicy.continuation_den = 2
	var cash_now := BotPolicy.decide(table)
	BotPolicy.continuation_num = 3
	BotPolicy.continuation_den = 4
	var setup := BotPolicy.decide(table)
	var again := BotPolicy.decide(table)
	_restore_score_defaults()
	print("M8_DISCOUNT half %s threeq %s" % [str(cash_now.get("coordinate", "")), str(setup.get("coordinate", ""))])
	if str(cash_now.get("coordinate", "")) != "B1":
		_fail("half discount %s" % str(cash_now))
	if str(setup.get("coordinate", "")) != "B8":
		_fail("three quarter setup %s" % str(setup))
	if str(again.get("coordinate", "")) != "B8":
		_fail("three quarter drifted %s" % str(again))


func _discount_table():
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	table.turn_index = int(ada["turn_order_index"])
	ada["hand"] = ["B1", "B8", "C8", "D8", "E8"]
	ada["shares"]["nova_ai"] = 2
	ada["shares"]["orbit_pay"] = 4
	_plant(table, "nova_ai", ["A8", "A9"])
	_plant(table, "orbit_pay", ["A1", "A2"])
	_plant(table, "volt_grid", ["C4", "C5"])
	_plant(table, "pulse_media", ["I1", "I2"])
	_plant(table, "evermart", ["A4", "A5"])
	for column in ["F", "G"]:
		for row in range(5, 10):
			table.occupied["%s%s" % [column, str(row)]] = true
	for row in range(6, 10):
		table.occupied["H%s" % str(row)] = true
	return table


func _check_new_reply_outweighs_a_small_growth() -> void:
	# B1 grows NOVA ($100) and lets Rowan merge it into ORBIT on the next ply.
	# A quarter of every reply, including the growth Rowan already has, ties B1 with I9,
	# and the lower coordinate plays B1. Half of only the new merger prefers I9.
	var table = _reply_table()
	BotPolicy.threat_div = 4
	BotPolicy.threat_uses_marginal = false
	var absolute := BotPolicy.decide(table)
	BotPolicy.threat_div = 2
	BotPolicy.threat_uses_marginal = true
	var marginal := BotPolicy.decide(table)
	var again := BotPolicy.decide(table)
	_restore_score_defaults()
	print("M8_REPLY absolute %s marginal %s" % [str(absolute.get("coordinate", "")), str(marginal.get("coordinate", ""))])
	if str(absolute.get("coordinate", "")) != "B1":
		_fail("absolute reply %s" % str(absolute))
	if str(marginal.get("coordinate", "")) != "I9":
		_fail("marginal reply %s" % str(marginal))
	if str(again.get("coordinate", "")) != "I9":
		_fail("marginal reply drifted %s" % str(again))


func _reply_table():
	var table = OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	var ada := _seat(table, "Ada")
	var rowan := _seat(table, "Rowan")
	table.turn_index = int(ada["turn_order_index"])
	ada["hand"] = ["B1", "I9"]
	ada["shares"]["nova_ai"] = 2
	rowan["shares"]["orbit_pay"] = 4
	_plant(table, "nova_ai", ["A1", "A2"])
	_plant(table, "orbit_pay", ["D1", "D2"])
	_plant(table, "volt_grid", ["A8", "A9"])
	_plant(table, "pulse_media", ["I1", "I2"])
	_plant(table, "evermart", ["H5", "H6"])
	return table


func _check_difficulties() -> void:
	_check_easy_plays_legally_and_misses()
	_check_hard_buys_a_larger_contest()
	_check_each_difficulty_replays()
	_restore_score_defaults()


func _check_easy_plays_legally_and_misses() -> void:
	BotPolicy.set_difficulty("easy")
	var chain = _chain_table()
	var started := Time.get_ticks_usec()
	var greedy := BotPolicy.decide(chain)
	var greedy_again := BotPolicy.decide(chain)
	for _repeat in range(48):
		BotPolicy.decide(chain)
	var easy_us := Time.get_ticks_usec() - started
	if str(greedy.get("coordinate", "")) != "B1" or str(greedy_again.get("coordinate", "")) != "B1":
		_fail("easy chain %s %s" % [str(greedy), str(greedy_again)])
	BotPolicy.set_difficulty("normal")
	if str(BotPolicy.decide(_chain_table()).get("coordinate", "")) != "E3":
		_fail("normal chain after easy")
	BotPolicy.set_difficulty("hard")
	if BotPolicy.placement_plies != 5 or BotPolicy.continuation_num != 3 or BotPolicy.continuation_den != 4 or BotPolicy.market_style != "sharp":
		_fail("hard knobs plies %d keep %d/%d style %s" % [BotPolicy.placement_plies, BotPolicy.continuation_num, BotPolicy.continuation_den, BotPolicy.market_style])
	var hard_chain := BotPolicy.decide(_chain_table())
	var hard_chain_again := BotPolicy.decide(_chain_table())
	if str(hard_chain.get("coordinate", "")) != "E3" or str(hard_chain_again.get("coordinate", "")) != "E3":
		_fail("hard chain %s %s" % [str(hard_chain), str(hard_chain_again)])
	BotPolicy.set_difficulty("easy")
	var easy_blob := BotPolicy.decide(_blob_table())
	if str(easy_blob.get("coordinate", "")) != "B1":
		_fail("easy blob %s" % str(easy_blob))
	BotPolicy.set_difficulty("hard")
	var hard_blob := BotPolicy.decide(_blob_table())
	var hard_blob_again := BotPolicy.decide(_blob_table())
	if str(hard_blob.get("coordinate", "")) != "B8" or str(hard_blob_again.get("coordinate", "")) != "B8":
		_fail("hard blob %s %s" % [str(hard_blob), str(hard_blob_again)])
	BotPolicy.set_difficulty("easy")
	var fight = _market_table()
	_plant_market(fight, "nova_ai", 6, 400, 0)
	_seat(fight, "Ada")["shares"]["nova_ai"] = 3
	_seat(fight, "Rowan")["shares"]["nova_ai"] = 3
	if str(BotPolicy.decide(fight).get("command", "")) != "pass_market":
		_fail("easy contest %s" % str(BotPolicy.decide(fight)))
	var coin = _market_table()
	coin.byte_price = 300
	if str(BotPolicy.decide(coin).get("command", "")) != "pass_market":
		_fail("easy byte %s" % str(BotPolicy.decide(coin)))
	var second = _market_table()
	_plant_market(second, "nova_ai", 2, 200, 0)
	_seat(second, "Ada")["shares"]["nova_ai"] = 1
	if str(BotPolicy.decide(second).get("command", "")) != "pass_market":
		_fail("easy second share %s" % str(BotPolicy.decide(second)))
	var floor = _market_table()
	_plant_market(floor, "nova_ai", 2, 200, 0)
	_seat(floor, "Ada")["cash"] = 600
	if str(BotPolicy.decide(floor).get("command", "")) != "pass_market":
		_fail("easy floor %s" % str(BotPolicy.decide(floor)))
	var broke = _market_table()
	_plant_market(broke, "nova_ai", 2, 200, 0)
	var poor := _seat(broke, "Ada")
	poor["cash"] = 400
	poor["shares"]["nova_ai"] = 1
	var sold := BotPolicy.decide(broke)
	if str(sold.get("command", "")) != "sell_share" or str(sold.get("corporation_id", "")) != "nova_ai":
		_fail("easy liquidity %s" % str(sold))
	if not bool(BotPolicy.apply(broke, sold).get("ok", false)) or int(poor["cash"]) != 600 or int(poor["shares"]["nova_ai"]) != 0:
		_fail("easy liquidity book cash %d shares %s" % [int(poor["cash"]), str(poor["shares"])])
	var empty = _market_table()
	_seat(empty, "Ada")["cash"] = 400
	if str(BotPolicy.decide(empty).get("command", "")) != "pass_market":
		_fail("easy sold an empty book %s" % str(BotPolicy.decide(empty)))
	var opener = _market_table()
	_plant_market(opener, "nova_ai", 2, 200, 0)
	var buyer := _seat(opener, "Ada")
	buyer["cash"] = 800
	var bought := BotPolicy.decide(opener)
	if str(bought.get("command", "")) != "buy_share" or str(bought.get("corporation_id", "")) != "nova_ai":
		_fail("easy first share %s" % str(bought))
	if not bool(BotPolicy.apply(opener, bought).get("ok", false)):
		_fail("easy first share rejected")
	if int(buyer["cash"]) != 600 or int(buyer["shares"]["nova_ai"]) != 1:
		_fail("easy first share book cash %d shares %s" % [int(buyer["cash"]), str(buyer["shares"])])
	print("M8_EASY chain B1 blob B1 contest pass byte pass us %d" % easy_us)


func _check_hard_buys_a_larger_contest() -> void:
	var big = _market_table()
	_plant_market(big, "nova_ai", 16, 900, 0)
	_seat(big, "Ada")["shares"]["nova_ai"] = 3
	_seat(big, "Rowan")["shares"]["nova_ai"] = 3
	BotPolicy.set_difficulty("normal")
	if str(BotPolicy.decide(big).get("command", "")) != "pass_market":
		_fail("normal size 16 %s" % str(BotPolicy.decide(big)))
	BotPolicy.set_difficulty("easy")
	if str(BotPolicy.decide(big).get("command", "")) != "pass_market":
		_fail("easy size 16 %s" % str(BotPolicy.decide(big)))
	BotPolicy.set_difficulty("hard")
	var taken := BotPolicy.decide(big)
	var taken_again := BotPolicy.decide(big)
	if str(taken.get("command", "")) != "buy_share" or str(taken.get("corporation_id", "")) != "nova_ai":
		_fail("hard size 16 %s" % str(taken))
	if str(taken_again.get("command", "")) != "buy_share" or str(taken_again.get("corporation_id", "")) != "nova_ai":
		_fail("hard size 16 drifted %s" % str(taken_again))
	if not bool(BotPolicy.apply(big, taken).get("ok", false)):
		_fail("hard size 16 rejected")
	if int(_seat(big, "Ada")["shares"]["nova_ai"]) != 4:
		_fail("hard size 16 book %s" % str(_seat(big, "Ada")["shares"]))
	if str(BotPolicy.decide(big).get("command", "")) != "pass_market":
		_fail("hard contest continued %s" % str(BotPolicy.decide(big)))
	var huge = _market_table()
	_plant_market(huge, "nova_ai", 19, 900, 0)
	_seat(huge, "Ada")["shares"]["nova_ai"] = 3
	_seat(huge, "Rowan")["shares"]["nova_ai"] = 3
	if str(BotPolicy.decide(huge).get("command", "")) != "pass_market":
		_fail("hard size 19 %s" % str(BotPolicy.decide(huge)))
	var hot = _market_table()
	_plant_market(hot, "nova_ai", 6, 400, 2)
	_seat(hot, "Ada")["shares"]["nova_ai"] = 3
	_seat(hot, "Rowan")["shares"]["nova_ai"] = 3
	if str(BotPolicy.decide(hot).get("command", "")) != "pass_market":
		_fail("hard sentiment %s" % str(BotPolicy.decide(hot)))
	var tied = _market_table()
	_plant_market(tied, "pulse_media", 18, 1000, 2)
	_seat(tied, "Ada")["shares"]["pulse_media"] = 2
	_seat(tied, "Rowan")["shares"]["pulse_media"] = 2
	if str(BotPolicy.decide(tied).get("command", "")) != "pass_market":
		_fail("hard tied sale %s" % str(BotPolicy.decide(tied)))
	print("M8_HARD chain E3 blob B8 size16 buy size19 pass")


func _check_each_difficulty_replays() -> void:
	var easy_a := _prefix(7710, 16, "easy")
	var easy_b := _prefix(7710, 16, "easy")
	var normal_a := _prefix(7710, 16, "normal")
	var normal_b := _prefix(7710, 16, "normal")
	var hard_a := _prefix(7710, 16, "hard")
	var hard_b := _prefix(7710, 16, "hard")
	BotPolicy.set_difficulty("mystery")
	if BotPolicy.difficulty != "normal" or BotPolicy.placement_plies != 5 or BotPolicy.continuation_num != 3 or BotPolicy.continuation_den != 4 or BotPolicy.market_style != "standard":
		_fail("unknown difficulty %s plies %d style %s" % [BotPolicy.difficulty, BotPolicy.placement_plies, BotPolicy.market_style])
	if not bool(easy_a.get("ok", false)) or str(easy_a["trace"]) != str(easy_b["trace"]):
		_fail("easy replay %s" % str(easy_a.get("error", "diverged")))
	if not bool(normal_a.get("ok", false)) or str(normal_a["trace"]) != str(normal_b["trace"]):
		_fail("normal replay %s" % str(normal_a.get("error", "diverged")))
	if not bool(hard_a.get("ok", false)) or str(hard_a["trace"]) != str(hard_b["trace"]):
		_fail("hard replay %s" % str(hard_a.get("error", "diverged")))
	if str(easy_a["trace"]) == str(normal_a["trace"]):
		_fail("easy matched normal")
	var easy_lines := str(easy_a["trace"]).split("\n")
	var normal_lines := str(normal_a["trace"]).split("\n")
	var first_diff := "none"
	var compared := mini(easy_lines.size(), normal_lines.size())
	for index in compared:
		if easy_lines[index] != normal_lines[index]:
			first_diff = "%d easy %s normal %s" % [index + 1, easy_lines[index], normal_lines[index]]
			break
	var hard_note := "same" if str(hard_a["trace"]) == str(normal_a["trace"]) else "different"
	print("M8_DIFFICULTY easy %d normal %d hard %d hard_vs_normal %s first %s" % [
		str(easy_a["trace"]).length(),
		str(normal_a["trace"]).length(),
		str(hard_a["trace"]).length(),
		hard_note,
		first_diff,
	])


func _prefix(seed_value: int, limit: int, level: String) -> Dictionary:
	BotPolicy.set_difficulty(level)
	var table = OfflineMatch.create(seed_value, ["Rowan", "Ada", "Bo"], ["Ada", "Bo"])
	if table == null:
		return {"ok": false, "error": "deal"}
	var trace: PackedStringArray = []
	var steps := 0
	while table.phase != "completed" and steps < limit:
		steps += 1
		var decision := BotPolicy.decide(table)
		if not bool(decision.get("ok", false)):
			return {"ok": false, "error": str(decision.get("error", decision))}
		trace.append("%s:%s" % [str(decision["command"]), str(decision.get("coordinate", decision.get("corporation_id", "")))])
		var result := BotPolicy.apply(table, decision)
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": str(result.get("error", result))}
	return {"ok": true, "trace": "\n".join(trace)}


func _check_full_matches() -> void:
	_restore_score_defaults()
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
