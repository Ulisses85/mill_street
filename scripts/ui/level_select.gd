extends Node2D
## Level select: one card per level in Game.level_list. Locked levels unlock in order.

@export var background: Texture2D


func _ready() -> void:
	Game.player = null
	get_tree().paused = false
	var bg := Sprite2D.new()
	bg.texture = background
	bg.centered = false
	add_child(bg)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.11, 0.16, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	col.add_child(UITheme.label("PICK A STREET", 16, Color("#ffd0ec")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var first: Button = null
	for i in Game.level_count():
		var info: LevelInfo = Game.level_list.levels[i]
		var locked := i >= Game.unlocked
		var b := Button.new()
		b.custom_minimum_size = Vector2(136, 140)
		b.disabled = locked
		b.focus_mode = Control.FOCUS_ALL
		b.text = "\n\n\n\n\nLEVEL %d\n%s\n%s\nBEST %06d" % [i + 1, info.level_name, "???" if locked else info.boss_name, int(Game.best_scores.get(i, 0))]
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.pressed.connect(func(): Game.start_level(i))
		b.draw.connect(_draw_card.bind(b, info, locked))
		row.add_child(b)
		if not locked and (first == null or i == Game.unlocked - 1):
			first = b
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(Game.go_to_main_menu)
	var bc := CenterContainer.new()
	bc.add_child(back)
	col.add_child(bc)
	if first:
		first.call_deferred(&"grab_focus")


func _draw_card(b: Button, info: LevelInfo, locked: bool) -> void:
	var pal := info.palette
	var n := pal.size()
	for k in n:
		b.draw_rect(Rect2(6, 6 + k * 7, 124, 7), pal[n - 1 - k])
	for k in 8:
		var h := 10.0 + fposmod(sin(k * 12.9898 + info.level_name.length()) * 43758.5453, 1.0) * 26.0
		b.draw_rect(Rect2(6 + k * 15.5, 55 - h, 14, h), pal[2] if n > 2 else Color.DIM_GRAY)
	if locked:
		b.draw_rect(Rect2(6, 6, 124, 49), Color(0.12, 0.11, 0.16, 0.75))
		var f := UITheme.get_theme().default_font
		b.draw_string(f, Vector2(44, 34), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#d2d1de"))
