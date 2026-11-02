extends RefCounted
class_name ScriptedTutorial

## An authored deal and legal Classic commands, isolated from ordinary matches.
## No scoring, price, supply or end-condition overrides. Opponent moves are demonstrations.
const HUMAN := ["A1", "A2", "C1", "C2", "B2", "A3", "B1", "B3", "C3", "A4", "B4", "C4", "A5", "B5", "C5", "A6", "B6", "C6", "A7", "B7", "C7", "A8"]
const ADA := ["I9", "I8", "I7", "I6", "I5", "I4", "I3", "I2", "I1", "H1", "H2", "H3", "H4", "H5", "H6", "H7", "H8", "H9", "G9", "G8", "G7", "G6"]
var index := 0
var last_outcome := "This is a scripted practice game: the deal, events and Ada's moves are arranged to teach Classic. Ordinary matches use shuffled deals and computer decisions."
var steps: Array[Dictionary] = []


func _init() -> void:
	_step("place", "A1", "Your hand and the board", "Only tiles in your private hand can be placed. Select A1 with the lesson button, then press Place selected. An isolated tile stays unincorporated. Orthogonal neighbors connect; diagonals do not.")
	_step("buy_byte", "", "Cash becomes a holding", "Each turn gives two market actions after placement. Click Buy BYTE, read the confirmation and confirm. One BYTE costs the posted price; cash falls and your BYTE count rises. A trade does not move the quote. You need enough cash and exchange inventory to buy, and can sell only what you own.")
	_step("sell_byte", "", "Sell at the posted price", "Click Sell BYTE and confirm. Selling returns the posted price to cash and returns BYTE to the exchange. This uses your second market action. Ada's turn will wait for you to continue.")
	_demo("A round includes every seat", "Watch Ada place I9 and pass both market actions. Her hand stays private. A round event is drawn after the last seat finishes, not after each placement.")
	_event()
	_step("place", "A2", "Connect two districts", "Place A2 next to A1. Two connected unincorporated districts can become a company. This time a company-choice dialog will open before trading.")
	_step("founder", "nova_ai", "Found NOVA AI", "Choose NOVA AI in the dialog. The two districts become its company, and you receive one free founder share if the bank has one. Size and sector sentiment determine its posted price; the bank holds the other shares.")
	_step("buy_share", "nova_ai", "Buy a company share", "Select NA (NOVA AI) on the market, then Buy share and confirm. You spend the posted price and own one more share. Shares in an active company contribute count × current price to final net worth.")
	_step("sell_share", "nova_ai", "Sell a company share", "Sell one NOVA AI share and confirm. Cash rises and the share returns to the bank. You still hold your founder share. Buying and selling themselves do not change the quote.")
	_demo("Watch another founding", "Ada places I8 beside I9 and founds ORBIT PAY, receiving its founder share. She passes trading. Compare her company with yours, then inspect the new round event.")
	_event()
	_step("place", "C1", "Prepare a separate company", "Place C1. B1 is empty, so C1 is not connected to A1: a gap breaks a chain. It stays unincorporated even though NOVA AI is nearby.")
	_step("pass", "", "Passing is allowed", "Choose Pass one and confirm. A market action can be skipped without spending cash. You do not have to trade on every turn.")
	_step("pass", "", "Finish the market", "Pass the second market action. Finishing trading draws one replacement tile from the bag and hands the turn to the next seat. The lesson pauses before Ada moves.")
	_demo("Growth needs no new founder", "Ada places I7 into ORBIT PAY. An adjacent unincorporated district joins an existing company; its size and posted price update. No second founder share is awarded for growth.")
	_event()
	_step("place", "C2", "Found a second company", "Place C2 beside C1. B2 is still empty, so this pair is separate from NOVA AI. You will choose a different company.")
	_step("founder", "volt_grid", "Found VOLT GRID", "Choose VOLT GRID. You now own founder shares in two companies, each size two. This arrangement will let you learn a tied merger next turn.")
	_step("buy_share", "volt_grid", "Prepare to see a merger payout", "Select VG (VOLT GRID) and buy one share. You will hold two VOLT GRID shares. A losing company's shareholders receive the existing majority/minority bonuses and a buyout at its pre-merger quote.")
	_step("buy_share", "nova_ai", "Keep a stake in the survivor", "Select NA (NOVA AI) and buy one share. These shares will remain if NOVA AI survives. Holding the losing company and holding the survivor produce different outcomes.")
	_demo("Before the merger", "Ada grows ORBIT PAY at I6 and passes. Her separate company is not part of your upcoming merger: only connected companies participate.")
	_event()
	_step("place", "B2", "Join two companies", "Place B2 between A2 and C2. It connects NOVA AI and VOLT GRID. The largest company BEFORE placement normally survives automatically. Here both are size two, so you must choose a survivor. The new tile does not break the tie.")
	_step("survivor", "nova_ai", "Choose the tied survivor", "Choose NOVA AI. All five connected districts become NOVA AI. VOLT GRID pays bonuses and buys out your two shares at its old quote, then becomes inactive. The majority bonus pool is twice the old quote and the minority pool is once the quote. As the only holder, you receive both pools; tied holders split their pool, with leftover dollars by player id. Read the actual payout next; no share swap is required.")
	_step("buy_byte", "", "Hold BYTE through an event", "Buy one BYTE and keep it this time. At the next round event its posted price can rise or fall. Holding an asset exposes its final value to later repricing; cash itself does not reprice.")
	_step("pass", "", "Carry the holding forward", "Pass your remaining market action. Your cash and BYTE stay yours when the turn changes. Continue to watch Ada finish the round.")
	_demo("An event affects existing holdings", "Ada grows ORBIT PAY at I5 and passes. Watch the resulting event and compare BYTE's new posted value with the amount you paid.")
	_event()
	_step("place", "A3", "Grow the survivor", "Place A3 next to NOVA AI. The company grows from five to six districts, and its price is recalculated using the current AI sentiment. Your share count stays the same; each share can be worth more or less as quotes change.")
	_step("sell_byte", "", "Value versus sale proceeds", "Sell your BYTE at the CURRENT posted price. Compare this cash received with its purchase in the action/history records. A sale price is proceeds, not automatically a profit.")
	_step("pass", "", "Reach the endgame lesson", "Pass the remaining market action. Next you will watch the rest of this round and a clearly labelled demonstration of the middle game.")
	_demo("Finish this round", "Ada places I4 and passes. Read the event before moving on to the final-round demonstration.")
	_event()
	_step("fast_forward", "", "Demonstrate the middle game", "To avoid repeating identical growth turns, the lesson will play 15 scripted rounds for BOTH seats. Every placement, pass, draw and event uses the normal rules and remains in the real history. It stops with NOVA AI at size 21, just before the normal size-22 ending trigger.")
	_step("place", "A8", "Trigger the final round", "Place A8 to grow NOVA AI from 21 to 22 districts. Finish your market actions to trigger the final round. Every seat that has not acted this round still gets its turn; reaching the threshold does not immediately score the game.")
	_step("pass", "", "Final-round trading still counts", "Pass one market action. Trading follows the same rules in the last round. Final valuation will use the quotes after the final event, rather than purchase prices.")
	_step("pass", "", "Let the remaining seat finish", "Pass your last market action. NOVA AI has reached size 22, so the normal final-round flag is set. Ada still has her turn in this round.")
	_demo("Finish a real Classic match", "Watch Ada place G6 and pass. The final round event is applied and the existing scoring rules produce standings for both players.")
	_step("finish", "", "Read the final standings", "Net worth is cash + active company shares at their closing quotes + BYTE at its closing quote. Inactive shares have no value. Highest net worth wins; ties use cash, active share count, then opening order. Ordinary games can also end at 65 occupied districts, or when both the bag and all hands are empty. Read the closing holdings and the reconciled cash breakdown. You have now practiced placement, founding, shares, BYTE, passing, events, growth, tied mergers and the final round.")


