extends Node
## Animation and move-set check: scripted moves in level 1, captured as frames.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 480x270 --fixed-fps 60 res://tests/feel.tscn
## Writes user://feel_<frame>.png (God mode on, so nothing interrupts) and prints what each move did.
var level
var frame := 0
var holds := {}      # action -> [from, to] frames held
var taps := {}       # frame -> [actions] pressed for one frame
var shots: Array = []

func _hold(a: StringName, f0: int, f1: int) -> void:
	holds[a] = holds.get(a, []) + [[f0, f1]]

func _tap(f: int, actions: Array) -> void:
	taps[f] = actions

func _ready() -> void:
	Game.god_mode = true
	level = load("res://scenes/levels/level_01.tscn").instantiate()
	add_child(level)
	_hold(&"move_right", 1, 4); _hold(&"move_right", 8, 125)   # double-tap and run towards the first thugs
	_hold(&"move_right", 126, 128); _tap(126, [&"punch"])                               # dash attack into them
	for f in [175, 187, 199, 211]: _tap(f, [&"punch"])  # 4-hit combo
	for f in [235, 243, 251]: _tap(f, [&"punch"])       # juggle the airborne thug
	_tap(280, [&"kick"])                                # special (power given below)
	_tap(320, [&"defend"])                              # dodge back
	_tap(350, [&"jump"]); _hold(&"move_right", 350, 370); _hold(&"move_down", 356, 360); _tap(358, [&"punch"])   # dive kick
	for f in [400, 412, 424]: _tap(f, [&"punch"])
	_hold(&"move_left", 434, 440); _tap(436, [&"punch"])  # over-the-shoulder finisher
	_tap(480, [&"taunt"])
	_hold(&"kick", 540, 546); _tap(541, [&"jump"])       # super
	for f in range(100, 600, 4): shots.append(f)

func _physics_process(_d: float) -> void:
	frame += 1
	var p = Game.player
	if frame == 275 and p: p.add_power(100.0)
	if frame == 530 and p: p.add_power(100.0)
	for a in [&"move_right", &"move_left", &"move_down", &"punch", &"kick", &"jump", &"defend", &"taunt"]:
		var on := false
		for r in holds.get(a, []):
			if frame >= r[0] and frame <= r[1]: on = true
		if on: Input.action_press(a)
		else: Input.action_release(a)
	for a in taps.get(frame, []):
		Input.action_press(a)
	if p and frame % 4 == 0 and frame >= 100:
		print("f%d state=%s anim=%s run=%s power=%d" % [frame, p.state, p.anim, p.running, int(p.power)])
	if frame in shots:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://feel_%04d.png" % frame)
	if frame > 600:
		get_tree().quit()
