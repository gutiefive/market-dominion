extends RefCounted
class_name Tiles

## Same error strings as the Python checker: count, duplicate, missing, unknown.


static func conservation_errors(bag, hands, board) -> PackedStringArray:
	var catalog := {}
	for coordinate in Coordinates.catalog():
		catalog[coordinate] = true
	var seen: Array[String] = []
	for item in bag:
		seen.append(str(item))
	for hand in hands:
		for item in hand:
			seen.append(str(item))
	for item in board:
		seen.append(str(item))
	var errors := PackedStringArray()
	if seen.size() != catalog.size():
		errors.append("count:%d" % seen.size())
	var counts := {}
	for coordinate in seen:
		counts[coordinate] = int(counts.get(coordinate, 0)) + 1
	var duplicate_names: Array[String] = []
	var unknown_names: Array[String] = []
	for coordinate in counts.keys():
		if int(counts[coordinate]) > 1:
			duplicate_names.append(str(coordinate))
		if not catalog.has(coordinate):
			unknown_names.append(str(coordinate))
	var missing_names: Array[String] = []
	for coordinate in catalog.keys():
		if not counts.has(coordinate):
			missing_names.append(str(coordinate))
	duplicate_names.sort()
	missing_names.sort()
	unknown_names.sort()
	for coordinate in duplicate_names:
		errors.append("duplicate:%s" % coordinate)
	for coordinate in missing_names:
		errors.append("missing:%s" % coordinate)
	for coordinate in unknown_names:
		errors.append("unknown:%s" % coordinate)
	return errors
