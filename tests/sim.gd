extends Node
## Bot playthrough test. A simple bot plays one level with real inputs and reports the result.
##
##   godot --headless --path . res://tests/sim.tscn -- level_02 [god] [seed=7] [timeout=300] [shots=900,1500] [quiet]
##
## Options:
##   god        player can't be hit (tests that the level can be finished, not bot skill)
##   seed=N     random seed, so a failing run can be replayed exactly
##   timeout=S  give up after S seconds of game time (default 300)
##   shots=...  save screenshots at these frames (needs a display, e.g. xvfb-run)
##   boxes      show the debug panel and hitbox overlay (for screenshots)
##   quiet      only print the result line
##
## Exit codes: 0 level finished, 1 timeout, 2 player died, 3 script/setup error.
## The last line is a machine-readable summary starting with RESULT.

var level: Node
var frame := 0
var level_name := "level_01"
var timeout_frames := 60 * 300
var shots: Array = []
var quiet := false
var hits_taken := 0
var waves_cleared := 0
var last_pos := Vector2.ZERO
var stuck_frames := 0
var detour := 0
var detour_dir := 1.0
var done := false


func _ready() -> void:
	var rng_seed := 7
	var hero := 0          # the default hero unless hero= says otherwise (ignores the saved choice)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level_"):
			level_name = a
		elif a == "god":
			Game.god_mode = true
		elif a == "boxes":
			DebugTools.hitboxes = true
			DebugTools.show_panel = true
		elif a == "quiet":
			quiet = true
		elif a.begins_with("hero="):
			# hero=1 (index in level_list.heroes) or hero=mel (scene file player_mel.tscn / mel.tscn)
			var want := a.substr(5)
			for i in Game.level_list.heroes.size():
				if want == str(i) or Game.level_list.heroes[i].get_file().get_basename() in ["player_" + want, want]:
					hero = i
		elif a.begins_with("seed="):
			rng_seed = int(a.substr(5))
		elif a.begins_with("timeout="):
			timeout_frames = int(a.substr(8)) * 60
		elif a.begins_with("shots="):
			for f in a.substr(6).split(","):
				shots.append(int(f))
	seed(rng_seed)
	Game.hero = hero
	var path := "res://scenes/levels/%s.tscn" % level_name
	if not ResourceLoader.exists(path):
		_finish(3, "missing scene " + path)
		return
	Game.current_level = int(level_name.right(1)) - 1
	level = load(path).instantiate()
	add_child(level)
	var wm := level.get_node("World/WaveManager")
	wm.wave_started.connect(func(i): _log("wave %d started" % (i + 1)))
	wm.wave_cleared.connect(func(i): waves_cleared += 1; _log("wave %d cleared" % (i + 1)))
	Game.level_finished.connect(func(): _finish(0, "level finished"))
	Game.player_died.connect(func(): _finish(2, "player died"))
	await get_tree().process_frame
	Game.player.health.damaged.connect(func(a, _src): hits_taken += 1; _log("player hit -%d (hp %d)" % [a, Game.player.health.current_hp]))
	_log("seed %d, god=%s" % [rng_seed, Game.god_mode])


func _log(s: String) -> void:
	if not quiet:
		print("[%05d] %s" % [frame, s])


func _finish(code: int, why: String) -> void:
	if done:
		return
	done = true
	var p = Game.player
	if code == 1 and not quiet:
		for e in get_tree().get_nodes_in_group(&"enemies"):
			print("  left: %s %s state=%s pos=%s hp=%d" % [e.name, e.display_name, e.state, e.position.round(), e.health.current_hp])
	print("RESULT level=%s code=%d reason=\"%s\" frames=%d seconds=%.1f waves_cleared=%d hits_taken=%d lives_left=%s" % [
		level_name, code, why, frame, frame / 60.0, waves_cleared, hits_taken, str(p.lives) if p else "-"])
	get_tree().quit(code)


func _press(a: StringName) -> void:
	Input.action_press(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(a)


func _physics_process(_d: float) -> void:
	if done:
		return
	frame += 1
	if frame in shots:
		await RenderingServer.frame_post_draw
		var out := OS.get_user_data_dir().path_join("sim_%s_%05d.png" % [level_name, frame])
		get_viewport().get_texture().get_image().save_png(out)
		_log("screenshot " + out)
	var p = Game.player
	if p == null:
		return
	for act in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(act)
	if p.state == &"held":       # grabbed by an enemy: mash like a player would (about 6 presses a second)
		if frame % 10 == 0:
			_press(&"punch")
		return
	# stuck detection: walk around whatever is in the way
	if p.state == &"walk" and p.position.distance_to(last_pos) < 0.2:
		stuck_frames += 1
	else:
		stuck_frames = 0
	last_pos = p.position
	if stuck_frames > 45 and detour == 0:
		detour = 40
		detour_dir = -1.0 if p.position.y > 205.0 else 1.0
	if detour > 0:
		detour -= 1
		Input.action_press(&"move_down" if detour_dir > 0 else &"move_up")
		Input.action_press(&"move_right")
	else:
		_fight(p)
	if frame % 600 == 0:
		var wm = level.get_node("World/WaveManager")
		_log("status x=%d hp=%d state=%s lives=%d wave=%d enemies_left=%d" % [p.position.x, p.health.current_hp, p.state, p.lives, wm.current + 1, wm.enemies_left])
	if frame > timeout_frames:
		_finish(1, "timeout")


func _fight(p) -> void:
	var nearest = null
	var best := 1e9
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e.is_alive() and e.state != &"wait":
			var d: float = abs(e.position.x - p.position.x) + abs(e.position.y - p.position.y) * 2.0
			if d < best:
				best = d
				nearest = e
	if nearest == null:
		Input.action_press(&"move_right")
		return
	var dx: float = nearest.position.x - p.position.x
	var dy: float = nearest.position.y - p.position.y
	if abs(dy) > 4:
		Input.action_press(&"move_down" if dy > 0 else &"move_up")
	if abs(dx) > 26:
		Input.action_press(&"move_right" if dx > 0 else &"move_left")
	elif abs(dy) <= 6 and frame % 9 == 0:
		if p.face != sign(dx):
			Input.action_press(&"move_right" if dx > 0 else &"move_left")
		var r := (frame / 9) % 7
		if r == 3:
			_press(&"grab")
		elif r == 5:
			_press(&"kick")
		elif r == 6:
			_press(&"jump")
		else:
			_press(&"punch")
