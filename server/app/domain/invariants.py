"""Public-state invariants that do not require a turn engine.

Assumptions A5, A6, and A7. The checker reports strings and does not mutate.
"""

from __future__ import annotations

from typing import Any

from app.contract import public_state_schema_errors
from app.domain.coordinates import all_coordinates
from app.domain.corporations import load_corporations
from app.domain.events import load_round_events, sectors
from app.files import load_rules


def public_state_errors(state: dict[str, Any]) -> list[str]:
    errors = public_state_schema_errors(state)
    if errors:
        return errors
    rules = load_rules()
    catalog = all_coordinates()
    board = state["board"]
    coordinates = [cell["coordinate"] for cell in board]
    if coordinates != catalog:
        return ["board coordinates must equal the catalog in catalog order"]
    occupied = 0
    for cell in board:
        if cell["occupied"]:
            occupied += 1
        elif cell["company_id"] is not None:
            errors.append(f"{cell['coordinate']}: empty cell cannot name a company")
    hand_total = 0
    seen_indexes: set[int] = set()
    holdings_by_corp: dict[str, int] = {}
    byte_held = 0
    for player in state["players"]:
        hand_total += int(player["hand_count"])
        index = int(player["turn_order_index"])
        if index in seen_indexes:
            errors.append(f"duplicate turn_order_index {index}")
        seen_indexes.add(index)
        byte_held += int(player["byte_count"])
        for corp_id, count in player["holdings_by_corp"].items():
            holdings_by_corp[corp_id] = holdings_by_corp.get(corp_id, 0) + int(count)
    if int(state["tile_bag_count"]) + hand_total + occupied != int(rules["tile_count"]):
        errors.append("tile counts must partition the full catalog")
    supply = int(rules["corporation_share_supply"])
    roster_ids = [corporation["id"] for corporation in state["corporations"]]
    if roster_ids != [corporation["id"] for corporation in load_corporations()]:
        errors.append("corporations must be the v1 roster in roster order")
    known_ids = set(roster_ids)
    for corp_id in holdings_by_corp:
        if corp_id not in known_ids:
            errors.append(f"holding names unknown corporation {corp_id}")
    by_coordinate = {cell["coordinate"]: cell for cell in board}
    for corporation in state["corporations"]:
        corp_id = corporation["id"]
        expected_cells = [
            coordinate
            for coordinate in catalog
            if by_coordinate[coordinate]["company_id"] == corp_id
        ]
        if corporation["cells"] != expected_cells:
            errors.append(f"{corp_id}: cells do not match the board in catalog order")
        if corporation["size"] != len(expected_cells):
            errors.append(f"{corp_id}: size does not match its cells")
        outstanding = holdings_by_corp.get(corp_id, 0)
        if int(corporation["bank_shares"]) + outstanding != supply:
            errors.append(f"{corp_id}: bank shares plus holdings must equal {supply}")
        if corporation["active"]:
            if corporation["size"] < 2:
                errors.append(f"{corp_id}: an active company needs at least 2 cells")
        else:
            if corporation["size"] != 0 or corporation["cells"] or corporation["share_price"] != 0:
                errors.append(f"{corp_id}: inactive companies have no cells and no price")
            if outstanding != 0 or int(corporation["bank_shares"]) != supply:
                errors.append(f"{corp_id}: inactive companies are fully back in the bank")
    market = state["crypto_market"]
    if int(market["exchange_coin_count"]) + byte_held != int(market["supply"]):
        errors.append("BYTE coins must sum to the fixed supply")
    if int(market["supply"]) != int(rules["byte_supply"]):
        errors.append("BYTE supply does not match the rules constant")
    if market["symbol"] != rules["byte_symbol"]:
        errors.append("crypto symbol must be BYTE")
    sentiment = state["sector_sentiment"]
    if set(sentiment) != set(sectors()):
        errors.append("sector sentiment must contain exactly the v1 sectors")
    phase = state["phase"]
    flag = bool(state["final_round_flag"])
    if phase in {"lobby", "playing"} and flag:
        errors.append("final_round_flag is only set once the final round starts")
    if phase in {"final_round", "completed"} and not flag:
        errors.append("final_round and completed phases require final_round_flag")
    if phase == "lobby" and state["active_player_id"] is not None:
        errors.append("lobby has no active player")
    if int(state["events_remaining"]) > len(load_round_events()):
        errors.append("events_remaining cannot exceed the deck size")
    return errors
