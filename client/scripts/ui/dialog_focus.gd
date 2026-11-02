extends Node
class_name DialogFocus

## Keeps keyboard navigation inside the most recently opened visible dialog.
static var _stack: Array[WeakRef] = []
var _dialog: Control
var _opener: WeakRef
var _active := false


static func install(dialog: Control) -> void:
	var guard := DialogFocus.new()
	dialog.add_child(guard)


func _ready() -> void:
	_dialog = get_parent() as Control
	_dialog.visibility_changed.connect(_visibility_changed)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	_visibility_changed()


func _visibility_changed() -> void:
	var showing := _dialog.is_visible_in_tree()
	if showing == _active:
		return
	_active = showing
	if showing:
		_opener = weakref(get_viewport().gui_get_focus_owner())
		_stack.append(weakref(self))
		call_deferred("_focus_first")
	else:
		_remove()
		if _opener != null:
			var previous = _opener.get_ref()
			if is_instance_valid(previous) and previous.is_visible_in_tree() and not previous.is_queued_for_deletion():
				previous.grab_focus()


func _remove() -> void:
	for index in range(_stack.size() - 1, -1, -1):
		if _stack[index].get_ref() == null or _stack[index].get_ref() == self:
			_stack.remove_at(index)


func _exit_tree() -> void:
	_remove()


func _top() -> bool:
	for index in range(_stack.size() - 1, -1, -1):
		var guard = _stack[index].get_ref()
		if is_instance_valid(guard) and guard._active and guard._dialog.is_visible_in_tree():
			return guard == self
	return false


func _choices(node: Node, result: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not child.is_queued_for_deletion():
			if child.focus_mode == Control.FOCUS_ALL and not (child is BaseButton and child.disabled):
				result.append(child)
		_choices(child, result)


func _focus_first() -> void:
	if not _top():
		return
	var choices: Array[Control] = []
	_choices(_dialog, choices)
	for choice in choices:
		if choice is Button and choice.text.to_lower().begins_with("cancel"):
			choice.grab_focus()
			return
	if not choices.is_empty():
		choices[0].grab_focus()


func _focus_changed(control: Control) -> void:
	if _top() and control != null and not _dialog.is_ancestor_of(control):
		call_deferred("_focus_first")


func _input(event: InputEvent) -> void:
	if not _top() or not event is InputEventKey or not event.pressed:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if event.keycode == KEY_TAB:
		var choices: Array[Control] = []
		_choices(_dialog, choices)
		if not choices.is_empty():
			var index := choices.find(focused)
			var step := -1 if event.shift_pressed else 1
			choices[posmod(index + step, choices.size())].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and (focused == null or not _dialog.is_ancestor_of(focused)):
		_focus_first()
		get_viewport().set_input_as_handled()
