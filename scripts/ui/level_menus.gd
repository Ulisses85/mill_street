extends CanvasLayer
## In-level menus: pause, level complete, all levels complete and game over.

@export_range(0.0, 5.0, 0.1, "suffix:s") var finish_delay := 1.6

var panel: MenuPanel
var busy := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = MenuPanel.new()
	add_child(panel)
	Game.pause_requested.connect(_toggle_pause)
	Game.level_finished.connect(_on_finished)
	Game.player_died.connect(_on_died)


func _toggle_pause() -> void:
	if busy:
		return
	if get_tree().paused:
		_resume()
		return
	get_tree().paused = true
	_open_pause()


func _open_pause(focus := 0) -> void:
	panel.open("PAUSED", "", [["RESUME", _resume], ["OPTIONS", func(): OptionsMenu.open(panel, func(): _open_pause(1))],
		["RESTART", Game.restart_level], ["LEVEL SELECT", Game.go_to_level_select], ["MAIN MENU", Game.go_to_main_menu]], Color.WHITE, true, focus)


func _resume() -> void:
	panel.close()
	get_tree().paused = false


func _on_finished() -> void:
	busy = true
	Game.complete_level()
	Game.message("LEVEL CLEAR", finish_delay)
	await get_tree().create_timer(finish_delay).timeout
	get_tree().paused = true
	var info := "SCORE %06d" % Game.score
	if Game.is_last_level():
		panel.open("ALL LEVELS COMPLETE", info, [["MAIN MENU", Game.go_to_main_menu], ["LEVEL SELECT", Game.go_to_level_select]], Color("#ffd23a"))
	else:
		panel.open("LEVEL COMPLETE", info, [["NEXT LEVEL", Game.next_level], ["LEVEL SELECT", Game.go_to_level_select], ["MAIN MENU", Game.go_to_main_menu]], Color("#ffd23a"))


func _on_died() -> void:
	busy = true
	await get_tree().create_timer(1.0).timeout
	get_tree().paused = true
	panel.open("GAME OVER", "SCORE %06d" % Game.score, [["RETRY", Game.restart_level], ["LEVEL SELECT", Game.go_to_level_select], ["MAIN MENU", Game.go_to_main_menu]], Color("#ff5a3a"))
