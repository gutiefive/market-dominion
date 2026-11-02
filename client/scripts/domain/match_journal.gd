extends RefCounted
class_name MatchJournal

## In-memory facts only. No hands, seed, tokens, networking, or inferred prices.
const MAX_POINTS := 128
var _quotes: Dictionary = {}
var _stats: Dictionary = {}
var _last_sequence := -1
var _last_round := 0


func observe(round_number: int, sequence: int, quotes: Dictionary, reason: String) -> void:
	if sequence < _last_sequence:
		return
	_last_sequence = sequence
	_last_round = round_number
	for asset in quotes:
		var values: Array = _quotes.get(asset, [])
		var price: Variant = quotes[asset]
		if not values.is_empty() and values.back()["price"] == price:
			var was_gap := str(values.back()["reason"]) == "Connection gap"
			if price != null or was_gap == (reason == "Connection gap"):
				continue
		values.append({"round": round_number, "sequence": sequence, "price": price, "reason": reason})
		if values.size() > MAX_POINTS:
			values.pop_front()
		_quotes[asset] = values


func gap() -> void:
	var missing := {}
	for asset in _quotes:
		missing[asset] = null
	observe(_last_round, _last_sequence, missing, "Connection gap")


func points(asset: String, limit: int = 8) -> Array:
	var values: Array = _quotes.get(asset, [])
	return values.slice(maxi(0, values.size() - limit)).duplicate(true)


func add(player_id: String, field: String, amount: int = 1) -> void:
	var row: Dictionary = _stats.get(player_id, {})
	row[field] = int(row.get(field, 0)) + amount
	_stats[player_id] = row


func trade(player_id: String, kind: String, price: int) -> void:
	add(player_id, kind)
	add(player_id, "spent" if kind.begins_with("buy") else "proceeds", price)


func stats(player_id: String) -> Dictionary:
	return (_stats.get(player_id, {}) as Dictionary).duplicate(true)


func analysis(player_id: String, starting_cash: int, closing: Dictionary) -> Dictionary:
	var facts := stats(player_id)
	var expected_cash := starting_cash - int(facts.get("spent", 0)) + int(facts.get("proceeds", 0)) + int(facts.get("merger_bonus", 0)) + int(facts.get("merger_buyout", 0))
	facts["cash_reconciled"] = expected_cash == int(closing["cash"])
	facts["net_change"] = int(closing["net_worth"]) - starting_cash
	facts["buys"] = int(facts.get("buy_share", 0)) + int(facts.get("buy_byte", 0))
	facts["sells"] = int(facts.get("sell_share", 0)) + int(facts.get("sell_byte", 0))
	return facts
