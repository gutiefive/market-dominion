extends RefCounted
class_name GuidedMatch

## Explanations read the real Classic state; they never change a deal or a move.

static func guidance(table: OfflineMatch) -> Dictionary:
	if table.phase == "completed":
		return {"title": "Guided match complete", "body": "Compare the final cash and portfolio values in the standings. Net worth decides the winner; cash, active shares, then opening order break ties."}
	if bool(table.active_player().get("bot", false)):
		return {"title": "Watch the computer", "body": "Ada follows the same placement and market rules. Her private tiles stay hidden. Your next turn starts automatically."}
	if table.phase == "choose_founder":
		return {"title": "2 · Found a company", "body": "Your tile joined an unincorporated cluster. Choose an available company in the dialog. You receive one founder share when the bank has one; the company price follows its size and sector sentiment."}
	if table.phase == "choose_survivor":
		return {"title": "2 · Resolve a merger", "body": "The largest companies tied. Choose a survivor in the dialog. The other companies pay their existing shareholder bonuses and buy out their shares. Compare the shown holdings before choosing."}
	if table.phase == "market":
		return {"title": "3 · Trade or pass", "body": "You have %d market action%s left. A buy spends cash at the posted price; a sell returns cash. You may pass instead. Finishing the market lets Ada play. At the end of each round an event changes sector sentiment and BYTE prices." % [table.market_actions_left, "" if table.market_actions_left == 1 else "s"]}
	var ending := " This is the final round; standings follow when every remaining seat finishes." if table.final_round else ""
	return {"title": "1 · Place one tile", "body": "Your hand lists the districts you can place. Select a hand tile and press Place selected, or press its highlighted board cell. Neighbors can found or grow a company; joining companies causes a merger. Then you get two market actions." + ending}


static func suggested_tile(table: OfflineMatch) -> String:
	if table.phase != "place" or bool(table.active_player().get("bot", false)):
		return ""
	var hand: Array = table.active_player()["hand"].duplicate()
	hand.sort()
	return "" if hand.is_empty() else str(hand[0])
