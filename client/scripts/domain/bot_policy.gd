extends RefCounted
class_name BotPolicy

## Deterministic local computer. `set_difficulty` picks Easy, Normal, or Hard.
## Normal is the shipped policy: five tiles, three-quarter continuations, and
## the contest-aware market. Easy looks one tile ahead and only buys a first
## cheap share. Hard uses that same five-tile search and may buy up to size 18
## when that purchase ties or takes the lead. A heavier continuation made the
## chain place the immediate growth, so Hard does not change the discount.
## A tile that ends the company for an opponent while we hold nothing is not
## expanded. A tile that touches neither the board nor another tile still in
## hand scores only its immediate value. A branch is cut when its immediate
## value plus OPTIMISTIC_TILE still cannot beat the best continuation already
## scored. The search stops at MAX_PLACEMENT_NODES. After the first tile, one
## ply over at most FRONTIER_CAP empty neighbors estimates an opponent's best
## reply. Only the increase over the reply already available is kept, and half
## of that increase is subtracted. Hidden hands are not read. Market buys and
## sells shares and BYTE when that score is positive, at most two actions, and
## never spends the cash floor. On Normal and Hard, BYTE under the $500
## reference is bought and BYTE over that reference is sold. A share past three
## is bought only to tie or take the lead. A one-share holding is sold when
## someone else already leads and the price is rich, and it is kept when it is
## the bonus. Ties break by lowest coordinate, fixture order, or the earlier
## survivor. The match generator is not advanced here.


const CASH_FLOOR := 500
const BUY_MAX_SIZE := 14
const BUY_MAX_SENTIMENT := 1
const SELL_MIN_SIZE := 16
const SELL_MIN_SENTIMENT := 1
const SELL_MIN_OWNED := 2
const BYTE_REFERENCE := 500
const BYTE_BUY_MAX := 490
const BYTE_SELL_MIN := 510
## Hard may cross the Normal size cap only to tie or take the lead.
const HARD_BUY_MAX_SIZE := 18
const END_FEED_PENALTY := -100000
## Lobby name. Unknown names become Normal. Tests must restore Normal.
static var difficulty := "normal"
## "soft", "standard", or "sharp". Set only through `set_difficulty`.
static var market_style := "standard"
## Shipped Normal and Hard depth. Easy uses one. Tests may lower it and must restore five.
static var placement_plies := 5
const MAX_PLACEMENT_NODES := 500
const FRONTIER_CAP := 24
## Shipped weights. Tests may lower them and must restore three quarters and half the new reply.
static var continuation_num := 3
static var continuation_den := 4
static var threat_div := 2
static var threat_uses_marginal := true
## Upper bound on one later tile's contribution after the three-quarter discount.
## A sibling is skipped when even this cannot beat the best continuation.
const OPTIMISTIC_TILE := 20000

static var last_placement_nodes := 0


static func set_difficulty(name: String) -> void:
	var choice := name.strip_edges().to_lower()
	if choice != "easy" and choice != "hard":
		choice = "normal"
	difficulty = choice
	threat_div = 2
	threat_uses_marginal = true
	if choice == "easy":
		placement_plies = 1
		continuation_num = 3
		continuation_den = 4
		market_style = "soft"
	elif choice == "hard":
		placement_plies = 5
		continuation_num = 3
		continuation_den = 4
		market_style = "sharp"
	else:
		placement_plies = 5
		continuation_num = 3
		continuation_den = 4
		market_style = "standard"


static func difficulty_label() -> String:
	if difficulty == "easy":
		return "Easy"
	if difficulty == "hard":
		return "Hard"
	return "Normal"

static var _catalog_cache: PackedStringArray = PackedStringArray()
static var _neighbor_cache: Dictionary = {}
static var _price_cache: Dictionary = {}


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
	if cash - price < CASH_FLOOR:
		return 0
	if market_style == "soft":
		if owned != 0 or size > 4 or sentiment > 0 or price > 200:
			return 0
		return (5 - size) * 20 - Pricing.div_nonneg(price, 20) + 10
	var best_other := _best_opponent(match, str(corp["id"]))
	var size_cap := BUY_MAX_SIZE
	if market_style == "sharp" and owned >= 3 and best_other >= owned:
		size_cap = HARD_BUY_MAX_SIZE
	if size > size_cap or sentiment > BUY_MAX_SENTIMENT:
		return 0
	if owned >= 3 and best_other < owned:
		return 0
	if owned >= 2 and size >= 8 and owned - best_other >= 2:
		return 0
	var stake := 0
	if owned == 1:
		stake = 40
	elif owned >= 3 and best_other >= owned:
		stake = 120
	return (15 - size) * 30 + (1 - sentiment) * 40 - Pricing.div_nonneg(price, 20) + stake


