extends Node
## Animation feel check: scripted moves in level 1, saved as a contact sheet of frames.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 480x270 --fixed-fps 60 res://tests/feel.tscn
## Writes user://feel_<n>.png for each captured frame (God mode on, so nothing interrupts).
var level
var frame := 0
var plan := {}          # frame -> action
var capture: Array = []

func _ready() -> void:
	Game.god_mode = true
	level = load("res://scenes/levels/level_01.tscn").instantiate()
	add_child(level)
	# walk, then double-tap to run, stop, pick up a bat (F8 gives one), swing it, then a punch combo
	for f in [20, 21, 22]: plan[f] = "tap_right"
	capture = [40, 46, 52, 140, 146, 152, 158]

func _physics_process(_d: float) -> void:
	frame += 1
	var p = Game.player
	for a in [&"move_right", &"punch", &"kick"]:
		Input.action_release(a)
	if frame < 60: Input.action_press(&"move_right")                     # walk
	elif frame in [100, 104]: Input.action_release(&"move_right")       # double-tap
	elif frame >= 100 and frame < 200 and frame != 103: Input.action_press(&"move_right")   # run
	if frame in [50, 150] and p: print("frame %d running=%s vx=%.0f anim=%s" % [frame, p.running, p.vx, p.anim])
	if frame == 230 and p:
		p.equip(load("res://resources/weapons/bat.tres"), 9)
	if frame in [240, 290]: Input.action_press(&"punch")                 # bat swings
	if frame in [340, 352, 364]: Input.action_press(&"punch")            # punch combo
	if frame in [400, 412]: Input.action_press(&"kick")
	if (frame >= 236 and frame <= 270 and frame % 3 == 0) or (frame >= 336 and frame <= 440 and frame % 4 == 0) or frame in [40, 46, 52, 140, 146, 152]:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://feel_%04d.png" % frame)
	if frame > 450:
		get_tree().quit()