func _step(action: String, arg: String, title: String, body: String) -> void:
	steps.append({"action": action, "arg": arg, "title": title, "body": body})


func _demo(title: String, body: String) -> void:
	_step("demo", "", title, body)


func _event() -> void:
	_step("event", "", "Read the round event", "The actual event above changed only its named sectors, clamped from −2 to +2, and changed BYTE by its stated percentage. Company quotes follow size and sector sentiment; BYTE follows its previous quote. Look at the market's numeric history to compare recorded changes. Continue when you have read the result.")


static func create_table() -> OfflineMatch:
	var table := OfflineMatch.create(7710, ["Rowan", "Ada"], ["Ada"])
	if str(table.players[0]["display_name"]) != "Rowan":
		table.players.reverse()
	var used := {}
	for seat in range(2):
		table.players[seat]["turn_order_index"] = seat
		table.players[seat]["hand"] = []
		var plan: Array = HUMAN if seat == 0 else ADA
		for index in range(5):
			table.players[seat]["hand"].append(plan[index])
			used[plan[index]] = true
	table.bag = []
	for index in range(5, HUMAN.size()):
		for plan in [HUMAN, ADA]:
			table.bag.append(plan[index])
			used[plan[index]] = true
	for cell in Coordinates.catalog():
		if not used.has(cell):
			table.bag.append(cell)
	# A fixed sequence of existing event cards, not new effects or altered prices.
	var deck: Array = SharedFiles.read_json("fixtures/round_events.json")["events"]
	table.events = []
	for cycle in range(3):
		table.events.append_array(deck.duplicate(true))
	return table


