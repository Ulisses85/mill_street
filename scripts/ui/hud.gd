extends Control
## Heads-up display: player portrait, name and health bar (top-left), the enemy you are
## fighting (top-right), score, combo counter, GO arrow and centre messages.

const INK := Color("#1e1c28")
const RED := Color("#d8261e")
const PANEL := Color("#ecebf3")
# Loaded at runtime, not preloaded: a preload fails on a fresh clone before Godot has imported the fonts.
var FONT: Font = load("res://assets/fonts/Silkscreen-Regular.ttf")
var FONT_B: Font = load("res://assets/fonts/Silkscreen-Bold.ttf")

@export var player_bar_width := 110
@export var enemy_bar_width := 110
@export var boss_bar_width := 150
@export_range(0.0, 10.0, 0.1, "suffix:s") var target_show_time := 2.5

var player: Unit = null
var target: Unit = null
var target_left := 0
var msg := ""
var msg_left := 0
var msg_important := false
var go_left := 0
var combo := 0
var ended := ""
var tick := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.player_spawned.connect(_on_player)
	Game.enemy_engaged.connect(func(e): target = e; target_left = int(target_show_time * 60.0))
	Game.hud_message.connect(func(s, d, imp): msg = s; msg_left = int(d * 60.0); msg_important = imp)
	Game.go_arrow.connect(func(on): go_left = 200 if on else 0)
	if Game.player:
		_on_player(Game.player)


func _on_player(p: Node) -> void:
	player = p
	if p.has_signal(&"combo_changed"):
		p.combo_changed.connect(func(n): combo = n)


func _physics_process(_delta: float) -> void:
	tick += 1
	if target_left > 0:
		target_left -= 1
	if msg_left > 0 and not get_tree().paused:
		msg_left -= 1
	if go_left > 0:
		go_left -= 1
	queue_redraw()


func _text(s: String, pos: Vector2, size := 8, col := INK, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(FONT_B if bold else FONT, pos, s, align, width, size, col)


func _outlined(s: String, center_x: float, y: float, size: int, col: Color) -> void:
	var f := FONT_B
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(round(center_x - w / 2), y)
	var t := 2 if size >= 32 else 1
	for dx in range(-t, t + 1):
		for dy in range(-t, t + 2):
			if dx != 0 or dy != 0:
				draw_string(f, p + Vector2(dx, dy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(pos: Vector2, w: int, pct: float, col: Color) -> void:
	draw_rect(Rect2(pos - Vector2.ONE, Vector2(w + 2, 7)), INK)
	draw_rect(Rect2(pos, Vector2(w, 5)), Color("#d2d1de"))
	var fw := roundf(w * clampf(pct, 0.0, 1.0))
	draw_rect(Rect2(pos, Vector2(fw, 5)), col)
	draw_rect(Rect2(pos, Vector2(fw, 1)), Color(1, 1, 1, 0.4))


## Power meter under the health bar, split into specials; flashes gold when a super is ready.
func _power_meter(pos: Vector2, w: int) -> void:
	if player.get("special_attack") == null and player.get("super_attack") == null:
		return
	var mx: float = player.max_power
	var pct: float = player.power / maxf(mx, 1.0)
	draw_rect(Rect2(pos - Vector2.ONE, Vector2(w + 2, 5)), INK)
	draw_rect(Rect2(pos, Vector2(w, 3)), Color("#4a4958"))
	var full := pct >= 1.0
	var col := Color("#ffd23a") if full and (tick / 6) % 2 == 0 else Color("#7fd4ff")
	draw_rect(Rect2(pos, Vector2(roundf(w * pct), 3)), col)
	var seg: float = player.special_cost
	var x := seg
	while x < mx - 0.5:
		draw_rect(Rect2(pos + Vector2(roundf(w * x / mx), 0), Vector2(1, 3)), INK)
		x += seg


func _portrait(pos: Vector2, tex: Texture2D) -> void:
	draw_rect(Rect2(pos, Vector2(22, 22)), INK)
	draw_rect(Rect2(pos + Vector2.ONE, Vector2(20, 20)), PANEL)
	draw_rect(Rect2(pos + Vector2(1, 16), Vector2(20, 5)), Color("#b2b1c2"))
	if tex:
		draw_texture(tex, pos + Vector2(1, 1))


func _draw() -> void:
	var W := size.x
	if player and is_instance_valid(player):
		var h: HealthSystem = player.health
		_portrait(Vector2(8, 6), player.portrait)
		_text(player.display_name, Vector2(34, 13), 8, INK, true)
		var low := h.current_hp <= h.max_hp * 0.25 and (tick / 8) % 2 == 0
		_bar(Vector2(34, 16), player_bar_width, float(h.current_hp) / h.max_hp, Color("#ff8a2a") if low else RED)
		_power_meter(Vector2(34, 24), player_bar_width)
		var lives: int = player.get("lives") if player.get("lives") != null else 0
		for i in lives:
			var c := Vector2(152 + i * 9, 18)
			draw_circle(c, 3.5, INK)
			draw_circle(c, 2.5, PANEL)
		_text("%06d" % Game.score, Vector2(34, 36), 8, Color("#4a4958"))
		var w: WeaponData = player.get("held_weapon")
		if w:
			_text("%s x%d" % [w.weapon_name, player.weapon_uses], Vector2(80, 36), 8, Color("#4a4958"))
	var boss: Unit = null
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e.get("is_boss") and e.state != &"wait" and e.state != &"dead" and e.is_alive():
			boss = e
	var show: Unit = boss if boss else (target if target and is_instance_valid(target) and target_left > 0 and target.state != &"dead" else null)
	if show:
		var th: HealthSystem = show.health
		var bw := boss_bar_width if show == boss else enemy_bar_width
		var tg := show
		_portrait(Vector2(W - 30, 6), tg.portrait)
		var name_w := FONT_B.get_string_size(tg.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(tg.display_name, Vector2(W - 36 - name_w, 13), 8, INK, true)
		_bar(Vector2(W - 36 - bw, 16), bw, float(th.current_hp) / th.max_hp, RED)
	if combo >= 2:
		_outlined("%d HITS" % combo, W / 2, 52, 16, Color("#ffd23a"))
	if go_left > 0 and (go_left / 16) % 2 == 0:
		_outlined("GO", W - 46, 140, 16, Color("#ff3a2a"))
		draw_colored_polygon(PackedVector2Array([Vector2(W - 28, 124), Vector2(W - 10, 134), Vector2(W - 28, 144)]), INK)
		draw_colored_polygon(PackedVector2Array([Vector2(W - 26, 127), Vector2(W - 14, 134), Vector2(W - 26, 141)]), Color("#ff3a2a"))
	if msg_left > 0 and msg != "":
		draw_rect(Rect2(0, 98, W, 30), Color(0.12, 0.11, 0.16, 0.82))
		_outlined(msg, W / 2, 120, 16, Color("#ff5a3a") if msg_important else Color.WHITE)
