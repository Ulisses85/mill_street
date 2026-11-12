extends Node
## Global game services (autoload "Game").
## - Registers the default input map (keyboard + joypad). Rebind in Project Settings or at runtime.
## - Hit-stop and screen shake requests.
## - Small helpers shared by units.

signal player_spawned(player: Node)
signal hud_message(text: String, duration: float, important: bool)
signal go_arrow(show: bool)
signal enemy_engaged(enemy: Node)
signal level_finished
signal player_died
signal pause_requested

const TICK := 1.0 / 60.0

## Frames left in the current hit-stop. Units skip their update while this is above zero.
var hitstop := 0
## While > 0, enemies run at half speed (perfect dodge).
var slowmo := 0
## Current screen-shake strength in pixels (decays every frame).
var shake := 0.0

var player: Node = null
var score := 0
## Debug: the player cannot be hit (DebugTools F2, or the test bot's `god` option).
var god_mode := false
## Random numbers for looks and sound only, so gameplay randomness stays reproducible with seed().
var fx_rng := RandomNumberGenerator.new()
signal score_changed(score: int)

const DEFAULT_ACTIONS := {
	"move_left":  {"keys": [KEY_A, KEY_LEFT],  "pad_buttons": [JOY_BUTTON_DPAD_LEFT],  "axis": [JOY_AXIS_LEFT_X, -1.0]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "pad_buttons": [JOY_BUTTON_DPAD_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0]},
	"move_up":    {"keys": [KEY_W, KEY_UP],    "pad_buttons": [JOY_BUTTON_DPAD_UP],    "axis": [JOY_AXIS_LEFT_Y, -1.0]},
	"move_down":  {"keys": [KEY_S, KEY_DOWN],  "pad_buttons": [JOY_BUTTON_DPAD_DOWN],  "axis": [JOY_AXIS_LEFT_Y, 1.0]},
	"punch":      {"keys": [KEY_J, KEY_Z],     "pad_buttons": [JOY_BUTTON_X]},
	"kick":       {"keys": [KEY_K, KEY_X],     "pad_buttons": [JOY_BUTTON_Y]},
	"defend":     {"keys": [KEY_I, KEY_C, KEY_SHIFT], "pad_buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"grab":       {"keys": [KEY_U, KEY_V],     "pad_buttons": [JOY_BUTTON_B]},
	"jump":       {"keys": [KEY_L, KEY_SPACE], "pad_buttons": [JOY_BUTTON_A]},
	"taunt":      {"keys": [KEY_T],            "pad_buttons": [JOY_BUTTON_BACK]},
	"pause":      {"keys": [KEY_P, KEY_ESCAPE], "pad_buttons": [JOY_BUTTON_START]},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	_load_progress()
	apply_settings()
	# crisp pixel text everywhere
	for f: Font in [load("res://assets/fonts/Silkscreen-Regular.ttf"), load("res://assets/fonts/Silkscreen-Bold.ttf")]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and player != null:
		pause_requested.emit()


func _physics_process(_delta: float) -> void:
	if slowmo > 0 and hitstop == 0:
		slowmo -= 1
	if hitstop > 0:
		hitstop -= 1
	shake = shake * 0.85 if shake > 0.3 else 0.0


func _register_input() -> void:
	for pair in [[&"ui_accept", KEY_J], [&"ui_accept", KEY_Z], [&"ui_cancel", KEY_K], [&"ui_cancel", KEY_X]]:
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], ev)
	for action in DEFAULT_ACTIONS:
		if InputMap.has_action(action):
			continue  # project settings win
		InputMap.add_action(action, 0.35)
		var spec: Dictionary = DEFAULT_ACTIONS[action]
		for k in spec.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for b in spec.get("pad_buttons", []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
		if spec.has("axis"):
			var jm := InputEventJoypadMotion.new()
			jm.axis = spec["axis"][0]
			jm.axis_value = spec["axis"][1]
			InputMap.action_add_event(action, jm)


func request_hitstop(frames: int) -> void:
	hitstop = maxi(hitstop, frames)


func request_shake(strength: float) -> void:
	if not settings.shake:
		return
	shake = maxf(shake, strength)


## Music and SFX volume (0-10) on their own audio buses, and fullscreen.
func apply_settings() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	for pair in [["Music", int(settings.music)], ["SFX", int(settings.sfx)]]:
		var i := AudioServer.get_bus_index(pair[0])
		var v: int = pair[1]
		AudioServer.set_bus_mute(i, v <= 0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v / 10.0, 0.001)))
	if not OS.has_feature("web") and not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)


