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
	for spec in [[_hero_sheet(), Vector2(200, 228), 1, &"idle"], ["res://assets/characters/thug/sheet.json", Vector2(290, 222), -1, &"idle"], ["res://assets/characters/brute/sheet.json", Vector2(340, 236), -1, &"idle"]]:
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
	_panel = panel
	_open_main()
	var header := VBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 22
	header.add_theme_constant_override("separation", -6)
	header.add_child(UITheme.label(title, 32, Color.WHITE))
	header.add_child(UITheme.label(title_accent, 32, Color("#ff3a2a")))
	header.add_child(UITheme.label(subtitle, 8, Color("#4a4958")))
	header.theme = UITheme.get_theme()
	layer.add_child(header)
	_header = header


var _panel: MenuPanel
var _header: Control


func _open_main(focus := 0) -> void:
	if _header:
		_header.visible = true
	var opts := [["START", func(): Game.go_to_hero_select(func(): Game.start_level(0))],
		["LEVEL SELECT", func(): Game.go_to_hero_select(Game.go_to_level_select)],
		["OPTIONS", _open_options]]
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		opts.append(["QUIT", func(): get_tree().quit()])
	_panel.open("", "", opts, Color.WHITE, false, focus)
	_panel.get_child(1).offset_top = 84


func _open_options() -> void:
	_header.visible = false
	_panel.get_child(1).offset_top = 0
	OptionsMenu.open(_panel, func(): _open_main(2))


## The chosen hero's sprite sheet, for the title screen.
func _hero_sheet() -> String:
	var path := Game.hero_scene()
	if path != "" and ResourceLoader.exists(path):
		var h: Node = load(path).instantiate()
		var body := h.get_node_or_null("Body")
		var sheet: String = body.get("sheet_json") if body else ""
		h.free()
		if sheet != "":
			return sheet
	return "res://assets/characters/player/sheet.json"


func _physics_process(_d: float) -> void:
	tick += 1
	for c in get_children():
		if c is SpriteAnimator:
			c.show_frame(c.get_meta(&"anim"), tick)
