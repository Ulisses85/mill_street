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

const TICK := 1.0 / 60.0

## Frames left in the current hit-stop. Units skip their update while this is above zero.
var hitstop := 0
## Current screen-shake strength in pixels (decays every frame).
var shake := 0.0

var player: Node = null
var score := 0
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
	"pause":      {"keys": [KEY_P, KEY_ESCAPE], "pad_buttons": [JOY_BUTTON_START]},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	# crisp pixel text everywhere
	for f in [preload("res://assets/fonts/Silkscreen-Regular.ttf"), preload("res://assets/fonts/Silkscreen-Bold.ttf")]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and player != null:
		get_tree().paused = not get_tree().paused
		hud_message.emit("PAUSED" if get_tree().paused else "", 9999.0 if get_tree().paused else 0.0, false)


func _physics_process(_delta: float) -> void:
	if hitstop > 0:
		hitstop -= 1
	shake = shake * 0.85 if shake > 0.3 else 0.0


func _register_input() -> void:
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
	shake = maxf(shake, strength)


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


func add_score(n: int) -> void:
	score += n
	score_changed.emit(score)
