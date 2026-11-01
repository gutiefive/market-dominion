extends RefCounted
class_name Coordinates

## Row-major A1..I9 catalog. Column labels and row count come from the shared rules file.


static func catalog() -> PackedStringArray:
	var rules = SharedFiles.read_json("fixtures/rules_constants.json")
	var coords := PackedStringArray()
	if rules == null:
		return coords
	var columns := str(rules["column_labels"])
	var rows := int(rules["board_rows"])
	for row in range(1, rows + 1):
		for col in range(columns.length()):
			coords.append("%s%s" % [columns.substr(col, 1), str(row)])
	return coords
