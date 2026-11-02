extends SceneTree

var _failed := false
var _legal_swaps := 0
var _holdings_banks := 0


func _initialize() -> void:
	var fixtures: Dictionary = Rulesets._integer_numbers(SharedFiles.read_json("fixtures/dominion_v1/merger_vectors.json"))
	var traces: Array = []
	for case in fixtures["scenarios"]:
		var merger := _begin(case)
		if merger == null:
			_fail("Valid financial opening was rejected")
			return
		var trace: Array = [merger.export_state()]
		var queue: Array = []
		for choice in merger.export_state()["queue"]:
			queue.append([choice["loser_id"], choice["player_id"]])
		if queue != case["queue"]:
			_fail("Company/player resolution order differs from the specification")
			return
		for pairs in case["choices"]:
			var before := merger.export_state()
			merger = DominionMerger.from_export(JSON.parse_string(JSON.stringify(before)))
			if merger == null or merger.export_state() != before:
				_fail("JSON restore changed balances, bonus or the pending holder")
				return
			if not bool(_apply(merger, pairs)["ok"]):
				_fail("A legal shared choice was rejected")
				return
			_supply(merger.export_state())
			trace.append(merger.export_state())
		var final := merger.export_state()
		var holdings := {}
		for pid in final["shares"]: holdings[pid] = final["shares"][pid]["nova_ai"]
		if final["cash"] != case["cash"] or holdings != case["survivor_holdings"] or final["remaining_survivor_bank"] != case["survivor_bank"] or not final["complete"] or final["required_actor_id"] != null or final["resume_player_id"] != case["opening"]["placer_id"]:
			_fail("Cash/share results disagree with the manual financial vectors")
			return
		for cid in final["opening"]["losing_ids"]:
			if final["banks"][cid] != 20:
				_fail("Losing shares were not all returned to their bank")
				return
		if DominionMerger.from_export(JSON.parse_string(JSON.stringify(final))) == null:
			_fail("Completed resolution cannot be restored")
			return
		traces.append(trace)
	if JSON.stringify(traces, "", true).sha256_text() != str(fixtures["trace_sha256"]):
		_fail("Complete state trace differs from the shared versioned baseline")
		return
	_boundary_checks(fixtures["scenarios"][0])
	if _failed: return
	print("M11_MERGER_REPORT " + JSON.stringify({"scenarios": traces.size(), "trace_sha256": JSON.stringify(traces, "", true).sha256_text(), "holdings_bank_cases": _holdings_banks, "legal_swap_cases": _legal_swaps, "playable": false}))
	print("M11_MERGER_OK financial queue, bounded swaps, atomic rejections, replay, timeout and conservation")
	quit(0)


func _begin(case: Dictionary) -> DominionMerger:
	var o: Dictionary = case["opening"]
	return DominionMerger.begin(o["resolution_id"], o["survivor_id"], o["placer_id"], o["losing_ids"], o["companies"], o["players"])


func _apply(merger: DominionMerger, pairs: int, timed_out := false) -> Dictionary:
	var choice := merger.current_choice()
	var state := merger.export_state()
	var o: Dictionary = state["opening"]
	var action := "a%d" % int(state["version"])
	if timed_out:
		return merger.timeout(o["resolution_id"], choice["player_id"], choice["loser_id"], action, state["version"])
	return merger.choose(o["resolution_id"], choice["player_id"], choice["loser_id"], pairs, action, state["version"])


func _supply(state: Dictionary) -> void:
	for cid in state["banks"]:
		var bank: int = state["banks"][cid]
		var total := bank
		for pid in state["shares"]: total += int(state["shares"][pid][cid])
		if bank < 0 or bank > 20 or total != 20:
			_fail("Supply was created or destroyed")
	for cash in state["cash"].values():
		if int(cash) < 0: _fail("Negative cash")


