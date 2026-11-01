extends SceneTree

## Invitation links, fresh action IDs, standings, and failed socket handshakes.

var _closed_count := 0


func _initialize() -> void:
	var page := "https://play.example/index.html?server=https%3A%2F%2Fapi.example&session_token=secret"
	var link := OnlineTable.invitation_href(page, "AB12CD")
	if not link.begins_with("https://play.example/index.html?"):
		_fail("base")
	if "invite=AB12CD" not in link:
		_fail("invite")
	if "session_token" in link or "secret" in link:
		_fail("token leaked")
	if "server=https%3A%2F%2Fapi.example" not in link:
		_fail("server dropped")
	if OnlineTable.invite_from_search(link) != "AB12CD":
		_fail("round trip")
	if OnlineTable.invite_from_search("?session_token=abc") != "":
		_fail("token is not an invite")
	if OnlineTable.invitation_href("", "ZZ99") != "?invite=ZZ99":
		_fail("bare link")
	# Two new browsers and a refreshed page must never reuse an idempotency key.
	var first := OnlineTable.new()
	var second := OnlineTable.new()
	var first_id := first._next_action()
	if first_id == second._next_action() or first_id == first._next_action():
		_fail("action IDs collided across seats or commands")
	first.free()
	second.free()
	var state := {"players": [
		{"id": "p1", "cash": 100, "byte_count": 0, "holdings_by_corp": {"x": 2}, "turn_order_index": 0},
		{"id": "p2", "cash": 200, "byte_count": 0, "holdings_by_corp": {}, "turn_order_index": 1}],
		"corporations": [{"id": "x", "active": true, "share_price": 100}], "crypto_market": {"price": 500}}
	if OnlineTable.final_ranking(state) != PackedStringArray(["p1", "p2"]):
		_fail("final standings ignore holdings")
	call_deferred("_check_failed_handshake")


func _fail(message: String) -> void:
	push_error(message)
	print("M9_CLIENT_FAIL %s" % message)
	quit(1)


func _check_failed_handshake() -> void:
	var socket := RoomSocket.new()
	socket.closed.connect(func() -> void: _closed_count += 1)
	socket.connect_to("ws://127.0.0.1:1")
	for attempt in range(150):
		socket.poll()
		if _closed_count > 0:
			break
		await create_timer(0.02).timeout
	if _closed_count != 1:
		_fail("failed initial handshake did not emit closed")
	for attempt in range(5):
		socket.poll()
	if _closed_count != 1:
		_fail("closed was emitted repeatedly")
	var table := OnlineTable.new()
	root.add_child(table)
	var state: Dictionary = SharedFiles.read_json("fixtures/sample_lobby_state.json").duplicate(true)
	state["phase"] = "completed"
	var payload := {"you": "p1", "your_hand": [], "step": "completed", "pending_options": [], "state": state}
	table._reconnect_attempts = 2
	table._link_banner.text = "Connection lost"
	table._apply_snapshot(payload)
	if "Final standings" not in table._standings.text or "<null>" in table._badge.text or "Connection lost" in table._link_banner.text:
		_fail("completion view kept stale connection/turn state")
	state["phase"] = "playing"
	state["active_player_id"] = "p1"
	table._reconnect_attempts = 2
	table._apply_snapshot(payload)
	if "Reconnected" not in table._link_banner.text:
		_fail("healthy snapshot kept the reconnect warning")
	table.free()
	print("M9_CLIENT_OK")
	quit(0)
