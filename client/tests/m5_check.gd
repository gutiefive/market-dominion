extends SceneTree

## The online command envelope is shaped for the server. It does not apply a move.


func _initialize() -> void:
	var body := RoomCommands.envelope("room_check", "act_1", 3, "guesttoken", "place_tile", {"coordinate": "A1"})
	if body["match_id"] != "room_check" or body["client_action_id"] != "act_1":
		_fail("ids")
	if int(body["expected_state_version"]) != 3 or body["session_token"] != "guesttoken":
		_fail("version or token")
	if body["command"] != "place_tile" or str(body["payload"]["coordinate"]) != "A1":
		_fail("command")
	if body.has("cash") or body["payload"].has("cash"):
		_fail("client must not send cash")
	print("M5_CLIENT_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	print("M5_CLIENT_FAIL %s" % message)
	quit(1)
