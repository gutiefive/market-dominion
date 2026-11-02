extends SceneTree

## M10 first slice: real menu routes, non-mutating guidance, and a complete guided Classic match.

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("M10_CLIENT_FAIL %s" % message)
	quit(1)


func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void: _fail("guided UI test timed out"))
	var screen := load("res://scripts/ui/match_screen.gd").new() as Control
	root.add_child(screen)
	if not screen._menu.visible or screen._setup.visible:
		_fail("main menu was not the default entry")
		return
	screen._start_guided()
	if not screen._guided or screen._match == null or not screen._order.visible:
		_fail("guided menu route did not create a match")
		return
	if screen._match.seed != 7710 or screen._match.players.size() != 2 or BotPolicy.difficulty != "easy":
		_fail("guided setup did not use the documented Classic configuration")
		return
	screen._reveal()
	var steps := 0
	var phases := {}
	while screen._match.phase != "completed" and steps < 500 and not _failed:
		var table: OfflineMatch = screen._match
		var before := _fingerprint(table)
		var info := GuidedMatch.guidance(table)
		GuidedMatch.suggested_tile(table)
		if before != _fingerprint(table) or str(info["body"]) == "":
			_fail("guidance mutated the match or lost its explanation")
			return
		phases[table.phase] = true
		if bool(table.active_player().get("bot", false)):
			_fail("computer turn did not return control to the human")
			return
		if table.phase == "place":
			screen._select_guided_tile()
			if screen._selected != GuidedMatch.suggested_tile(table):
				_fail("tile help did not select an actual hand tile")
				return
			screen._place_selected()
		elif table.phase == "choose_founder":
			screen._choose_brand(str(table._inactive()[0]["id"]))
		elif table.phase == "choose_survivor":
			screen._choose_survivor(table.pending_options[0])
		elif table.phase == "market":
			screen._apply(table.pass_market())
		else:
			_fail("unhandled tutorial phase")
			return
		if not screen._match.economy_errors().is_empty() or screen._error.text != "":
			_fail("guided progression broke an invariant or rejected a move")
			return
		steps += 1
		await process_frame
	if _failed:
		return
	if screen._match.phase != "completed" or not screen._standings.visible:
		_fail("guided match did not reach visible standings")
		return
	if "Guided match complete" not in screen._standings.winner_label.text:
		_fail("guided completion was not identified")
		return
	screen._show_menu()
	screen._open_local_setup(false)
	if screen._guided or screen._vs_bots.button_pressed or not screen._setup.visible:
		_fail("pass-and-play menu route inherited tutorial settings")
		return
	screen._show_online()
	if not screen._online.visible or screen._scroll.visible:
		_fail("menu online route did not open the existing room panel")
		return
	screen._hide_online()
	screen.queue_free()
	await process_frame
	await process_frame
	BotPolicy.set_difficulty("normal")
	print("M10_CLIENT_OK guided match %d human actions; phases %s" % [steps, str(phases.keys())])
	quit(0)


func _fingerprint(table: OfflineMatch) -> String:
	return JSON.stringify([
		table.players, table.bag, table.occupied, table.company_of, table.corporations,
		table.phase, table.turn_index, table.market_actions_left, table.log, table.rng.state,
		table.round_number, table.sentiment, table.events, table.event_ids, table.final_round,
		table.pending, table.pending_options, table.pending_tile, table.byte_price,
		table.byte_exchange, table.ranking, table.ledger,
	])
