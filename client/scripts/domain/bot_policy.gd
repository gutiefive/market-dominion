extends RefCounted
class_name BotPolicy

## Deterministic local computer. Placement scores fictional dollars for a
## founding, a growth, or a merger, then adds half of the best follow-up
## tile still in hand. Market buys and sells shares and BYTE when that
## score is positive, at most two actions, and never spends the cash floor.
## Ties break by lowest coordinate, fixture order, or the earlier survivor.
## The match generator is not advanced here.


const CASH_FLOOR := 500
const BUY_MAX_SIZE := 14
const BUY_MAX_SENTIMENT := 1
const BUY_OWNED_LIMIT := 5
const SELL_MIN_SIZE := 16
const SELL_MIN_SENTIMENT := 1
const SELL_MIN_OWNED := 2
const BYTE_BUY_MAX := 400
const BYTE_SELL_MIN := 800
const END_FEED_PENALTY := -100000


static func decide(match: OfflineMatch) -> Dictionary:
	if match == null or match.phase == "completed":
		return {"ok": false, "error": "the match is over"}
	if match.phase == "choose_founder":
		return {"ok": true, "command": "choose_founder", "corporation_id": _founder(match)}
	if match.phase == "choose_survivor":
		return {"ok": true, "command": "choose_survivor", "corporation_id": _survivor(match)}
	if match.phase == "place":
		var hand: Array = match.active_player()["hand"]
		if hand.is_empty():
			return {"ok": true, "command": "pass_turn"}
		return {"ok": true, "command": "place", "coordinate": _tile(match, hand)}
	if match.phase == "market":
		return _market(match)
	return {"ok": false, "error": "no computer action for this step"}


static func apply(match: OfflineMatch, decision: Dictionary) -> Dictionary:
	if not bool(decision.get("ok", false)):
		return decision
	var command := str(decision.get("command", ""))
	if command == "place":
		return match.place(str(decision["coordinate"]))
	if command == "pass_turn":
		return match.pass_turn()
	if command == "choose_founder":
		return match.choose_founder(str(decision["corporation_id"]))
	if command == "choose_survivor":
		return match.choose_survivor(str(decision["corporation_id"]))
	if command == "buy_share":
		return match.buy_share(str(decision["corporation_id"]))
	if command == "sell_share":
		return match.sell_share(str(decision["corporation_id"]))
	if command == "buy_byte":
		return match.buy_byte()
	if command == "sell_byte":
		return match.sell_byte()
	if command == "pass_market":
		return match.pass_market()
	return {"ok": false, "error": "unknown computer command"}


static func act(match: OfflineMatch) -> Dictionary:
	return apply(match, decide(match))


static func _market(match: OfflineMatch) -> Dictionary:
	if match.market_actions_left <= 0:
		return {"ok": true, "command": "pass_market"}
	var player := match.active_player()
	var cash := int(player["cash"])
	var shares: Dictionary = player["shares"]
	var best_score := 0
	var best := {"ok": true, "command": "pass_market"}
	for index in match.corporations.size():
		var corp: Dictionary = match.corporations[index]
		var corp_id := str(corp["id"])
		var owned := int(shares.get(corp_id, 0))
		var buy_score := _buy_share_score(match, corp, owned, cash)
		if buy_score > best_score:
			best_score = buy_score
			best = {"ok": true, "command": "buy_share", "corporation_id": corp_id}
		var sell_score := _sell_share_score(match, corp, owned, cash)
		if sell_score > best_score:
			best_score = sell_score
			best = {"ok": true, "command": "sell_share", "corporation_id": corp_id}
	var byte_buy := _buy_byte_score(match, cash)
	if byte_buy > best_score:
		best_score = byte_buy
		best = {"ok": true, "command": "buy_byte"}
	var byte_sell := _sell_byte_score(match, player, cash)
	if byte_sell > best_score:
		best = {"ok": true, "command": "sell_byte"}
	return best


static func _buy_share_score(match: OfflineMatch, corp: Dictionary, owned: int, cash: int) -> int:
	if not bool(corp["active"]) or int(corp["bank_shares"]) < 1 or int(corp["share_price"]) <= 0:
		return 0
	var size := int(corp["size"])
	var sentiment := int(match.sentiment.get(str(corp["sector"]), 0))
	var price := int(corp["share_price"])
	if size > BUY_MAX_SIZE or sentiment > BUY_MAX_SENTIMENT or owned >= BUY_OWNED_LIMIT:
		return 0
	if cash - price < CASH_FLOOR:
		return 0
	return (15 - size) * 30 + (1 - sentiment) * 40 - Pricing.div_nonneg(price, 20) + owned * 80


