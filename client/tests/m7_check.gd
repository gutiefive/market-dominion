extends SceneTree

## The web page may pass ?server=http(s)://... and nothing else.


func _initialize() -> void:
	if OnlineTable.server_from_search("?server=https%3A%2F%2Fapi.example%2Fgame") != "https://api.example/game":
		_fail("https query")
	if OnlineTable.server_from_search("?x=1&server=http://127.0.0.1:8741") != "http://127.0.0.1:8741":
		_fail("http query")
	if OnlineTable.server_from_search("?server=javascript:alert(1)") != "":
		_fail("scheme")
	if OnlineTable.server_from_search("") != "":
		_fail("empty")
	print("M7_CLIENT_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	print("M7_CLIENT_FAIL %s" % message)
	quit(1)
