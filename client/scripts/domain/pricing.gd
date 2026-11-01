extends RefCounted
class_name Pricing

## Integer prices. `/` in GDScript is float division, so this file uses a bit loop.
## Illegal inputs return -1. Size 0 returns 0. See assumption A13.


static func div_nonneg(numerator: int, denominator: int) -> int:
	if numerator < 0 or denominator <= 0:
		return -1
	var quotient := 0
	var remainder := 0
	for shift in range(30, -1, -1):
		remainder = (remainder << 1) | ((numerator >> shift) & 1)
		if remainder >= denominator:
			remainder -= denominator
			quotient |= 1 << shift
	return quotient


static func round_ratio_half_up(numerator: int, divisor: int, step: int) -> int:
	if numerator < 0 or divisor <= 0 or step <= 0:
		return -1
	var unit := divisor * step
	var half := div_nonneg(unit, 2)
	var steps := div_nonneg(numerator + half, unit)
	return steps * step


static func share_price(size: int, sentiment: int) -> int:
	if size < 0:
		return -1
	if size == 0:
		return 0
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	if rules == null:
		return -1
	var low := int(rules["sentiment_min"])
	var high := int(rules["sentiment_max"])
	if sentiment < low or sentiment > high:
		return -1
	var base := int(rules["share_price_base_offset"]) + int(rules["share_price_per_tile"]) * size
	var multiplier := 100 + 10 * sentiment
	return round_ratio_half_up(base * multiplier, 100, int(rules["money_step"]))


static func byte_price_after_delta(prior: int, delta_percent: int) -> int:
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	if rules == null:
		return -1
	var step := int(rules["money_step"])
	var low := int(rules["byte_price_min"])
	var high := int(rules["byte_price_max"])
	if prior < low or prior > high or step <= 0:
		return -1
	if div_nonneg(prior, step) * step != prior:
		return -1
	var factor := 100 + delta_percent
	if factor <= 0:
		return -1
	var raw := round_ratio_half_up(prior * factor, 100, step)
	if raw < low:
		return low
	if raw > high:
		return high
	return raw