func message(text: String, duration := 1.8, important := false) -> void:
	hud_message.emit(text, duration, important)


## Picks a random line from a .txt file (one name per line). Returns fallback if the file is missing.
func random_line(path: String, fallback: String) -> String:
	if path == "" or not FileAccess.file_exists(path):
		return fallback
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	var clean: Array[String] = []
	for l in lines:
		var s := l.strip_edges()
		if s != "":
			clean.append(s)
	return fallback if clean.is_empty() else clean[randi() % clean.size()]


# ---------- levels, progress, save ----------
const LEVEL_LIST_PATH := "res://resources/level_list.tres"
const SAVE_PATH := "user://save.cfg"
var level_list: LevelList
var current_level := -1
var unlocked := 1
var best_scores := {}
## Index into level_list.heroes of the hero the player picked.
var hero := 0
## Player settings (Options menu), saved with the progress.
var settings := {"music": 7, "sfx": 8, "fullscreen": false, "shake": true}


func _load_progress() -> void:
	level_list = load(LEVEL_LIST_PATH) if ResourceLoader.exists(LEVEL_LIST_PATH) else LevelList.new()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		unlocked = int(cfg.get_value("progress", "unlocked", 1))
		best_scores = cfg.get_value("progress", "best", {})
		for k in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])
		hero = clampi(int(cfg.get_value("progress", "hero", 0)), 0, maxi(0, level_list.heroes.size() - 1))


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "best", best_scores)
	cfg.set_value("progress", "hero", hero)
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SAVE_PATH)


func level_count() -> int:
	return level_list.levels.size()


func start_level(i: int) -> void:
	current_level = i
	score = 0
	player = null
	get_tree().paused = false
	get_tree().change_scene_to_file(level_list.levels[i].scene)


func restart_level() -> void:
	start_level(maxi(current_level, 0))


func next_level() -> void:
	if current_level + 1 < level_count():
		start_level(current_level + 1)
	else:
		go_to_main_menu()


func go_to_main_menu() -> void:
	player = null
	get_tree().paused = false
	get_tree().change_scene_to_file(level_list.main_menu_scene)


## Scene path of the chosen hero (empty = keep the hero the level was built with).
func hero_scene() -> String:
	if level_list == null or level_list.heroes.is_empty():
		return ""
	return level_list.heroes[clampi(hero, 0, level_list.heroes.size() - 1)]


## Hero select, then `then` (e.g. start level 1, or the level select).
var after_hero_select: Callable


func go_to_hero_select(then: Callable) -> void:
	if level_list.heroes.size() < 2:
		then.call()
		return
	after_hero_select = then
	player = null
	get_tree().paused = false
	get_tree().change_scene_to_file(level_list.hero_select_scene)


func go_to_level_select() -> void:
	player = null
	get_tree().paused = false
	get_tree().change_scene_to_file(level_list.level_select_scene)


## Called when the current level is finished. Unlocks the next one and stores the best score.
func complete_level() -> void:
	if current_level < 0:
		current_level = _index_of_current_scene()
	if current_level >= 0:
		best_scores[current_level] = max(int(best_scores.get(current_level, 0)), score)
		unlocked = clampi(max(unlocked, current_level + 2), 1, level_count())
		save_progress()


func is_last_level() -> bool:
	return current_level >= level_count() - 1


func _index_of_current_scene() -> int:
	var scene := get_tree().current_scene
	if scene == null:
		return -1
	for i in level_count():
		if level_list.levels[i].scene == scene.scene_file_path:
			return i
	return -1


func add_score(n: int) -> void:
	score += n
	score_changed.emit(score)
