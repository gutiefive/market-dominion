extends SceneTree

## Invitation links name the room and never carry a session token.


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
	print("M9_CLIENT_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	print("M9_CLIENT_FAIL %s" % message)
	quit(1)
