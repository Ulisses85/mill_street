extends Node2D
## Title screen.

@export var background: Texture2D
@export var title := "MILL STREET"
@export var title_accent := "BRAWL"
@export var subtitle := "BEAT 'EM UP TEMPLATE"

var tick := 0


func _ready() -> void:
	Game.player = null
	get_tree().paused = false
	Sfx.music(&"music_street")
	var bg := Sprite2D.new()
	bg.texture = background
	bg.centered = false
	bg.position = Vector2(-120, 0)
	add_child(bg)
	for spec in [["res://assets/characters/player/sheet.json", Vector2(200, 228), 1, &"idle"], ["res://assets/characters/thug/sheet.json", Vector2(290, 222), -1, &"idle"], ["res://assets/characters/brute/sheet.json", Vector2(340, 236), -1, &"idle"]]:
		var s := SpriteAnimator.new()
		s.sheet_json = spec[0]
		s.position = spec[1]
		s.flip_h = spec[2] < 0
		s.preview_animation = spec[3]
		s.set_meta(&"anim", spec[3])
		add_child(s)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := MenuPanel.new()
	layer.add_child(panel)
	var opts := [["START", func(): Game.start_level(0)], ["LEVEL SELECT", Game.go_to_level_select]]
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		opts.append(["QUIT", func(): get_tree().quit()])
	panel.open("", "", opts, Color.WHITE, false)
	panel.get_child(1).offset_top = 84
	var header := VBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 22
	header.add_theme_constant_override("separation", -6)
	header.add_child(UITheme.label(title, 32, Color.WHITE))
	header.add_child(UITheme.label(title_accent, 32, Color("#ff3a2a")))
	header.add_child(UITheme.label(subtitle, 8, Color("#4a4958")))
	header.theme = UITheme.get_theme()
	layer.add_child(header)


func _physics_process(_d: float) -> void:
	tick += 1
	for c in get_children():
		if c is SpriteAnimator:
			c.show_frame(c.get_meta(&"anim"), tick)
