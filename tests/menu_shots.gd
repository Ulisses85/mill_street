extends Node
var frame := 0
var scene: Node
func _ready():
	var args := OS.get_cmdline_user_args()
	scene = load(args[0]).instantiate(); add_child(scene)
func _physics_process(_d):
	frame += 1
	if frame == 40:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/menu_%s.png" % OS.get_cmdline_user_args()[1])
		get_tree().quit()
