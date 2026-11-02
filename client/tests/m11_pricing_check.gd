extends SceneTree

func _initialize() -> void:
	var vectors: Dictionary = SharedFiles.read_json("fixtures/dominion_v1/pricing_vectors.json")
	for case in vectors["quotes"]:
		var actual := DominionPricing.share_price(str(case["company_id"]), int(case["size"]), int(case["sentiment"]))
		if actual != int(case["price"]):
			_fail("Written Dominion quote failed: %s" % str(case))
			return
	var matrix: Array = []
	for company_id in vectors["company_order"]:
		for size in range(82):
			for sentiment in range(-2, 3):
				var actual := DominionPricing.share_price(company_id, size, sentiment)
				if actual < 0 or actual % 10 != 0:
					_fail("Quote is negative or not integer dollars in $10 steps")
					return
				if size > 0 and actual <= DominionPricing.share_price(company_id, size - 1, sentiment):
					_fail("Company growth did not increase its quote")
					return
				if sentiment > -2 and actual < DominionPricing.share_price(company_id, size, sentiment - 1):
					_fail("Increasing sentiment decreased its quote")
					return
				matrix.append([company_id, size, sentiment, actual])
	var digest := JSON.stringify(matrix, "", true).sha256_text()
	if matrix.size() != int(vectors["cases"]) or digest != str(vectors["matrix_sha256"]):
		_fail("Whole-board quotes disagree with the independent reference/Python matrix")
		return
	for invalid in [["unknown", 2, 0], ["unknown", 0, 0], [null, 2, 0], [true, 2, 0], ["nova_ai", -1, 0], ["nova_ai", 82, 0], ["nova_ai", 2, -3], ["nova_ai", 0, 3], ["nova_ai", true, 0], ["nova_ai", 2, false], ["nova_ai", 2.0, 0], ["nova_ai", 2, 1.5], ["nova_ai", "2", 0], ["nova_ai", 2, null]]:
		if DominionPricing.share_price(invalid[0], invalid[1], invalid[2]) != -1:
			_fail("Invalid input was accepted or fell back to Classic")
			return
	if Pricing.share_price(2, 1) != 220 or not Rulesets.resolve("dominion_v1").is_empty():
		_fail("Isolated Dominion pricing changed Classic or enabled the mode")
		return
	print("M11_PRICING_REPORT " + JSON.stringify({"cases": matrix.size(), "matrix_sha256": digest, "playable": false}))
	print("M11_PRICING_OK company identities, rounding, input bounds and whole-board parity")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
