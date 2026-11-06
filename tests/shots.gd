extends Node
## Renders level 1 with scripted input and saves screenshots to user:// (run under a display).
var level; var frame := 0
var shots := {40: "start", 150: "walk", 330: "fight1", 380: "fight2", 430: "fight3", 520: "fight4"}
func _ready():
	level = load("res://scenes/levels/level_01.tscn").instantiate(); add_child(level)
func _physics_process(_d):
	frame += 1
	var p = Game.player
	Input.action_release(&"move_right"); Input.action_release(&"punch"); Input.action_release(&"kick"); Input.action_release(&"jump")
	if frame < 300: Input.action_press(&"move_right")
	elif frame % 10 == 0: Input.action_press(&"punch" if frame % 40 else &"kick")
	if frame == 470: Input.action_press(&"jump")
	if frame == 476: Input.action_press(&"kick")
	if shots.has(frame):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/gd_%s.png" % shots[frame])
	if frame > 530: get_tree().quit()
