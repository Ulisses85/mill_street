class_name OptionsMenu
## Options: music and sound volume, fullscreen, screen shake. Shown in any MenuPanel
## (main menu and pause), saved with the progress. Press a setting to change it.

static func open(panel: MenuPanel, back: Callable, focus := 0) -> void:
	var s := Game.settings
	var rows := [
		["MUSIC  %s" % _bar(s.music), func(): _step(panel, back, 0, &"music")],
		["SOUND  %s" % _bar(s.sfx), func(): _step(panel, back, 1, &"sfx")],
		["SHAKE  %s" % ("ON" if s.shake else "OFF"), func(): _toggle(panel, back, 2, &"shake")],
	]
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		rows.append(["FULLSCREEN  %s" % ("ON" if s.fullscreen else "OFF"), func(): _toggle(panel, back, 3, &"fullscreen")])
	rows.append(["BACK", back])
	panel.open("OPTIONS", "PRESS TO CHANGE", rows, Color.WHITE, true, focus)


static func _bar(v: int) -> String:
	return "|".repeat(v) + ".".repeat(10 - v)


static func _step(panel: MenuPanel, back: Callable, row: int, key: StringName) -> void:
	Game.settings[key] = (int(Game.settings[key]) + 2) % 12 if int(Game.settings[key]) < 10 else 0
	Game.settings[key] = mini(int(Game.settings[key]), 10)
	_save_and_reopen(panel, back, row)


static func _toggle(panel: MenuPanel, back: Callable, row: int, key: StringName) -> void:
	Game.settings[key] = not Game.settings[key]
	_save_and_reopen(panel, back, row)


static func _save_and_reopen(panel: MenuPanel, back: Callable, row: int) -> void:
	Game.apply_settings()
	Game.save_progress()
	open(panel, back, row)
