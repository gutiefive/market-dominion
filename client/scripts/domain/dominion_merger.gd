extends RefCounted
class_name DominionMerger

## Standalone public financial ledger; not connected to the Classic match or rooms.
## Bad constructors/restores return null. Bad decisions return {ok:false} unchanged.
var _state: Dictionary


static func _text(value: Variant) -> bool:
	return value is String and not value.is_empty()


static func _integer(value: Variant, maximum: int = -1) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and (maximum < 0 or value <= maximum)


static func begin(resolution_id: Variant, survivor_id: Variant, placer_id: Variant, losing_ids: Variant, companies: Variant, players: Variant) -> DominionMerger:
	if not _text(resolution_id) or not _text(survivor_id) or not _text(placer_id): return null
	var order: Array = []
	for company in SharedFiles.read_json("fixtures/corporations.json")["corporations"]:
		order.append(str(company["id"]))
	if not companies is Array or companies.size() != order.size(): return null
	var roster := {}
	for company in companies:
		if not company is Dictionary or not _text(company.get("id")): return null
		var cid: String = company["id"]
		if not order.has(cid) or roster.has(cid): return null
		if not _integer(company.get("bank_shares"), 20) or not _integer(company.get("share_price"), DominionPricing.share_price(cid, 81, 2)): return null
		if int(company["share_price"]) % 10 != 0: return null
		roster[cid] = {"id": cid, "bank_shares": company["bank_shares"], "share_price": company["share_price"]}
	if not roster.has(survivor_id) or int(roster[survivor_id]["share_price"]) <= 0: return null
	if not losing_ids is Array or losing_ids.is_empty(): return null
	var seen := {}
	for cid in losing_ids:
		if not _text(cid) or not roster.has(cid) or cid == survivor_id or seen.has(cid): return null
		if int(roster[cid]["share_price"]) <= 0: return null
		seen[cid] = true
	var losers: Array = []
	for cid in order:
		if seen.has(cid): losers.append(cid)
	if not players is Array or players.size() < 2 or players.size() > 4: return null
	var seats := {}
	for player in players:
		if not player is Dictionary or not _text(player.get("id")): return null
		var pid: String = player["id"]
		if seats.has(pid) or not _integer(player.get("cash"), 2147483647) or not player.get("shares") is Dictionary: return null
		if player["shares"].size() != order.size(): return null
		var book := {}
		for cid in order:
			if not _integer(player["shares"].get(cid), 20): return null
			book[cid] = player["shares"][cid]
		seats[pid] = {"id": pid, "cash": player["cash"], "shares": book}
	if not seats.has(placer_id): return null
	var ids: Array = seats.keys()
	ids.sort()
	for cid in order:
		var total: int = roster[cid]["bank_shares"]
		for pid in ids: total += int(seats[pid]["shares"][cid])
		if total != 20: return null
	var opening := {"resolution_id": resolution_id, "survivor_id": survivor_id, "placer_id": placer_id, "losing_ids": losers, "companies": [], "players": []}
	for cid in order: opening["companies"].append(roster[cid].duplicate(true))
	for pid in ids: opening["players"].append(seats[pid].duplicate(true))
	var state := {"format_version": 1, "ruleset_id": "dominion_v1", "opening": opening, "banks": {}, "cash": {}, "shares": {}, "snapshots": {}, "queue": [], "cursor": 0, "version": 0, "bonuses_paid": true, "decisions": []}
	for cid in order: state["banks"][cid] = roster[cid]["bank_shares"]
	for pid in ids:
		state["cash"][pid] = seats[pid]["cash"]
		state["shares"][pid] = seats[pid]["shares"].duplicate(true)
	for cid in losers:
		var holdings := {}
		for pid in ids: holdings[pid] = seats[pid]["shares"][cid]
		var payouts := Mergers.bonus_payouts(int(roster[cid]["share_price"]), holdings)
		state["snapshots"][cid] = {"price": roster[cid]["share_price"], "holdings": holdings, "bonuses": payouts}
		for pid in payouts: state["cash"][pid] += int(payouts[pid])
		for pid in ids:
			if int(holdings[pid]) > 0:
				state["queue"].append({"player_id": pid, "loser_id": cid, "shares": holdings[pid]})
	var instance := DominionMerger.new()
	instance._state = state
	_advance_flags(state)
	return instance


func export_state() -> Dictionary:
	return _state.duplicate(true)


func current_choice() -> Dictionary:
	if bool(_state["complete"]): return {}
	var choice: Dictionary = _state["queue"][_state["cursor"]].duplicate(true)
	choice["max_pairs"] = mini(Pricing.div_nonneg(int(choice["shares"]), 2), int(_state["remaining_survivor_bank"]))
	return choice


func choose(resolution_id: Variant, actor_id: Variant, loser_id: Variant, pairs: Variant, action_id: Variant, expected_version: Variant) -> Dictionary:
	return _commit(resolution_id, actor_id, loser_id, pairs, action_id, expected_version, false)


