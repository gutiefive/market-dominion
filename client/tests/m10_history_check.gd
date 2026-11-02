extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	var journal := MatchJournal.new()
	journal.observe(1, 1, {"BYTE": 500, "nova_ai": null}, "Opening quotes")
	journal.observe(1, 1, {"BYTE": 500, "nova_ai": null}, "Repeated snapshot")
	if journal.points("BYTE").size() != 1:
		failures.append("duplicate snapshot invented a price change")
	journal.observe(2, 3, {"BYTE": 450, "nova_ai": 200}, "Round event and founding")
	journal.observe(1, 2, {"BYTE": 999, "nova_ai": 999}, "Stale snapshot")
	if int(journal.points("BYTE").back()["price"]) != 450:
		failures.append("stale snapshot rewrote history")
	journal.gap()
	journal.observe(2, 3, {"BYTE": 450, "nova_ai": 200}, "Reconnect")
	var history := journal.points("BYTE")
	if history[-2]["price"] != null or str(history[-2]["reason"]) != "Connection gap":
		failures.append("reconnect history was interpolated")
	history.back()["price"] = 12345
	if int(journal.points("BYTE").back()["price"]) != 450:
		failures.append("history reader mutated recorded data")
	for index in range(4, 300):
		journal.observe(index, index, {"BYTE": 400 + index}, "Recorded change")
	if journal.points("BYTE", 1000).size() != MatchJournal.MAX_POINTS:
		failures.append("history exceeded its memory bound")
	var copy := QuoteHistory.description(journal.points("BYTE", 2))
	if "$698" not in copy or "$699" not in copy:
		failures.append("accessible history text disagrees with recorded points")

	var table := OfflineMatch.create(7710, ["Rowan", "Ada"])
	var before_planning := JSON.stringify([table.journal._quotes, table.journal._stats, table.rng.state])
	BotPolicy.decide(table)
	if before_planning != JSON.stringify([table.journal._quotes, table.journal._stats, table.rng.state]):
		failures.append("bot planning invented history or consumed the match RNG")
	var actor := str(table.active_player()["id"])
	var initial := int(table.active_player()["cash"])
	table.phase = "market"
	table.market_actions_left = 2
	if not bool(table.buy_byte()["ok"]):
		failures.append("controlled BYTE buy failed")
	# Keep the same actor for this isolated trade-accounting fixture.
	table.market_actions_left = 2
	if not bool(table.sell_byte()["ok"]):
		failures.append("controlled BYTE sale failed")
	var facts := table.journal.stats(actor)
	var before := JSON.stringify(facts)
	if bool(table.sell_byte()["ok"]) or before != JSON.stringify(table.journal.stats(actor)):
		failures.append("rejected trade changed statistics")
	if int(facts.get("buy_byte", 0)) != 1 or int(facts.get("sell_byte", 0)) != 1 or int(facts.get("spent", 0)) != 500 or int(facts.get("proceeds", 0)) != 500:
		failures.append("market trade amounts are inaccurate")
	if table.journal.points("BYTE").size() != 1:
		failures.append("price-taking trades invented quote movement")
	var analysis := table.journal.analysis(actor, initial, {"cash": initial, "net_worth": initial})
	if not bool(analysis["cash_reconciled"]) or int(analysis["net_change"]) != 0:
		failures.append("cash bridge did not reconcile")
	var changed := table.journal.analysis(actor, initial, {"cash": initial + 1, "net_worth": initial + 1})
	if bool(changed["cash_reconciled"]):
		failures.append("incomplete cash history presented as complete")
	if failures.is_empty():
		print("M10_HISTORY_OK recorded prices, gaps, bounded retention, trades and cash reconciliation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
