extends Node2D
## Visual check for normal-mapped (HD) sheets: the same frame unlit, then lit by a light on each side.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/normal_map_check.tscn -- bruiser
## Saves user://normal_check_<id>.png and quits.

var _frames := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cid: String = args[0] if args.size() > 0 else "bruiser"
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.2, 0.28)
	bg.size = Vector2(480, 270)
	add_child(bg)
	for i in 3:
		var s := SpriteAnimator.new()
		s.sheet_json = "res://assets/characters/%s/sheet.json" % cid
		s.position = Vector2(100 + i * 140, 220)
		s.light_mask = 1 if i > 0 else 2
		add_child(s)
		s.show_frame(&"idle", 0)
	var dark := CanvasModulate.new()
	dark.color = Color(0.55, 0.55, 0.6)
	add_child(dark)
	for p in [[Vector2(200, 150), Color(1.0, 0.75, 0.45)], [Vector2(450, 150), Color(0.5, 0.7, 1.0)]]:
		var l := PointLight2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.gradient = Gradient.new()
		g.gradient.set_color(0, Color.WHITE)
		g.gradient.set_color(1, Color(1, 1, 1, 0))
		g.width = 256
		g.height = 256
		l.texture = g
		l.position = p[0]
		l.color = p[1]
		l.energy = 1.6
		l.height = 40.0
		l.range_item_cull_mask = 1
		add_child(l)


func _process(_d: float) -> void:
	_frames += 1
	if _frames == 10:
		var cid: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "bruiser"
		get_viewport().get_texture().get_image().save_png("user://normal_check_%s.png" % cid)
		get_tree().quit()
