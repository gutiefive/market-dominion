extends RefCounted
class_name Rulesets

## Shared identity registry. No Dominion implementation or fallback is enabled.
const CLASSIC := "classic_v1"


static func classic_fingerprint() -> String:
	var manifest: Dictionary = SharedFiles.read_json("fixtures/rulesets.json")
	var constants: Dictionary = SharedFiles.read_json("fixtures/rules_constants.json")
	for key in manifest["classic_fingerprint_excluded_constants"]:
		constants.erase(key)
	var payload := {
		"constants": constants,
		"corporations": SharedFiles.read_json("fixtures/corporations.json")["corporations"],
		"events": SharedFiles.read_json("fixtures/round_events.json")["events"],
	}
	return JSON.stringify(_integer_numbers(payload), "", true).sha256_text()


static func resolve(ruleset_id: String = CLASSIC) -> Dictionary:
	var manifest: Dictionary = SharedFiles.read_json("fixtures/rulesets.json")
	for entry in manifest["rulesets"]:
		if str(entry["id"]) == ruleset_id:
			if ruleset_id != CLASSIC or not bool(entry["playable"]):
				return {}
			if classic_fingerprint() != str(entry["fingerprint"]):
				return {}
			return entry.duplicate(true)
	return {}


static func _integer_numbers(value: Variant) -> Variant:
	# Godot JSON parses numbers as floats; the canonical contract uses integers
	# for integral values, matching Python without depending on file whitespace.
	if value is float and value == floor(value):
		return int(value)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _integer_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_integer_numbers(item))
		return result
	return value