func current() -> Dictionary:
	return steps[index] if index < steps.size() else {"action": "done", "arg": "", "title": "Tutorial complete", "body": "Review the standings or return to the main menu to play an ordinary shuffled Classic match."}


func allows(action: String, arg: String = "") -> bool:
	var step := current()
	return str(step["action"]) == action and str(step["arg"]) == arg


static func dispatch(table: OfflineMatch, action: String, arg := "") -> Dictionary:
	match action:
		"place": return table.place(arg)
		"founder": return table.choose_founder(arg)
		"survivor": return table.choose_survivor(arg)
		"buy_share": return table.buy_share(arg)
		"sell_share": return table.sell_share(arg)
		"buy_byte": return table.buy_byte()
		"sell_byte": return table.sell_byte()
		"pass": return table.pass_market()
	return {"ok": false, "error": "Unknown local action"}


func remember(table: OfflineMatch, start: int) -> void:
	var lines := PackedStringArray()
	for line in table.log.slice(start):
		lines.append(str(line))
	last_outcome = "\n".join(lines)
	var human: Dictionary = table.players[0]
	last_outcome += "\nYour cash: $%d · BYTE: %d · NOVA AI shares: %d · VOLT GRID shares: %d" % [int(human["cash"]), int(human["byte_count"]), int(human["shares"]["nova_ai"]), int(human["shares"]["volt_grid"])]
	index += 1


func demonstrate(table: OfflineMatch, middle := false) -> Dictionary:
	var start := table.log.size()
	var before_byte := table.byte_price
	if middle:
		for turn in range(6, 21):
			var placed := _checked(table, "place", str(HUMAN[turn]))
			if not bool(placed["ok"]): return placed
			for action in range(2):
				var passed := _checked(table, "pass")
				if not bool(passed["ok"]): return passed
			var demo := _ada_turn(table)
			if not bool(demo["ok"]): return demo
	else:
		var demo := _ada_turn(table)
		if not bool(demo["ok"]): return demo
	remember(table, start)
	if not middle and not table.event_ids.is_empty():
		for event in SharedFiles.read_json("fixtures/round_events.json")["events"]:
			if str(event["id"]) == table.event_ids[-1]:
				last_outcome += "\nEvent rule: BYTE %+d%%, $%d to $%d (rounded to $10, within its price limits)." % [int(event["byte_delta_percent"]), before_byte, table.byte_price]
				var effects := PackedStringArray()
				for sector in event["sector_deltas"]:
					effects.append("%s %+d" % [table._sector_label(str(sector)), int(event["sector_deltas"][sector])])
				last_outcome += " Sector changes: " + ", ".join(effects) + "."
	if middle:
		last_outcome = "Demonstration complete: 30 legal placements, 60 market passes, replacement draws and 15 round events. NOVA AI is size %d. The game has not ended; your next placement will trigger the normal size-22 condition.\nYour cash: $%d." % [int(table._corp("nova_ai")["size"]), int(table.players[0]["cash"])]
	return {"ok": true, "log": last_outcome}


func _ada_turn(table: OfflineMatch) -> Dictionary:
	if str(table.active_player()["display_name"]) != "Ada" or table.phase != "place":
		return {"ok": false, "error": "Tutorial opponent is out of sequence"}
	var tile := ""
	for cell in ADA:
		if not bool(table.occupied[cell]):
			tile = str(cell)
			break
	var result := _checked(table, "place", tile)
	if not bool(result["ok"]): return result
	if table.phase == "choose_founder":
		result = _checked(table, "founder", "orbit_pay")
		if not bool(result["ok"]): return result
	for action in range(2):
		result = _checked(table, "pass")
		if not bool(result["ok"]): return result
	return result


func _checked(table: OfflineMatch, action: String, arg := "") -> Dictionary:
	var result := dispatch(table, action, arg)
	if bool(result["ok"]) and not table.economy_errors().is_empty():
		return {"ok": false, "error": "Tutorial invariant failed: %s" % str(table.economy_errors())}
	return result
