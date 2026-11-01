extends SceneTree

func _initialize() -> void:
	var theme := MarketTheme.build()
	var error := ResourceSaver.save(theme, "res://theme/market_theme.tres")
	if error != OK:
		push_error("theme save %s" % error_string(error))
		quit(1)
		return
	print("THEME_SAVED")
	quit(0)
