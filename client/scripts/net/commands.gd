extends RefCounted
class_name RoomCommands

## Build a command envelope. The server owns the match; this only names the request.


static func envelope(match_id: String, action_id: String, version: int, token: String, command: String, payload: Dictionary) -> Dictionary:
	return {
		"match_id": match_id,
		"client_action_id": action_id,
		"expected_state_version": version,
		"session_token": token,
		"command": command,
		"payload": payload,
	}