static func _sell_share_score(match: OfflineMatch, corp: Dictionary, owned: int, cash: int) -> int:
	if not bool(corp["active"]) or int(corp["share_price"]) <= 0 or owned < 1:
		return 0
	var size := int(corp["size"])
	var sentiment := int(match.sentiment.get(str(corp["sector"]), 0))
	var price := int(corp["share_price"])
	var profit := 0
	if owned >= SELL_MIN_OWNED and size >= SELL_MIN_SIZE and sentiment >= SELL_MIN_SENTIMENT:
		profit = (size - 14) * 50 + sentiment * 80 + Pricing.div_nonneg(price, 10)
	var liquidity := 500 if cash < CASH_FLOOR else 0
	return maxi(profit, liquidity)


static func _buy_byte_score(match: OfflineMatch, cash: int) -> int:
	var price := int(match.byte_price)
	if price > BYTE_BUY_MAX or match.byte_exchange < 1 or cash - price < CASH_FLOOR:
		return 0
	return (BYTE_BUY_MAX - price) + 50


static func _sell_byte_score(match: OfflineMatch, player: Dictionary, cash: int) -> int:
	if int(player["byte_count"]) < 1:
		return 0
	var price := int(match.byte_price)
	var profit := 0
	if price >= BYTE_SELL_MIN:
		profit = (price - 700) + 30
	var liquidity := 500 if cash < CASH_FLOOR else 0
	return maxi(profit, liquidity)


static func _tile(match: OfflineMatch, hand: Array) -> String:
	var filled := _filled(match)
	var company := _company_map(match)
	var best := ""
	var best_score := 0
	var chosen := false
	for coordinate in hand:
		var text := str(coordinate)
		var score := _placement_score(match, text, hand, filled, company)
		if not chosen or score > best_score or (score == best_score and text < best):
			chosen = true
			best = text
			best_score = score
	return best


static func _placement_score(match: OfflineMatch, coordinate: String, hand: Array, filled: Dictionary, company: Dictionary) -> int:
	var immediate := _immediate(match, coordinate, filled, company, {})
	var projected := _project(match, coordinate, filled, company, {})
	var bonus := 0
	var next_filled: Dictionary = projected["filled"]
	var next_company: Dictionary = projected["company"]
	var next_extra: Dictionary = projected["extra"]
	for other in hand:
		var follow := str(other)
		if follow == coordinate or bool(next_filled.get(follow, false)):
			continue
		var value := _immediate(match, follow, next_filled, next_company, next_extra)
		if value > bonus:
			bonus = value
	if bonus > 0:
		immediate += Pricing.div_nonneg(bonus, 2)
	return immediate


static func _immediate(match: OfflineMatch, coordinate: String, filled: Dictionary, company: Dictionary, extra: Dictionary) -> int:
	if bool(filled.get(coordinate, false)):
		return END_FEED_PENALTY
	var board := filled.duplicate()
	board[coordinate] = true
	var touched := BoardGraph.component(coordinate, board)
	var company_ids := _ids_in(touched, company)
	if company_ids.size() >= 2:
		return _merger_tile(match, company_ids, touched.size(), company, extra)
	if company_ids.size() == 1:
		return _growth_value(match, company_ids[0], touched.size(), company, extra)
	if touched.size() >= 2 and not _inactive_ids(match, company).is_empty():
		return _found_value(match, touched.size(), company)
	return 0


static func _project(match: OfflineMatch, coordinate: String, filled: Dictionary, company: Dictionary, extra: Dictionary) -> Dictionary:
	var board := filled.duplicate()
	board[coordinate] = true
	var owners := company.duplicate()
	var granted := extra.duplicate()
	var touched := BoardGraph.component(coordinate, board)
	var company_ids := _ids_in(touched, owners)
	if company_ids.size() >= 2:
		var survivor := _best_merger_id(match, company_ids, touched.size(), owners, granted)
		for cell in touched:
			owners[str(cell)] = survivor
	elif company_ids.size() == 1:
		var grown := str(company_ids[0])
		for cell in touched:
			owners[str(cell)] = grown
	elif touched.size() >= 2:
		var founder := _best_founder_id(match, touched.size(), owners)
		if founder != "":
			for cell in touched:
				owners[str(cell)] = founder
			granted[founder] = int(granted.get(founder, 0)) + 1
	return {"filled": board, "company": owners, "extra": granted}