static func _sell_share_score(match: OfflineMatch, corp: Dictionary, owned: int, cash: int) -> int:
	if not bool(corp["active"]) or int(corp["share_price"]) <= 0 or owned < 1:
		return 0
	var size := int(corp["size"])
	var sentiment := int(match.sentiment.get(str(corp["sector"]), 0))
	var price := int(corp["share_price"])
	if market_style == "soft":
		return 500 if cash < CASH_FLOOR else 0
	var best_other := _best_opponent(match, str(corp["id"]))
	var behind := best_other > owned
	var safe_lead := owned - 1 > best_other
	var profit := 0
	if safe_lead or behind:
		if owned >= SELL_MIN_OWNED and size >= SELL_MIN_SIZE and sentiment >= SELL_MIN_SENTIMENT:
			profit = (size - 14) * 50 + sentiment * 80 + Pricing.div_nonneg(price, 10)
		elif owned >= 4 and size >= 10 and sentiment >= 0 and owned - best_other >= 2:
			profit = (size - 8) * 40 + Pricing.div_nonneg(price, 10)
		elif owned >= SELL_MIN_OWNED and size >= 6 and sentiment >= 2:
			profit = sentiment * 70 + Pricing.div_nonneg(price, 10)
		elif owned == 1 and behind and ((size >= 6 and sentiment >= 2) or (size >= SELL_MIN_SIZE and sentiment >= SELL_MIN_SENTIMENT)):
			profit = sentiment * 70 + Pricing.div_nonneg(price, 10) + 40
	var liquidity := 500 if cash < CASH_FLOOR else 0
	return maxi(profit, liquidity)


static func _buy_byte_score(match: OfflineMatch, cash: int) -> int:
	if market_style == "soft":
		return 0
	var price := int(match.byte_price)
	if price > BYTE_BUY_MAX or match.byte_exchange < 1 or cash - price < CASH_FLOOR:
		return 0
	return (BYTE_REFERENCE - price) + 30


static func _sell_byte_score(match: OfflineMatch, player: Dictionary, cash: int) -> int:
	if int(player["byte_count"]) < 1:
		return 0
	if market_style == "soft":
		return 500 if cash < CASH_FLOOR else 0
	var price := int(match.byte_price)
	var profit := 0
	if price >= BYTE_SELL_MIN:
		profit = (price - BYTE_REFERENCE) + 30
	var liquidity := 500 if cash < CASH_FLOOR else 0
	return maxi(profit, liquidity)


static func _tile(match: OfflineMatch, hand: Array) -> String:
	var filled := _filled(match)
	var company := _company_map(match)
	var ordered := _sorted_hand(hand)
	var budget := {"n": 0}
	var best := ""
	var best_score := 0
	var chosen := false
	var base_threat := _opponent_threat(match, filled, company) if threat_uses_marginal else 0
	for coordinate in ordered:
		var text := str(coordinate)
		var rest := _without(ordered, text)
		var score := _line(match, text, rest, filled, company, {}, placement_plies, budget)
		var projected := _project(match, text, filled, company, {})
		var threat := _opponent_threat(match, projected["filled"], projected["company"])
		var penalty := threat - base_threat if threat_uses_marginal else threat
		if penalty > 0:
			score -= Pricing.div_nonneg(penalty, threat_div)
		if not chosen or score > best_score or (score == best_score and text < best):
			chosen = true
			best = text
			best_score = score
	last_placement_nodes = int(budget["n"])
	return best


static func _line(match: OfflineMatch, coordinate: String, others: Array, filled: Dictionary, company: Dictionary, extra: Dictionary, plies: int, budget: Dictionary) -> int:
	if int(budget["n"]) >= MAX_PLACEMENT_NODES:
		return 0
	budget["n"] = int(budget["n"]) + 1
	var immediate := _immediate(match, coordinate, filled, company, extra)
	return _extend_after(match, immediate, coordinate, others, filled, company, extra, plies, budget)


