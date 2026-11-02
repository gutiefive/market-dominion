extends SceneTree

## Reproducible Classic regression, not a human playtest. Reports contain synthetic seats only.
const STEP_CAP := 600
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	failed = true
	push_error(message)
	quit(1)


func _run() -> void:
	var seeds := [0, 1, 4, 17, 7710]
	var seats := [2, 3, 4]
	var difficulties := ["easy"]
	var output := "user://m10-simulation.json"
	for arg in OS.get_cmdline_user_args():
		var bits := str(arg).split("=", true, 1)
		if bits.size() != 2:
			_fail("Use --seeds=0,1 --seats=2,3 --difficulties=easy --output=PATH")
			return
		match bits[0]:
			"--seeds", "--seats":
				var numbers: Array = []
				for token in bits[1].split(","):
					if not str(token).is_valid_int():
						_fail("Seed/seat values must be integers")
						return
					numbers.append(int(token))
				if bits[0] == "--seeds":
					seeds = numbers
				else:
					seats = numbers
			"--difficulties":
				difficulties = Array(bits[1].split(","))
			"--output":
				output = bits[1]
			_:
				_fail("Unknown simulation option")
				return
	var report := {"engine": Engine.get_version_info()["string"], "cases": [], "total_games": 0, "total_actions": 0}
	for difficulty in difficulties:
		if str(difficulty) not in ["easy", "normal", "hard"]:
			_fail("Unknown difficulty")
			return
		BotPolicy.set_difficulty(str(difficulty))
		for seed_value in seeds:
			for count in seats:
				if int(seed_value) < 0 or int(count) < 2 or int(count) > 4:
					_fail("Seeds must be nonnegative; seats must be 2–4")
					return
				var first := _play(int(seed_value), int(count))
				if failed:
					return
				var second := _play(int(seed_value), int(count))
				if failed:
					return
				if first["digest"] != second["digest"]:
					_fail("Deterministic replay diverged")
					return
				report["cases"].append({"seed": seed_value, "seats": count, "difficulty": difficulty, "actions": first["actions"], "max_action_us": maxi(int(first["max_action_us"]), int(second["max_action_us"])), "ranking": first["ranking"], "digest": first["digest"]})
				report["total_games"] += 2
				report["total_actions"] += int(first["actions"]) * 2
				print("M10_SIM_CASE seed=%d seats=%d difficulty=%s actions=%d max_action_us=%d" % [seed_value, count, difficulty, first["actions"], first["max_action_us"]])
				await process_frame
	BotPolicy.set_difficulty("normal")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write simulation report")
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("M10_SIM_OK %d games %d actions; %s" % [report["total_games"], report["total_actions"], output])
	quit(0)


func _play(seed_value: int, count: int) -> Dictionary:
	var names: Array = []
	for index in count:
		names.append("Seat %d" % (index + 1))
	var table := OfflineMatch.create(seed_value, names, names)
	var trace: Array = []
	var worst := 0
	while table.phase != "completed" and trace.size() < STEP_CAP:
		var began := Time.get_ticks_usec()
		var command := BotPolicy.decide(table)
		var result := BotPolicy.apply(table, command)
		worst = maxi(worst, Time.get_ticks_usec() - began)
		if not bool(result.get("ok", false)) or not table.economy_errors().is_empty():
			_fail("Simulation rejected an action or broke an economy/tile invariant")
			return {}
		for player in table.players:
			var facts := table.journal.analysis(str(player["id"]), table.starting_cash, {"cash": player["cash"], "net_worth": 0})
			if not bool(facts["cash_reconciled"]):
				_fail("Recorded cash history diverged from actual balances")
				return {}
		trace.append(command)
	if table.phase != "completed" or table.ranking.size() != count:
		_fail("Simulation did not complete within the action bound")
		return {}
	var digest := JSON.stringify([trace, table.ledger, table.event_ids, table.log]).sha256_text()
	return {"digest": digest, "actions": trace.size(), "ranking": table.ranking.duplicate(), "max_action_us": worst}
