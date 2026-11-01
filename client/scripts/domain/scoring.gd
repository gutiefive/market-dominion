extends RefCounted
class_name Ranking

## Winner order from already-totaled net worth. Empty result means the input was rejected.


static func rank_players(players: Array) -> PackedStringArray:
	var seen := {}
	for player in players:
		var index := int(player["turn_order_index"])
		if seen.has(index):
			return PackedStringArray()
		seen[index] = true
	if players.is_empty():
		return PackedStringArray()
	var copy: Array = players.duplicate(true)
	copy.sort_custom(_before)
	var ids := PackedStringArray()
	for player in copy:
		ids.append(str(player["id"]))
	return ids


static func _before(a: Dictionary, b: Dictionary) -> bool:
	var net_a := int(a["net_worth"])
	var net_b := int(b["net_worth"])
	if net_a != net_b:
		return net_a > net_b
	var cash_a := int(a["cash"])
	var cash_b := int(b["cash"])
	if cash_a != cash_b:
		return cash_a > cash_b
	var shares_a := int(a["active_shares"])
	var shares_b := int(b["active_shares"])
	if shares_a != shares_b:
		return shares_a > shares_b
	return int(a["turn_order_index"]) < int(b["turn_order_index"])
