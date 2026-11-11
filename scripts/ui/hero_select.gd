extends Node2D
## Hero select: one card per hero in Game.level_list.heroes, with an animated preview and stats.
## Picking one saves it and continues to Game.after_hero_select (level 1 or the level select).

@export var background: Texture2D

var tick := 0
var cards: Array[Button] = []
var previews: Array[SpriteAnimator] = []


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
	dim.color = Color(0.12, 0.11, 0.16, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	col.add_child(UITheme.label("PICK A FIGHTER", 16, Color("#ffd0ec")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	for i in Game.level_list.heroes.size():
		var info := _hero_info(Game.level_list.heroes[i])
		if info.is_empty():
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 168)
		b.focus_mode = Control.FOCUS_ALL
		b.text = "\n\n\n\n\n\n\n\n\n%s\nHP %d  SPEED %d" % [String(info.name).to_upper(), info.hp, int(info.speed)]
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_pick.bind(i))
		row.add_child(b)
		var s := SpriteAnimator.new()
		s.sheet_json = info.sheet
		s.position = Vector2(65, 112)
		b.add_child(s)
		cards.append(b)
		previews.append(s)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(Game.go_to_main_menu)
	var bc := CenterContainer.new()
	bc.add_child(back)
	col.add_child(bc)
	if not cards.is_empty():
		cards[clampi(Game.hero, 0, cards.size() - 1)].call_deferred(&"grab_focus")


## Name, HP, speed and sprite sheet, read from the hero's scene.
func _hero_info(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var h: Node = load(path).instantiate()
	var body := h.get_node_or_null("Body")
	var hs := h.get_node_or_null("HealthSystem")
	var info := {"name": h.get("unit_name"), "speed": h.get("move_speed"),
		"hp": hs.get("max_hp") if hs else 100, "sheet": body.get("sheet_json") if body else ""}
	h.free()
	return info


func _pick(i: int) -> void:
	Game.hero = i
	Game.save_progress()
	if Game.after_hero_select.is_valid():
		Game.after_hero_select.call()
	else:
		Game.start_level(0)


func _physics_process(_d: float) -> void:
	tick += 1
	for i in previews.size():
		var s := previews[i]
		# the focused hero plays its win pose (or walk), the others stand in their idle
		var anim := &"idle"
		if cards[i].has_focus():
			anim = &"win" if s.has_animation(&"win") else &"walk" if s.has_animation(&"walk") else &"run"
		s.show_frame(anim, tick)
