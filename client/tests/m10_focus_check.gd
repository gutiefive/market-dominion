extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _key(code: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	var screen := load("res://scripts/ui/match_screen.gd").new() as Control
	root.add_child(screen)
	await process_frame
	screen._start_guided()
	screen._reveal()
	await process_frame
	var opener: Button = screen._place_button
	opener.grab_focus()
	screen._rules.show_panel()
	await process_frame
	await process_frame
	_check(screen._rules.is_ancestor_of(root.gui_get_focus_owner()), "Rules did not take keyboard focus")
	for index in range(8):
		await _key(KEY_TAB, index % 2 == 0)
		_check(screen._rules.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped Rules")
	opener.grab_focus()
	await process_frame
	await process_frame
	_check(screen._rules.is_ancestor_of(root.gui_get_focus_owner()), "Background focus was not contained")
	await _key(KEY_ESCAPE)
	_check(not screen._rules.visible and root.gui_get_focus_owner() == opener, "Rules did not restore opener on Escape")
	# A real required founder choice must retain focus; Escape cannot dismiss it.
	screen._founder_layer.visible = true
	var box: VBoxContainer = screen._modal_box(screen._founder_layer)
	var choice := Button.new()
	choice.text = "Required company"
	box.add_child(choice)
	await process_frame
	await process_frame
	await _key(KEY_ESCAPE)
	_check(screen._founder_layer.visible, "Escape dismissed a required company choice")
	await _key(KEY_TAB)
	_check(screen._founder_layer.is_ancestor_of(root.gui_get_focus_owner()), "Tab escaped required company choice")
	# Nested Rules returns focus to the underlying required choice.
	choice.grab_focus()
	screen._rules.show_panel()
	await process_frame
	await process_frame
	screen._rules.hide_panel()
	await process_frame
	_check(root.gui_get_focus_owner() == choice, "Nested Rules did not restore underlying dialog focus")
	screen._founder_layer.visible = false
	# Confirmations choose Cancel; Enter must not place a tile behind the dialog.
	var layer: Control = screen._confirm_layer
	opener.grab_focus()
	var before: int = screen._match.occupied.size()
	layer.visible = true
	await process_frame
	await process_frame
	_check(root.gui_get_focus_owner() is Button and root.gui_get_focus_owner().text.to_lower().begins_with("cancel"), "Confirmation did not choose safe Cancel focus")
	await _key(KEY_ENTER)
	_check(not layer.visible, "Enter on Cancel did not close confirmation")
	_check(screen._match.occupied.size() == before, "Enter activated a background placement")
	layer.visible = false
	screen.queue_free()
	await process_frame
	if not failed:
		print("M10_FOCUS_OK")
	quit(1 if failed else 0)
