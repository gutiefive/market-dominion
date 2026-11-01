extends RefCounted
class_name Mergers

## Merger bonuses in integer dollars. Remainder $1 follows ascending player id.
## See server/app/domain/mergers.py. The two functions stay in step.


static func bonus_payouts(price: int, holdings: Dictionary) -> Dictionary:
	if price <= 0:
		return {}
	var positive := {}
	for player_id in holdings.keys():
		var count := int(holdings[player_id])
		if count > 0:
			positive[str(player_id)] = count
	if positive.is_empty():
		return {}
	var top := 0
	for count in positive.values():
		if int(count) > top:
			top = int(count)
	var leaders: Array[String] = []
	for player_id in positive.keys():
		if int(positive[player_id]) == top:
			leaders.append(str(player_id))
	if positive.size() == 1:
		return {leaders[0]: 3 * price}
	if leaders.size() >= 2:
		return _split(3 * price, leaders)
	var second := 0
	for count in positive.values():
		if int(count) < top and int(count) > second:
			second = int(count)
	var runners: Array[String] = []
	for player_id in positive.keys():
		if int(positive[player_id]) == second:
			runners.append(str(player_id))
	var payouts := _split(2 * price, leaders)
	var minority := _split(price, runners)
	for player_id in minority.keys():
		payouts[str(player_id)] = int(payouts.get(str(player_id), 0)) + int(minority[player_id])
	return payouts


static func _split(amount: int, player_ids: Array) -> Dictionary:
	var ordered: Array[String] = []
	for player_id in player_ids:
		var key := str(player_id)
		if not ordered.has(key):
			ordered.append(key)
	ordered.sort()
	var payouts := {}
	if ordered.is_empty():
		return payouts
	var base := Pricing.div_nonneg(amount, ordered.size())
	var remainder := amount - base * ordered.size()
	for index in ordered.size():
		payouts[ordered[index]] = base + (1 if index < remainder else 0)
	return payouts