static func _found_value(match: OfflineMatch, cluster: int, company: Dictionary) -> int:
	var best := 0
	for corp_id in _inactive_ids(match, company):
		var price := _quoted(match, corp_id, cluster)
		if price > best:
			best = price
	return best


static func _growth_value(match: OfflineMatch, corp_id: String, new_size: int, company: Dictionary, extra: Dictionary) -> int:
	var old_size := int(_sizes(company).get(corp_id, 0))
	var delta := _quoted(match, corp_id, new_size) - _quoted(match, corp_id, old_size)
	var ours := _held(match, corp_id, extra)
	var others := _others(match, corp_id)
	if new_size >= match.end_size and ours == 0 and others > 0:
		return END_FEED_PENALTY
	return ours * delta - others * delta


static func _merger_tile(match: OfflineMatch, company_ids: Array, new_size: int, company: Dictionary, extra: Dictionary) -> int:
	var sizes := _sizes(company)
	var top := 0
	for corp_id in company_ids:
		top = maxi(top, int(sizes.get(str(corp_id), 0)))
	var best := END_FEED_PENALTY
	var found := false
	for index in match.corporations.size():
		var corp_id := str(match.corporations[index]["id"])
		if not company_ids.has(corp_id) or int(sizes.get(corp_id, 0)) != top:
			continue
		var value := _merger_value(match, corp_id, company_ids, new_size, sizes, extra)
		if not found or value > best:
			found = true
			best = value
	return best


static func _best_merger_id(match: OfflineMatch, company_ids: Array, new_size: int, company: Dictionary, extra: Dictionary) -> String:
	var sizes := _sizes(company)
	var top := 0
	for corp_id in company_ids:
		top = maxi(top, int(sizes.get(str(corp_id), 0)))
	var best_id := ""
	var best := 0
	var found := false
	for index in match.corporations.size():
		var corp_id := str(match.corporations[index]["id"])
		if not company_ids.has(corp_id) or int(sizes.get(corp_id, 0)) != top:
			continue
		var value := _merger_value(match, corp_id, company_ids, new_size, sizes, extra)
		if not found or value > best:
			found = true
			best = value
			best_id = corp_id
	return best_id


static func _merger_value(match: OfflineMatch, survivor: String, company_ids: Array, new_size: int, sizes: Dictionary, extra: Dictionary) -> int:
	var old_size := int(sizes.get(survivor, 0))
	var delta := _quoted(match, survivor, new_size) - _quoted(match, survivor, old_size)
	var ours := _held(match, survivor, extra)
	var value := ours * delta - _others(match, survivor) * delta
	var self_id := str(match.active_player()["id"])
	for corp_id in company_ids:
		var loser := str(corp_id)
		if loser == survivor:
			continue
		var holdings := _holdings(match, loser, extra)
		var payouts := Mergers.bonus_payouts(_quoted(match, loser, int(sizes.get(loser, 0))), holdings)
		for player in match.players:
			var amount := int(payouts.get(str(player["id"]), 0))
			if str(player["id"]) == self_id:
				value += amount
			else:
				value -= amount
	return value


static func _founder(match: OfflineMatch) -> String:
	var cluster := match.pending.size()
	if cluster < 2:
		cluster = 2
	return _best_founder_id(match, cluster, _company_map(match))


static func _best_founder_id(match: OfflineMatch, cluster: int, company: Dictionary) -> String:
	var inactive := _inactive_ids(match, company)
	var best_id := ""
	var best_price := -1
	var best_index := 999
	for index in match.corporations.size():
		var corp_id := str(match.corporations[index]["id"])
		if not inactive.has(corp_id):
			continue
		var price := _quoted(match, corp_id, cluster)
		if price > best_price or (price == best_price and index < best_index):
			best_id = corp_id
			best_price = price
			best_index = index
	return best_id


static func _survivor(match: OfflineMatch) -> String:
	var best := str(match.pending_options[0]) if not match.pending_options.is_empty() else ""
	var best_score := 0
	var best_shares := -1
	var best_index := 999
	var chosen := false
	var involved := _involved(match)
	for index in match.pending_options.size():
		var corp_id := str(match.pending_options[index])
		var score := _survivor_score(match, corp_id, involved)
		var held := _own(match, corp_id)
		var better := not chosen or score > best_score
		if chosen and score == best_score and held > best_shares:
			better = true
		if chosen and score == best_score and held == best_shares and index < best_index:
			better = true
		if better:
			chosen = true
			best = corp_id
			best_score = score
			best_shares = held
			best_index = index
	return best


