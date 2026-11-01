extends RefCounted
class_name RoomSocket

## WebSocket client for one room session. WSS is the same peer with a wss:// URL.

signal message_received(payload: Dictionary)
signal closed

var peer: WebSocketPeer
var _active := false
var _started := 0


func connect_to(url: String) -> int:
	if peer != null:
		peer.close()
	peer = WebSocketPeer.new()
	_active = true
	_started = Time.get_ticks_msec()
	return peer.connect_to_url(url)


func poll() -> void:
	if peer == null:
		return
	peer.poll()
	var state := peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while peer.get_available_packet_count() > 0:
			var text := peer.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				message_received.emit(parsed)
	elif _active and (state == WebSocketPeer.STATE_CLOSED or (state == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() - _started > 10000)):
		_active = false
		peer.close()
		closed.emit()


func send_text(text: String) -> bool:
	if peer == null or peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	return peer.send_text(text) == OK


func is_open() -> bool:
	return peer != null and peer.get_ready_state() == WebSocketPeer.STATE_OPEN
