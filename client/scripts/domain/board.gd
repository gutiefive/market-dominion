extends RefCounted
class_name BoardGraph

## Orthogonal districts. Diagonals do not connect. Components use catalog order.


static func neighbors(coordinate: String) -> PackedStringArray:
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	var found := PackedStringArray()
	if rules == null or coordinate.length() < 2:
		return found
	var labels := str(rules["column_labels"])
	var rows := int(rules["board_rows"])
	var column := labels.find(coordinate.substr(0, 1))
	if column == -1:
		return found
	var row := coordinate.substr(1).to_int()
	if row < 1 or row > rows:
		return found
	var deltas := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for delta in deltas:
		var next_column := column + int(delta.x)
		var next_row := row + int(delta.y)
		if next_column >= 0 and next_column < labels.length() and next_row >= 1 and next_row <= rows:
			found.append("%s%s" % [labels.substr(next_column, 1), str(next_row)])
	return found


static func component(origin: String, filled: Dictionary) -> PackedStringArray:
	var ordered := PackedStringArray()
	if not bool(filled.get(origin, false)):
		return ordered
	var seen := {}
	var stack: Array[String] = [origin]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		if seen.has(current) or not bool(filled.get(current, false)):
			continue
		seen[current] = true
		for neighbor in neighbors(current):
			stack.append(str(neighbor))
	for coordinate in Coordinates.catalog():
		if seen.has(coordinate):
			ordered.append(coordinate)
	return ordered