static func _survivor_score(match: OfflineMatch, survivor: String, involved: Array) -> int:
	var new_size := match.pending.size()
	var corp := _corp(match, survivor)
	var old_price := int(corp.get("share_price", 0))
	var new_price := _quoted(match, survivor, new_size) if new_size > 0 else 0
	var delta := new_price - old_price
	var ours := _own(match, survivor)
	var value := ours * delta - _others(match, survivor) * delta
	var self_id := str(match.active_player()["id"])
	for corp_id in involved:
		var loser := str(corp_id)
		if loser == survivor:
			continue
		var loser_corp := _corp(match, loser)
		var holdings := _holdings(match, loser, {})
		var payouts := Mergers.bonus_payouts(int(loser_corp.get("share_price", 0)), holdings)
		for player in match.players:
			var amount := int(payouts.get(str(player["id"]), 0))
			if str(player["id"]) == self_id:
				value += amount
			else:
				value -= amount
	return value


static func _involved(match: OfflineMatch) -> Array:
	var involved: Array = []
	for corp_id in match.pending_options:
		var text := str(corp_id)
		if not involved.has(text):
			involved.append(text)
	for cell in match.pending:
		var owner := str(match.company_of.get(str(cell), ""))
		if owner != "" and not involved.has(owner):
			involved.append(owner)
	return involved


static func _ids_in(touched: PackedStringArray, company: Dictionary) -> Array:
	var company_ids: Array = []
	for cell in touched:
		var corp_id := str(company.get(str(cell), ""))
		if corp_id != "" and not company_ids.has(corp_id):
			company_ids.append(corp_id)
	return company_ids


static func _inactive_ids(match: OfflineMatch, company: Dictionary) -> Array:
	var sizes := _sizes(company)
	var inactive: Array = []
	for corp in match.corporations:
		var corp_id := str(corp["id"])
		if int(sizes.get(corp_id, 0)) < 2:
			inactive.append(corp_id)
	return inactive


static func _sizes(company: Dictionary) -> Dictionary:
	var sizes := {}
	for cell in company.keys():
		var corp_id := str(company[cell])
		if corp_id == "":
			continue
		sizes[corp_id] = int(sizes.get(corp_id, 0)) + 1
	return sizes


static func _filled(match: OfflineMatch) -> Dictionary:
	var filled := {}
	for cell in match.occupied.keys():
		if bool(match.occupied[cell]):
			filled[str(cell)] = true
	return filled


static func _company_map(match: OfflineMatch) -> Dictionary:
	var company := {}
	for cell in match.company_of.keys():
		company[str(cell)] = str(match.company_of[cell])
	return company


static func _quoted(match: OfflineMatch, corp_id: String, size: int) -> int:
	if size <= 0:
		return 0
	var sentiment := int(match.sentiment.get(str(_corp(match, corp_id).get("sector", "")), 0))
	var price := Pricing.share_price(size, sentiment)
	if price < 0:
		return 0
	return price


static func _holdings(match: OfflineMatch, corp_id: String, extra: Dictionary) -> Dictionary:
	var self_id := str(match.active_player()["id"])
	var holdings := {}
	for player in match.players:
		var shares: Dictionary = player["shares"]
		var count := int(shares.get(corp_id, 0))
		if str(player["id"]) == self_id:
			count += int(extra.get(corp_id, 0))
		holdings[str(player["id"])] = count
	return holdings


static func _corp(match: OfflineMatch, corp_id: String) -> Dictionary:
	for corp in match.corporations:
		if str(corp["id"]) == corp_id:
			return corp
	return {}


static func _own(match: OfflineMatch, corp_id: String) -> int:
	var shares: Dictionary = match.active_player()["shares"]
	return int(shares.get(corp_id, 0))


static func _held(match: OfflineMatch, corp_id: String, extra: Dictionary) -> int:
	return _own(match, corp_id) + int(extra.get(corp_id, 0))


static func _others(match: OfflineMatch, corp_id: String) -> int:
	var self_id := str(match.active_player()["id"])
	var total := 0
	for player in match.players:
		if str(player["id"]) == self_id:
			continue
		var shares: Dictionary = player["shares"]
		total += int(shares.get(corp_id, 0))
	return total
