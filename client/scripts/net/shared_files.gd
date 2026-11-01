extends RefCounted
class_name SharedFiles

## Read JSON from the repository `shared/` directory next to `client/`.


static func shared_path(relative: String) -> String:
	var client_dir := ProjectSettings.globalize_path("res://")
	if client_dir.ends_with("/"):
		client_dir = client_dir.substr(0, client_dir.length() - 1)
	var root := client_dir.get_base_dir()
	return root.path_join("shared").path_join(relative)


static func read_json(relative: String):
	var external := shared_path(relative)
	if FileAccess.file_exists(external):
		return _parse(external)
	# Web export has no sibling shared/ directory. export_web.sh copies it into the pack.
	var packed := "res://export_shared/%s" % relative
	if FileAccess.file_exists(packed):
		return _parse(packed)
	push_error("Missing shared file: %s" % external)
	return null


static func _parse(path: String):
	var parser := JSON.new()
	var text := FileAccess.get_file_as_string(path)
	if parser.parse(text) != OK:
		push_error("Invalid JSON in %s: %s" % [path, parser.get_error_message()])
		return null
	return parser.data
