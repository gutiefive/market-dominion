extends RefCounted
class_name MatchRng

## Same 32-bit xorshift as server/app/domain/rng.py. Assumption A16.

var state: int


func _init(seed_value: int) -> void:
	if seed_value < 0:
		state = -1
		return
	state = seed_value & 0xFFFFFFFF
	if state == 0:
		state = 0x6D2B79F5


func next_u32() -> int:
	var x := state
	x = (x ^ ((x << 13) & 0xFFFFFFFF)) & 0xFFFFFFFF
	x = (x ^ (x >> 17)) & 0xFFFFFFFF
	x = (x ^ ((x << 5) & 0xFFFFFFFF)) & 0xFFFFFFFF
	state = x
	return x


func below(exclusive_end: int) -> int:
	return next_u32() % exclusive_end


static func shuffle(items: Array, rng: MatchRng) -> Array:
	var out: Array = items.duplicate(true)
	var index := out.size() - 1
	while index > 0:
		var swap := rng.below(index + 1)
		var tmp = out[index]
		out[index] = out[swap]
		out[swap] = tmp
		index -= 1
	return out
