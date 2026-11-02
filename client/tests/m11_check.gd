extends SceneTree

func _initialize() -> void:
	var identity := Rulesets.resolve()
	if identity.is_empty() or str(identity["id"]) != "classic_v1":
		_fail("Classic fingerprint differs between Python manifest and Godot canonical JSON")
		return
	for unsupported in ["dominion_v1", "classic_v2", "", "Classic"]:
		if not Rulesets.resolve(unsupported).is_empty() or OfflineMatch.create(7710, ["Rowan", "Quinn"], [], unsupported) != null:
			_fail("Unknown or disabled ruleset fell back to Classic")
			return
	var normal := OfflineMatch.create(7710, ["Rowan", "Quinn"])
	var explicit := OfflineMatch.create(7710, ["Rowan", "Quinn"], [], "classic_v1")
	if normal.ruleset_id != "classic_v1" or normal.ruleset_fingerprint != Rulesets.classic_fingerprint():
		_fail("Local match lost its explicit rule identity")
		return
	if JSON.stringify(normal.players) != JSON.stringify(explicit.players) or normal.bag != explicit.bag or normal.rng.state != explicit.rng.state:
		_fail("Explicit Classic selection changed the seeded deal")
		return
	var before := Rulesets.resolve()
	identity["fingerprint"] = "changed reader copy"
	if Rulesets.resolve() != before:
		_fail("A registry reader changed the canonical identity")
		return
	print("M11_CLIENT_OK Classic identity, cross-language fingerprint and disabled Dominion isolation")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