static func _extend_after(match: OfflineMatch, immediate: int, coordinate: String, others: Array, filled: Dictionary, company: Dictionary, extra: Dictionary, plies: int, budget: Dictionary) -> int:
	if plies <= 1 or immediate <= END_FEED_PENALTY:
		return immediate
	var projected := _project(match, coordinate, filled, company, extra)
	var next_filled: Dictionary = projected["filled"]
	var next_company: Dictionary = projected["company"]
	var next_extra: Dictionary = projected["extra"]
	var ranked: Array = []
	for follow in others:
		if int(budget["n"]) >= MAX_PLACEMENT_NODES:
			break
		var next := str(follow)
		if bool(next_filled.get(next, false)):
			continue
		budget["n"] = int(budget["n"]) + 1
		var child_imm := _immediate(match, next, next_filled, next_company, next_extra)
		if child_imm <= END_FEED_PENALTY:
			continue
		if child_imm == 0 and not _touches(next, next_filled, others):
			continue
		ranked.append({"c": next, "imm": child_imm})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["imm"]) != int(b["imm"]):
			return int(a["imm"]) > int(b["imm"])
		return str(a["c"]) < str(b["c"])
	)
	var best_cont := 0
	for entry in ranked:
		var next := str(entry["c"])
		var child_imm := int(entry["imm"])
		var ceiling := child_imm
		if plies > 2:
			ceiling += OPTIMISTIC_TILE
		if best_cont > 0 and ceiling <= best_cont:
			continue
		var child := _extend_after(match, child_imm, next, _without(others, next), next_filled, next_company, next_extra, plies - 1, budget)
		if child > best_cont:
			best_cont = child
	if best_cont > 0 and continuation_den > 0:
		immediate += Pricing.div_nonneg(best_cont * continuation_num, continuation_den)
	return immediate


static func _touches(coordinate: String, filled: Dictionary, others: Array) -> bool:
	for neighbor in _neighbors(coordinate):
		var next := str(neighbor)
		if bool(filled.get(next, false)):
			return true
		if others.has(next):
			return true
	return false


static func _opponent_threat(match: OfflineMatch, filled: Dictionary, company: Dictionary) -> int:
	var actor := str(match.active_player()["id"])
	var frontier := _frontier(filled)
	var best := 0
	var seen := 0
	for coordinate in frontier:
		if seen >= FRONTIER_CAP:
			break
		seen += 1
		var cell := str(coordinate)
		if bool(filled.get(cell, false)):
			continue
		var touched := _component(cell, filled, cell)
		for player in match.players:
			var player_id := str(player["id"])
			if player_id == actor:
				continue
			var value := _score_component(match, touched, company, {}, player_id)
			if value > best:
				best = value
	return best


static func _frontier(filled: Dictionary) -> Array:
	var found: Array = []
	var seen := {}
	for cell in _catalog():
		if not bool(filled.get(cell, false)):
			continue
		for neighbor in _neighbors(cell):
			var next := str(neighbor)
			if bool(filled.get(next, false)) or seen.has(next):
				continue
			seen[next] = true
			found.append(next)
	found.sort()
	return found


static func _sorted_hand(hand: Array) -> Array:
	var ordered: Array = []
	for coordinate in hand:
		ordered.append(str(coordinate))
	ordered.sort()
	return ordered


static func _without(hand: Array, skip: String) -> Array:
	var rest: Array = []
	for coordinate in hand:
		var text := str(coordinate)
		if text != skip:
			rest.append(text)
	return rest


static func _immediate(match: OfflineMatch, coordinate: String, filled: Dictionary, company: Dictionary, extra: Dictionary, actor: String = "") -> int:
	if bool(filled.get(coordinate, false)):
		return END_FEED_PENALTY
	var touched := _component(coordinate, filled, coordinate)
	return _score_component(match, touched, company, extra, actor)


static func _score_component(match: OfflineMatch, touched: PackedStringArray, company: Dictionary, extra: Dictionary, actor: String = "") -> int:
	var company_ids := _ids_in(touched, company)
	if company_ids.size() >= 2:
		return _merger_tile(match, company_ids, touched.size(), company, extra, actor)
	if company_ids.size() == 1:
		return _growth_value(match, company_ids[0], touched.size(), company, extra, actor)
	if touched.size() >= 2 and not _inactive_ids(match, company).is_empty():
		return _found_value(match, touched.size(), company)
	return 0


