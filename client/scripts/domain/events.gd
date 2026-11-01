extends RefCounted
class_name SectorEvents

## Apply sector deltas and clamp each sector on its own. The match shuffles the deck.


static func apply_sector_deltas(sentiment: Dictionary, deltas: Dictionary) -> Dictionary:
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	if rules == null:
		return {}
	var low := int(rules["sentiment_min"])
	var high := int(rules["sentiment_max"])
	var out := {}
	for sector in rules["sectors"]:
		var key := str(sector)
		if not sentiment.has(key):
			return {}
		out[key] = int(sentiment[key])
	for sector in deltas.keys():
		var key := str(sector)
		if not out.has(key):
			return {}
		var updated := int(out[key]) + int(deltas[sector])
		if updated > high:
			updated = high
		elif updated < low:
			updated = low
		out[key] = updated
	return out
