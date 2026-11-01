extends RefCounted
class_name BotPolicy

## Deterministic local computer. Ties use the same safe order as a timed
## autopass: lowest coordinate, fixture order, or the first listed survivor.
## The match generator is not advanced here, so event draws stay on the deal seed.


const CASH_RESERVE := 1000
const SHARE_CAP := 4


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
		if match.market_actions_left <= 0 or match.market_actions_left < match.market_limit:
			return {"ok": true, "command": "pass_market"}
		var corp_id := _buy_target(match)
		if corp_id == "":
			return {"ok": true, "command": "pass_market"}
		return {"ok": true, "command": "buy_share", "corporation_id": corp_id}
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
	if command == "pass_market":
		return match.pass_market()
	return {"ok": false, "error": "unknown computer command"}


static func act(match: OfflineMatch) -> Dictionary:
	return apply(match, decide(match))


static func _tile(match: OfflineMatch, hand: Array) -> String:
	var best := ""
	var best_key: Array = []
	for coordinate in hand:
		var key := _tile_key(match, str(coordinate))
		if best == "" or _before(key, best_key):
			best = str(coordinate)
			best_key = key
	return best


static func _tile_key(match: OfflineMatch, coordinate: String) -> Array:
	var filled := {}
	for cell in match.occupied.keys():
		if bool(match.occupied[cell]):
			filled[str(cell)] = true
	filled[coordinate] = true
	var touched := BoardGraph.component(coordinate, filled)
	var company_ids: Array[String] = []
	for cell in touched:
		var corp_id := str(match.company_of.get(str(cell), ""))
		if corp_id != "" and not company_ids.has(corp_id):
			company_ids.append(corp_id)
	if company_ids.size() >= 2:
		return _merger_key(match, coordinate, company_ids)
	if company_ids.size() == 1:
		return _growth_key(match, coordinate, company_ids[0], touched.size())
	if touched.size() >= 2 and _has_inactive(match):
		return [0, -touched.size(), 0, coordinate]
	return [3, 0, 0, coordinate]


static func _growth_key(match: OfflineMatch, coordinate: String, corp_id: String, cluster: int) -> Array:
	var corp := _corp(match, corp_id)
	var own := _own(match, corp_id)
	var opp := _max_other(match, corp_id)
	var growth := cluster - int(corp.get("size", 0))
	var feeds_end := cluster >= match.end_size and own == 0 and opp > 0
	var feeds_holder := own == 0 and opp >= 3
	if feeds_end or feeds_holder:
		return [5, 0, 0, coordinate]
	if own > 0:
		return [1, -own, -growth, coordinate]
	return [4, growth, 0, coordinate]


static func _merger_key(match: OfflineMatch, coordinate: String, company_ids: Array[String]) -> Array:
	var top := 0
	for corp_id in company_ids:
		top = maxi(top, int(_corp(match, corp_id).get("size", 0)))
	var tied: Array[String] = []
	for corp_id in company_ids:
		if int(_corp(match, corp_id).get("size", 0)) == top:
			tied.append(corp_id)
	if tied.size() != 1:
		return [3, 0, 0, coordinate]
	var survivor := tied[0]
	var held := _own(match, survivor)
	var losers := 0
	for corp_id in company_ids:
		if corp_id != survivor:
			losers += _own(match, corp_id)
	var opponent := _max_other(match, survivor)
	if losers > held and opponent > held:
		return [5, 0, 0, coordinate]
	if held > 0 and held >= losers:
		return [2, -held, 0, coordinate]
	return [3, 0, 0, coordinate]


static func _founder(match: OfflineMatch) -> String:
	var best_id := ""
	var best_sentiment := -99
	var best_index := 999
	for index in match.corporations.size():
		var corp: Dictionary = match.corporations[index]
		if bool(corp["active"]):
			continue
		var sentiment := int(match.sentiment.get(str(corp["sector"]), 0))
		if sentiment > best_sentiment or (sentiment == best_sentiment and index < best_index):
			best_id = str(corp["id"])
			best_sentiment = sentiment
			best_index = index
	return best_id


static func _survivor(match: OfflineMatch) -> String:
	var player := match.active_player()
	var shares: Dictionary = player["shares"]
	var best := str(match.pending_options[0]) if not match.pending_options.is_empty() else ""
	var best_shares := -1
	var best_sentiment := -99
	var best_index := 999
	for index in match.pending_options.size():
		var corp_id := str(match.pending_options[index])
		var held := int(shares.get(corp_id, 0))
		var sentiment := int(match.sentiment.get(str(_corp(match, corp_id).get("sector", "")), 0))
		var better := held > best_shares
		if not better and held == best_shares and sentiment > best_sentiment:
			better = true
		if not better and held == best_shares and sentiment == best_sentiment and index < best_index:
			better = true
		if better:
			best = corp_id
			best_shares = held
			best_sentiment = sentiment
			best_index = index
	return best


static func _buy_target(match: OfflineMatch) -> String:
	var player := match.active_player()
	var shares: Dictionary = player["shares"]
	var cash := int(player["cash"])
	var held_best := ""
	var held_count := 0
	var held_price := 1 << 30
	var held_index := 999
	var cheap_id := ""
	var cheap_price := 1 << 30
	var cheap_index := 999
	for index in match.corporations.size():
		var corp: Dictionary = match.corporations[index]
		if not bool(corp["active"]) or int(corp["bank_shares"]) < 1 or int(corp["share_price"]) <= 0:
			continue
		var corp_id := str(corp["id"])
		var price := int(corp["share_price"])
		if cash - price < CASH_RESERVE:
			continue
		var owned := int(shares.get(corp_id, 0))
		if owned >= SHARE_CAP:
			continue
		if price < cheap_price or (price == cheap_price and index < cheap_index):
			cheap_id = corp_id
			cheap_price = price
			cheap_index = index
		if owned > held_count or (owned == held_count and owned > 0 and (price < held_price or (price == held_price and index < held_index))):
			if owned > 0:
				held_best = corp_id
				held_count = owned
				held_price = price
				held_index = index
	if held_best != "":
		return held_best
	return cheap_id


static func _has_inactive(match: OfflineMatch) -> bool:
	for corp in match.corporations:
		if not bool(corp["active"]):
			return true
	return false


static func _corp(match: OfflineMatch, corp_id: String) -> Dictionary:
	for corp in match.corporations:
		if str(corp["id"]) == corp_id:
			return corp
	return {}


static func _own(match: OfflineMatch, corp_id: String) -> int:
	var shares: Dictionary = match.active_player()["shares"]
	return int(shares.get(corp_id, 0))


static func _max_other(match: OfflineMatch, corp_id: String) -> int:
	var self_id := str(match.active_player()["id"])
	var best := 0
	for player in match.players:
		if str(player["id"]) == self_id:
			continue
		var shares: Dictionary = player["shares"]
		best = maxi(best, int(shares.get(corp_id, 0)))
	return best


static func _before(left: Array, right: Array) -> bool:
	for index in left.size():
		var a = left[index]
		var b = right[index]
		if str(a) == str(b):
			continue
		if a is String or b is String:
			return str(a) < str(b)
		return int(a) < int(b)
	return false