static func _project(match: OfflineMatch, coordinate: String, filled: Dictionary, company: Dictionary, extra: Dictionary) -> Dictionary:
	var board := filled.duplicate()
	board[coordinate] = true
	var owners := company.duplicate()
	var granted := extra.duplicate()
	var touched := _component(coordinate, board)
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


static func _growth_value(match: OfflineMatch, corp_id: String, new_size: int, company: Dictionary, extra: Dictionary, actor: String = "") -> int:
	var old_size := int(_sizes(company).get(corp_id, 0))
	var delta := _quoted(match, corp_id, new_size) - _quoted(match, corp_id, old_size)
	var ours := _held(match, corp_id, extra, actor)
	var others := _others(match, corp_id, actor)
	if new_size >= match.end_size and ours == 0 and others > 0:
		return END_FEED_PENALTY
	return ours * delta - others * delta


static func _merger_tile(match: OfflineMatch, company_ids: Array, new_size: int, company: Dictionary, extra: Dictionary, actor: String = "") -> int:
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
		var value := _merger_value(match, corp_id, company_ids, new_size, sizes, extra, actor)
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


static func _merger_value(match: OfflineMatch, survivor: String, company_ids: Array, new_size: int, sizes: Dictionary, extra: Dictionary, actor: String = "") -> int:
	var old_size := int(sizes.get(survivor, 0))
	var delta := _quoted(match, survivor, new_size) - _quoted(match, survivor, old_size)
	var ours := _held(match, survivor, extra, actor)
	var value := ours * delta - _others(match, survivor, actor) * delta
	var self_id := _actor_id(match, actor)
	for corp_id in company_ids:
		var loser := str(corp_id)
		if loser == survivor:
			continue
		var holdings := _holdings(match, loser, extra, actor)
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
	var key := "%d:%d" % [size, sentiment]
	if _price_cache.has(key):
		return int(_price_cache[key])
	var price := Pricing.share_price(size, sentiment)
	if price < 0:
		price = 0
	_price_cache[key] = price
	return price


static func _holdings(match: OfflineMatch, corp_id: String, extra: Dictionary, actor: String = "") -> Dictionary:
	var self_id := _actor_id(match, actor)
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


static func _actor_id(match: OfflineMatch, actor: String) -> String:
	if actor != "":
		return actor
	return str(match.active_player()["id"])


static func _held(match: OfflineMatch, corp_id: String, extra: Dictionary, actor: String = "") -> int:
	var who := _actor_id(match, actor)
	var count := 0
	for player in match.players:
		if str(player["id"]) != who:
			continue
		var shares: Dictionary = player["shares"]
		count = int(shares.get(corp_id, 0))
		break
	return count + int(extra.get(corp_id, 0))


static func _best_opponent(match: OfflineMatch, corp_id: String) -> int:
	var who := str(match.active_player()["id"])
	var best := 0
	for player in match.players:
		if str(player["id"]) == who:
			continue
		var shares: Dictionary = player["shares"]
		var count := int(shares.get(corp_id, 0))
		if count > best:
			best = count
	return best


static func _others(match: OfflineMatch, corp_id: String, actor: String = "") -> int:
	var who := _actor_id(match, actor)
	var total := 0
	for player in match.players:
		if str(player["id"]) == who:
			continue
		var shares: Dictionary = player["shares"]
		total += int(shares.get(corp_id, 0))
	return total


static func _catalog() -> PackedStringArray:
	if _catalog_cache.is_empty():
		_catalog_cache = Coordinates.catalog()
	return _catalog_cache


static func _neighbors(coordinate: String) -> PackedStringArray:
	if _neighbor_cache.has(coordinate):
		return _neighbor_cache[coordinate]
	var found := BoardGraph.neighbors(coordinate)
	_neighbor_cache[coordinate] = found
	return found


static func _component(origin: String, filled: Dictionary, extra: String = "") -> PackedStringArray:
	var ordered := PackedStringArray()
	if origin != extra and not bool(filled.get(origin, false)):
		return ordered
	var seen := {}
	var stack: Array[String] = [origin]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		if seen.has(current):
			continue
		if current != extra and not bool(filled.get(current, false)):
			continue
		seen[current] = true
		ordered.append(current)
		for neighbor in _neighbors(current):
			stack.append(str(neighbor))
	return ordered
