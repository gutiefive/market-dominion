extends RefCounted
class_name DominionPricing

## Isolated experimental arithmetic. Classic never calls this calculator.
## Strict integer inputs; invalid inputs return -1, following the Pricing convention.
static var _parameters: Dictionary = {}


static func share_price(company_id: Variant, size: Variant, sentiment: Variant) -> int:
	if not company_id is String or typeof(size) != TYPE_INT or typeof(sentiment) != TYPE_INT:
		return -1
	if _parameters.is_empty():
		var source: Variant = SharedFiles.read_json("fixtures/dominion_v1/pricing.json")
		if not source is Dictionary:
			return -1
		_parameters = source
	var profile := {}
	for company in _parameters["companies"]:
		if str(company["id"]) == company_id:
			profile = company
			break
	if profile.is_empty():
		return -1
	if size < int(_parameters["size_min"]) or size > int(_parameters["size_max"]):
		return -1
	if sentiment < int(_parameters["sentiment_min"]) or sentiment > int(_parameters["sentiment_max"]):
		return -1
	if size == 0:
		return 0
	var base: int = int(_parameters["base_offset"]) + int(profile["growth"]) * size
	var multiplier: int = 100 + int(profile["sensitivity"]) * sentiment
	return Pricing.round_ratio_half_up(base * multiplier, 100, int(_parameters["money_step"]))
