extends CanvasLayer
## Debug tools (autoload "DebugTools"). Only active in the editor and in debug exports;
## release exports (Steam, itch, mobile) turn them off automatically.
##
##   F1  show / hide this panel          F6  slow motion (25%)
##   F2  god mode                        F7  show hitboxes, hurtboxes, FOV and bounds
##   F3  defeat the current wave         F8  full health + give a bat
##   F4  unlock all levels               F9  skip to the next level

const KEYS := {
	KEY_F1: "panel", KEY_F2: "god", KEY_F3: "kill_wave", KEY_F4: "unlock",
	KEY_F6: "slow", KEY_F7: "hitboxes", KEY_F8: "heal", KEY_F9: "next",
}

var enabled := false
var show_panel := false
var slow := false
var hitboxes := false
var _label: Label
var _overlay: Node2D


func _ready() -> void:
	enabled = OS.is_debug_build() and not OS.has_feature("headless_ci")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	if not enabled:
		set_process(false)
		set_process_unhandled_key_input(false)
		return
	_label = Label.new()
	_label.theme = UITheme.get_theme()
	_label.position = Vector2(4, 40)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("#ffd23a"))
	add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not KEYS.has(k.keycode):
		return
	get_viewport().set_input_as_handled()
	match KEYS[k.keycode]:
		"panel": show_panel = not show_panel
		"god": Game.god_mode = not Game.god_mode; _toast("GOD MODE " + _on(Game.god_mode))
		"kill_wave": _kill_wave()
		"unlock":
			Game.unlocked = Game.level_count()
			Game.save_progress()
			_toast("ALL LEVELS UNLOCKED")
		"slow":
			slow = not slow
			Engine.time_scale = 0.25 if slow else 1.0
			_toast("SLOW MOTION " + _on(slow))
		"hitboxes": hitboxes = not hitboxes; _toast("HITBOXES " + _on(hitboxes))
		"heal": _heal()
		"next": Game.next_level()


func _process(_d: float) -> void:
	_ensure_overlay()
	if _overlay:
		_overlay.visible = hitboxes
		_overlay.queue_redraw()
	if not show_panel:
		_label.text = "F1 DEBUG"
		return
	var wm := _wave_manager()
	var p := Game.player as Unit
	_label.text = "\n".join([
		"FPS %d   TIME x%.2f" % [Engine.get_frames_per_second(), Engine.time_scale],
		"F2 GOD %s   F6 SLOW %s   F7 BOXES %s" % [_on(Game.god_mode), _on(slow), _on(hitboxes)],
		"F3 KILL WAVE   F4 UNLOCK ALL   F8 HEAL+BAT   F9 NEXT LEVEL",
		"LEVEL %d   WAVE %s   ENEMIES LEFT %s" % [Game.current_level + 1, str(wm.current + 1) if wm else "-", str(wm.enemies_left) if wm else "-"],
		"PLAYER %s  HP %s  POS %s" % [p.state if p else "-", str(p.health.current_hp) if p else "-", str(p.position.round()) if p else "-"],
	])


func _on(b: bool) -> String:
	return "ON" if b else "OFF"


func _toast(s: String) -> void:
	Game.message(s, 1.0)


func _wave_manager() -> WaveManager:
	var lvl := Level.current
	return lvl.get_node_or_null("World/WaveManager") as WaveManager if lvl else null


func _kill_wave() -> void:
	var wm := _wave_manager()
	if wm == null or wm.current >= wm._waves.size():
		return
	var wave: Wave = wm._waves[wm.current]
	for e in wave.enemies():
		if is_instance_valid(e) and e.is_alive():
			e.health.damage(e.health.current_hp, Game.player)
			e.knockdown(1.0)
	_toast("WAVE DEFEATED")


func _heal() -> void:
	var p := Game.player as Unit
	if p == null:
		return
	p.health.restore()
	if ResourceLoader.exists("res://resources/weapons/bat.tres"):
		var bat: WeaponData = load("res://resources/weapons/bat.tres")
		p.held_weapon = bat
		p.weapon_uses = bat.uses
	_toast("HEALED + BAT")


# ---------- hitbox overlay ----------
func _ensure_overlay() -> void:
	var lvl := Level.current
	if lvl == null:
		_overlay = null
		return
	if _overlay and is_instance_valid(_overlay) and _overlay.get_parent() == lvl:
		return
	_overlay = Node2D.new()
	_overlay.z_index = 100
	_overlay.z_as_relative = false
	_overlay.draw.connect(_draw_overlay)
	lvl.add_child(_overlay)


func _draw_overlay() -> void:
	var o := _overlay
	var lvl := Level.current
	if lvl == null:
		return
	o.draw_rect(lvl.walk_area, Color(0.3, 0.9, 0.5, 0.7), false, 1.0)
	var cam := lvl.get_node_or_null("BeatCamera") as BeatCamera
	if cam and cam.level_bound < INF:
		o.draw_line(Vector2(cam.level_bound, 0), Vector2(cam.level_bound, 270), Color(1, 0.85, 0.1), 2.0)
	for u in o.get_tree().get_nodes_in_group(&"units"):
		var unit := u as Unit
		var feet := unit.position
		var top := feet.y - unit.z - unit.body_height
		if unit.state in [&"knockdown", &"dead"]:
			continue
		o.draw_rect(Rect2(feet.x - unit.body_half_width, top, unit.body_half_width * 2.0, unit.body_height), Color(0.3, 0.6, 1.0, 0.8), false, 1.0)
		o.draw_line(feet + Vector2(-10, 0), feet + Vector2(10, 0), Color(0.3, 0.6, 1.0), 1.0)
		var a := unit.current_attack
		if unit.state == &"attack" and a and a.depth_range >= 0.0:
			var active := a.is_active(unit.t)
			var x0 := feet.x + (a.reach_from if unit.face > 0 else -a.reach_to)
			var x1 := feet.x + (a.reach_to if unit.face > 0 else -a.reach_from)
			if a.hits_both_sides:
				x0 = feet.x - a.reach_to
				x1 = feet.x + a.reach_to
			var col := Color(1, 0.2, 0.2, 0.85) if active else Color(1, 0.6, 0.6, 0.35)
			o.draw_rect(Rect2(x0, top, x1 - x0, unit.body_height), col, false, 1.0)
			o.draw_rect(Rect2(x0, feet.y - a.depth_range, x1 - x0, a.depth_range * 2.0), Color(col, col.a * 0.4))
		if unit is Enemy and unit.enable_fov and unit.state == &"wait":
			var e := unit as Enemy
			var eye := feet + Vector2(e.view_pos_offset.x * e.face, e.view_pos_offset.y)
			var half := deg_to_rad(e.view_angle * 0.5)
			var base := 0.0 if e.face > 0 else PI
			var pts := PackedVector2Array([eye])
			for i in 9:
				var ang := base - half + 2.0 * half * i / 8.0
				pts.append(eye + Vector2(cos(ang), sin(ang)) * e.view_distance)
			o.draw_colored_polygon(pts, Color(1, 0.8, 0.2, 0.3 if e.target_in_sight else 0.12))