func _boundary_checks(case: Dictionary) -> void:
	var merger := _begin(case)
	var before := merger.export_state()
	for args in [["other", "p1", "volt_grid", 0, "x", 0], ["m1", "p2", "volt_grid", 0, "x", 0], ["m1", "p1", "orbit_pay", 0, "x", 0], ["m1", "p1", "volt_grid", 0, "x", 1], ["m1", "p1", "volt_grid", -1, "x", 0], ["m1", "p1", "volt_grid", 3, "x", 0], ["m1", "p1", "volt_grid", true, "x", 0], ["m1", "p1", "volt_grid", 1.0, "x", 0], ["m1", "p1", "volt_grid", 0, "", 0], ["m1", "p1", "volt_grid", 0, "x", false]]:
		var result := merger.choose(args[0], args[1], args[2], args[3], args[4], args[5])
		if result["ok"] or merger.export_state() != before:
			_fail("Invalid action mutated financial state")
			return
	var first := _apply(merger, 2)
	merger = DominionMerger.from_export(merger.export_state())
	before = merger.export_state()
	if merger.current_choice()["max_pairs"] != 1 or _apply(merger, 2)["ok"] or merger.export_state() != before:
		_fail("A later holder consumed unavailable shares")
		return
	var duplicate := merger.choose("m1", "p1", "volt_grid", 2, "a0", 0)
	if not duplicate["duplicate"] or duplicate["receipt"] != first["receipt"] or merger.export_state() != before:
		_fail("An identical retry paid or swapped twice after restore")
		return
	if not merger.choose("m1", "p1", "volt_grid", 2, "a0", 1).get("duplicate", false) or merger.export_state() != before:
		_fail("Retry with a refreshed version did not retain its original receipt")
		return
	if merger.choose("m1", "p1", "volt_grid", 0, "a0", 0)["ok"] or merger.export_state() != before:
		_fail("Reused action id accepted a different exchange")
		return
	for field in ["cash", "bank", "cursor", "bonus_flag", "receipt", "version_bool", "snapshot", "actor", "extra"]:
		var bad := before.duplicate(true)
		match field:
			"cash": bad["cash"]["p1"] += 1
			"bank": bad["banks"]["nova_ai"] += 1
			"cursor": bad["cursor"] = 0
			"bonus_flag": bad["bonuses_paid"] = false
			"receipt": bad["decisions"][0]["receipt"]["cash_proceeds"] += 1
			"version_bool": bad["version"] = true
			"snapshot": bad["snapshots"]["volt_grid"]["price"] += 10
			"actor": bad["required_actor_id"] = "p1"
			"extra": bad["unexpected"] = "not ignored"
		if DominionMerger.from_export(bad) != null:
			_fail("A corrupt snapshot was silently accepted: " + field)
			return
	var private_case := case.duplicate(true)
	private_case["opening"]["players"][0]["hand"] = ["I9"]
	private_case["opening"]["players"][0]["session_token"] = "test-only-not-copied"
	var private_core := _begin(private_case)
	if "session_token" in JSON.stringify(private_core.export_state()) or '"hand"' in JSON.stringify(private_core.export_state()):
		_fail("Private metadata leaked into the financial snapshot")
		return
	var copied := private_core.export_state()
	copied["cash"]["p1"] = -1
	var copied_choice := private_core.current_choice()
	copied_choice["max_pairs"] = 99
	if private_core.export_state()["cash"]["p1"] != 1440 or private_core.current_choice()["max_pairs"] != 2:
		_fail("Reader copies changed the authoritative financial state")
		return
	merger = _begin(case)
	_apply(merger, 0, true)
	merger = DominionMerger.from_export(JSON.parse_string(JSON.stringify(merger.export_state())))
	before = merger.export_state()
	if not merger.timeout("m1", "p1", "volt_grid", "a0", 0)["duplicate"] or merger.export_state() != before:
		_fail("Repeated timeout paid again")
		return
	if merger.timeout("m1", "p1", "volt_grid", "late-deadline", 0)["ok"] or merger.export_state() != before:
		_fail("A late timeout affected the next shareholder")
		return
	_apply(merger, 0, true)
	if merger.export_state()["cash"] != {"p1": 2540, "p2": 1880}:
		_fail("Timeout did not sell the pending holder at the old quote")
		return
	for field in ["supply", "negative_cash", "huge_cash", "bool_cash", "huge_price", "duplicate_company", "duplicate_loser", "same_survivor", "unknown_placer", "missing_shares"]:
		var bad_case := case.duplicate(true)
		var opening: Dictionary = bad_case["opening"]
		match field:
			"supply": opening["companies"][0]["bank_shares"] -= 1
			"negative_cash": opening["players"][0]["cash"] = -1
			"huge_cash": opening["players"][0]["cash"] = 2147483648
			"bool_cash": opening["players"][0]["cash"] = true
			"huge_price": opening["companies"][0]["share_price"] = 1000000000
			"duplicate_company": opening["companies"][0] = opening["companies"][1].duplicate(true)
			"duplicate_loser": opening["losing_ids"].append(opening["losing_ids"][0])
			"same_survivor": opening["losing_ids"] = [opening["survivor_id"]]
			"unknown_placer": opening["placer_id"] = "p9"
			"missing_shares": opening["players"][0]["shares"].erase("nova_ai")
		if _begin(bad_case) != null:
			_fail("Invalid opening accepted: " + field)
			return
	for count in range(1, 21):
		for bank in range(21):
			_holdings_banks += 1
			for pairs in range(mini(Pricing.div_nonneg(count, 2), bank) + 1):
				_legal_swaps += 1
				var variant: Dictionary = case.duplicate(true)
				var o: Dictionary = variant["opening"]
				for player in o["players"]:
					player["shares"]["volt_grid"] = count if player["id"] == "p1" else 0
					player["shares"]["nova_ai"] = 20 - bank if player["id"] == "p2" else 0
				for corp in o["companies"]:
					if corp["id"] == "volt_grid": corp["bank_shares"] = 20 - count
					if corp["id"] == "nova_ai": corp["bank_shares"] = bank
				var transaction := _begin(variant)
				if transaction != null and pairs == 0:
					var unchanged := transaction.export_state()
					if _apply(transaction, mini(Pricing.div_nonneg(count, 2), bank) + 1)["ok"] or transaction.export_state() != unchanged:
						_fail("An over-request changed inventory or money")
						return
				if transaction == null or not _apply(transaction, pairs)["ok"]:
					_fail("A legal bank/holdings boundary case failed")
					return
				var final := transaction.export_state()
				_supply(final)
				if final["cash"]["p1"] != 1000 + 660 + (count - 2 * pairs) * 220 or final["shares"]["p1"]["nova_ai"] != pairs:
					_fail("Odd leftovers or swap supply produced the wrong money/shares")
					return


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
