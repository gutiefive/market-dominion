extends Control
class_name QuoteHistory

## Discrete recorded quote changes. Gaps are never joined or treated as zero.
var points: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(120, 36)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var low := 2147483647
	var high := 0
	for point in points:
		if point["price"] != null:
			low = mini(low, int(point["price"]))
			high = maxi(high, int(point["price"]))
	if high == 0 or points.size() < 2:
		return
	var previous: Variant = null
	for index in points.size():
		var value: Variant = points[index]["price"]
		if value == null:
			previous = null
			continue
		var y := 0.5 if high == low else float(int(value) - low) / float(high - low)
		var position := Vector2(5.0 + float(index) / float(points.size() - 1) * (size.x - 10.0), 5.0 + (1.0 - y) * (size.y - 10.0))
		if previous != null:
			draw_line(previous, position, Color("7dd3fc"), 2.0, true)
		draw_circle(position, 3.0, Color("e8eef9"))
		previous = position


static func description(values: Array) -> String:
	var parts: PackedStringArray = []
	for point in values:
		if point["price"] == null:
			parts.append("gap" if str(point["reason"]) == "Connection gap" else "unavailable")
		else:
			parts.append("$%d" % int(point["price"]))
	return "Recorded changes: " + " -> ".join(parts)