func timeout(resolution_id: Variant, actor_id: Variant, loser_id: Variant, action_id: Variant, expected_version: Variant) -> Dictionary:
	return _commit(resolution_id, actor_id, loser_id, 0, action_id, expected_version, true)


func _commit(resolution_id: Variant, actor_id: Variant, loser_id: Variant, pairs: Variant, action_id: Variant, expected_version: Variant, timed_out: bool) -> Dictionary:
	if not _text(resolution_id) or not _text(actor_id) or not _text(loser_id) or not _text(action_id) or not _integer(pairs) or not _integer(expected_version):
		return {"ok": false, "error": "Invalid decision fields"}
	var request := {"resolution_id": resolution_id, "actor_id": actor_id, "loser_id": loser_id, "pairs": pairs, "action_id": action_id, "expected_version": expected_version, "timed_out": timed_out}
	for decision in _state["decisions"]:
		if decision["request"]["action_id"] == action_id:
			var original_intent: Dictionary = decision["request"].duplicate(true)
			var retry_intent := request.duplicate(true)
			original_intent.erase("expected_version")
			retry_intent.erase("expected_version")
			if original_intent != retry_intent: return {"ok": false, "error": "Action id reused"}
			return {"ok": true, "duplicate": true, "receipt": decision["receipt"].duplicate(true)}
	if resolution_id != _state["opening"]["resolution_id"] or expected_version != _state["version"]:
		return {"ok": false, "error": "Wrong resolution or stale version"}
	var choice := current_choice()
	if choice.is_empty(): return {"ok": false, "error": "Resolution is complete"}
	if actor_id != choice["player_id"] or loser_id != choice["loser_id"]:
		return {"ok": false, "error": "Not the required shareholder/company"}
	if pairs > choice["max_pairs"]: return {"ok": false, "error": "Insufficient holdings or survivor inventory"}
	var candidate := _state.duplicate(true)
	var survivor: String = candidate["opening"]["survivor_id"]
	var count: int = choice["shares"]
	var proceeds: int = (count - 2 * int(pairs)) * int(candidate["snapshots"][loser_id]["price"])
	candidate["shares"][actor_id][loser_id] = 0
	candidate["shares"][actor_id][survivor] += int(pairs)
	candidate["banks"][loser_id] += count
	candidate["banks"][survivor] -= int(pairs)
	candidate["cash"][actor_id] += proceeds
	candidate["cursor"] += 1
	candidate["version"] += 1
	var receipt := {"action_id": action_id, "version": candidate["version"], "player_id": actor_id, "loser_id": loser_id, "pairs": pairs, "loser_shares_returned": count, "survivor_shares_received": pairs, "cash_proceeds": proceeds, "timed_out": timed_out}
	candidate["decisions"].append({"request": request, "receipt": receipt})
	_advance_flags(candidate)
	for cid in candidate["banks"]:
		var total: int = candidate["banks"][cid]
		if total < 0: return {"ok": false, "error": "Share supply mismatch"}
		for pid in candidate["shares"]: total += int(candidate["shares"][pid][cid])
		if total != 20: return {"ok": false, "error": "Share supply mismatch"}
	_state = candidate
	return {"ok": true, "duplicate": false, "receipt": receipt.duplicate(true)}


static func _advance_flags(state: Dictionary) -> void:
	state["complete"] = int(state["cursor"]) == state["queue"].size()
	state["required_actor_id"] = null if state["complete"] else state["queue"][state["cursor"]]["player_id"]
	state["resume_player_id"] = state["opening"]["placer_id"] if state["complete"] else null
	state["remaining_survivor_bank"] = state["banks"][state["opening"]["survivor_id"]]


static func from_export(data: Variant) -> DominionMerger:
	if not data is Dictionary: return null
	var saved: Dictionary = Rulesets._integer_numbers(data.duplicate(true))
	var opening: Variant = saved.get("opening")
	if not opening is Dictionary or not saved.get("decisions") is Array: return null
	var rebuilt := begin(opening.get("resolution_id"), opening.get("survivor_id"), opening.get("placer_id"), opening.get("losing_ids"), opening.get("companies"), opening.get("players"))
	if rebuilt == null: return null
	for decision in saved["decisions"]:
		if not decision is Dictionary or not decision.get("request") is Dictionary: return null
		var request: Dictionary = decision["request"]
		var result: Dictionary
		if request.get("timed_out") is bool and request["timed_out"]:
			if request.get("pairs") != 0: return null
			result = rebuilt.timeout(request.get("resolution_id"), request.get("actor_id"), request.get("loser_id"), request.get("action_id"), request.get("expected_version"))
		elif request.get("timed_out") is bool and not request["timed_out"]:
			result = rebuilt.choose(request.get("resolution_id"), request.get("actor_id"), request.get("loser_id"), request.get("pairs"), request.get("action_id"), request.get("expected_version"))
		else: return null
		if not bool(result["ok"]): return null
	if JSON.stringify(saved, "", true) != JSON.stringify(rebuilt.export_state(), "", true): return null
	return rebuilt
