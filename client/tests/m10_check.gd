extends SceneTree

## Production scripted tutorial: explicit teaching, real controls, full match and responsive bounds.

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
	root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	var steps := 0
	var phases := {}
	var taught := {}
	# The first lesson blocks accidental game commands before it is acknowledged.
	var opening := _fingerprint(screen._match)
	screen._selected = "C1"
	screen._place_selected()
	if _fingerprint(screen._match) != opening:
		_fail("an unacknowledged/wrong tutorial action changed the game")
		return
	while screen._tutorial.index < screen._tutorial.steps.size() and steps < 100 and not _failed:
		var table: OfflineMatch = screen._match
		var before := _fingerprint(table)
		var info: Dictionary = screen._tutorial.current()
		if before != _fingerprint(table) or str(info["body"]) == "" or not screen._lesson_layer.visible:
			_fail("a teaching step was skipped or mutated the table")
			return
		var action := str(info["action"])
		var arg := str(info["arg"])
		await process_frame
		await process_frame
		var page: Control = screen._scroll.get_child(0)
		if page.size.x > 391 or screen._dock.get_global_rect().end.x > 391 or screen._dock.get_global_rect().end.y > 845:
			_fail("gameplay exceeded phone width at lesson %d: page=%s dock=%s" % [steps, page.size, screen._dock.get_global_rect()])
			return
		phases[table.phase] = true
		taught[action] = true
		if action in ["demo", "event", "fast_forward", "finish"]:
			screen._lesson_continue()
		else:
			screen._lesson_continue()
			# Off-script input must not consume a turn, tile or money.
			var snapshot := _fingerprint(table)
			screen._execute_local("place", "I9")
			if _fingerprint(table) != snapshot:
				_fail("off-script input mutated the table")
				return
			screen._lesson_continue()
			if action == "place":
				screen._select_guided_tile()
				if screen._selected != arg:
					_fail("lesson selector did not select its authored hand tile")
					return
				screen._place_selected()
			elif action == "founder":
				screen._choose_brand(arg)
			elif action == "survivor":
				screen._choose_survivor(arg)
			else:
				if arg != "":
					screen._select_corp(arg)
					var focused: Control = root.gui_get_focus_owner()
					if not focused is Button or focused.text != str(BoardGrid.MARKS[arg]):
						_fail("company selection lost keyboard focus")
						return
				screen._open_confirm(action)
				screen._apply_confirm()
		if not screen._match.economy_errors().is_empty() or screen._error.text != "":
			_fail("scripted progression broke an invariant or rejected a move: %s" % screen._error.text)
			return
		steps += 1
		await process_frame
	for action in ["founder", "survivor", "buy_share", "sell_share", "buy_byte", "sell_byte", "pass", "event", "fast_forward", "finish"]:
		if not taught.has(action):
			_fail("tutorial skipped mechanic: " + action)
			return
	# Replaying the authored commands produces identical rules state, logs and ledger.
	var replay := ScriptedTutorial.create_table()
	var course := ScriptedTutorial.new()
	while course.index < course.steps.size():
		var step := course.current()
		var kind := str(step["action"])
		if kind in ["demo", "fast_forward"]:
			var result := course.demonstrate(replay, kind == "fast_forward")
			if not bool(result["ok"]):
				_fail("scripted replay demonstration failed")
				return
		elif kind in ["event", "finish"]:
			course.index += 1
		else:
			var start := replay.log.size()
			var result := ScriptedTutorial.dispatch(replay, kind, str(step["arg"]))
			if not bool(result["ok"]) or not replay.economy_errors().is_empty():
				_fail("scripted replay action failed")
				return
			course.remember(replay, start)
	if _fingerprint(replay) != _fingerprint(screen._match):
		_fail("scripted replay diverged from UI playthrough")
		return
	if screen._match.event_ids.size() != 22 or int(screen._match._corp("nova_ai")["size"]) != 22 or not screen._match.final_round:
		_fail("the authored match did not finish via normal round/end rules")
		return
	if _failed:
		return
	if screen._match.phase != "completed" or not screen._standings.visible:
		_fail("guided match did not reach visible standings")
		return
	for row in screen._match.ledger:
		var analysis: Dictionary = screen._match.journal.analysis(str(row["id"]), screen._match.starting_cash, row)
		if not bool(analysis["cash_reconciled"]):
			_fail("completed local cash history did not reconcile")
			return
	if "Guided match complete" not in screen._standings.winner_label.text:
		_fail("guided completion was not identified")
		return
	# Desktop windows reflow at their real size instead of stretching a fixed canvas.
	root.size = Vector2i(1920, 1080)
	await process_frame
	if root.content_scale_size != Vector2i.ZERO or screen.get_viewport_rect().size != Vector2(1920, 1080) or screen.size != Vector2(1920, 1080):
		_fail("native-sized viewport did not use the resized window")
		return
	# Analysis remains inside a phone viewport at the largest existing text setting.
	var saved_scale := Palette.text_scale
	Palette.text_scale = float(Palette.SCALES[-1])
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(390, 844)
	Palette.restyle(screen)
	await process_frame
	await process_frame
	var card := screen._standings.get_node("Center/Card") as Control
	if card.size.x > 390 or card.get_global_rect().position.x < 0 or card.get_global_rect().end.x > 390 or card.get_global_rect().end.y > 844 or screen._standings.again_button.custom_minimum_size.y < 44:
		_fail("analysis layout: card=%s viewport=%s button_height=%s minimum=%s rectangle=%s" % [card.size, root.get_visible_rect().size, screen._standings.again_button.custom_minimum_size.y, card.get_combined_minimum_size(), card.get_global_rect()])
		return
	for button in screen._watch.find_children("*", "Button", true, false):
		if button.focus_mode != Control.FOCUS_ALL or button.get_theme_font_size("font_size") != Palette.px(14):
			_fail("history controls did not preserve focus or text scaling")
			return
	screen._standings.again_button.grab_focus()
	await process_frame
	await process_frame
	var scroll := screen._standings.get_node("Center/Card/Margin/Scroll") as ScrollContainer
	if screen._standings.again_button.get_global_rect().end.y > scroll.get_global_rect().end.y + 1:
		_fail("analysis did not scroll the focused replay control into view")
		return
	for lesson in range(screen._tutorial.steps.size()):
		screen._tutorial.index = lesson
		screen._present_lesson()
		await process_frame
		await process_frame
		var bounds: Rect2 = screen._lesson_card.get_global_rect()
		if bounds.position.x < 0 or bounds.end.x > 391 or bounds.position.y < 0 or bounds.end.y > 845 or screen._lesson_button.get_global_rect().end.y > 845:
			_fail("enlarged phone lesson overflow at %d: %s" % [lesson, bounds])
			return
	screen._lesson_layer.visible = false
	Palette.text_scale = saved_scale
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
	print("M10_CLIENT_OK scripted tutorial %d teaching steps; phases %s" % [steps, str(phases.keys())])
	quit(0)


func _fingerprint(table: OfflineMatch) -> String:
	return JSON.stringify([
		table.players, table.bag, table.occupied, table.company_of, table.corporations,
		table.phase, table.turn_index, table.market_actions_left, table.log, table.rng.state,
		table.round_number, table.sentiment, table.events, table.event_ids, table.final_round,
		table.pending, table.pending_options, table.pending_tile, table.byte_price,
		table.byte_exchange, table.ranking, table.ledger,
	])
