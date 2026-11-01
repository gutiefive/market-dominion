extends SceneTree

## Production UI marks companies with a symbol and letters, and the rules panel names its sections.


func _initialize() -> void:
	var seen := {}
	if BoardGrid.SYMBOLS.size() != 5 or BoardGrid.MARKS.size() != 5:
		_fail("five companies")
	for corp_id in BoardGrid.SYMBOLS:
		var symbol := str(BoardGrid.SYMBOLS[corp_id])
		var mark := str(BoardGrid.MARKS[corp_id])
		if symbol == "" or mark == "" or symbol == mark:
			_fail("symbol and letters")
		if seen.has(symbol) or seen.has(mark):
			_fail("unique marks")
		seen[symbol] = true
		seen[mark] = true
	if RulesPanel.SECTION_TITLES.size() != 4:
		_fail("sections")
	var titles := " ".join(RulesPanel.SECTION_TITLES)
	if not titles.contains("Why prices change") or not titles.contains("Merger payouts"):
		_fail("explanations")
	if Palette.SCALES.size() != 3 or Palette.SCALES[0] != 1.0:
		_fail("text scale")
	print("M6_CLIENT_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	print("M6_CLIENT_FAIL %s" % message)
	quit(1)
