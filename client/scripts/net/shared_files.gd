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
	var path := shared_path(relative)
	if not FileAccess.file_exists(path):
		push_error("Missing shared file: %s" % path)
		return null
	var parser := JSON.new()
	var text := FileAccess.get_file_as_string(path)
	if parser.parse(text) != OK:
		push_error("Invalid JSON in %s: %s" % [path, parser.get_error_message()])
		return null
	return parser.data
