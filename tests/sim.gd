extends Node
## Headless smoke test: plays level 1 with scripted input and prints what happened.
## Run: godot --headless --path . res://tests/sim.tscn

var level: Node
var frame := 0
var log_lines: Array[String] = []
var script_steps := []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var lv := args[0] if args.size() > 0 else "level_01"
	Game.current_level = int(lv.right(1)) - 1
	level = load("res://scenes/levels/%s.tscn" % lv).instantiate()
	add_child(level)
	var wm = level.get_node("World/WaveManager")
	wm.wave_started.connect(func(i): _log("wave started %d" % i))
	wm.wave_cleared.connect(func(i): _log("wave cleared %d" % i))
	Game.level_finished.connect(func(): _log("LEVEL FINISHED"); get_tree().quit())
	Game.player_died.connect(func(): _log("PLAYER DIED"); get_tree().quit())
	Game.player_spawned.connect(func(pl): pl.health.damaged.connect(func(a, src): _log("PLAYER HIT -%d by %s" % [a, src.display_name if src and src.get("display_name") else "?"])))
	await get_tree().process_frame
	Game.player.health.damaged.connect(func(a, src): _log("player hit -%d" % a))

func _log(s: String) -> void:
	print("[%05d] %s" % [frame, s])

func _press(a: StringName) -> void:
	Input.action_press(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(a)

var shot_frames := []

func _physics_process(_d: float) -> void:
	frame += 1
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and frame in shot_frames_for(args):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/sim_%s_%05d.png" % [args[0], frame])
	var p = Game.player
	if p == null:
		return
	# simple bot: walk right until an enemy is near, then fight
	var nearest = null
	var best := 1e9
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e.is_alive() and e.state != &"wait":
			var d: float = abs(e.position.x - p.position.x) + abs(e.position.y - p.position.y) * 2.0
			if d < best:
				best = d; nearest = e
	Input.action_release(&"move_left"); Input.action_release(&"move_right")
	Input.action_release(&"move_up"); Input.action_release(&"move_down")
	if nearest:
		var dx: float = nearest.position.x - p.position.x
		var dy: float = nearest.position.y - p.position.y
		if abs(dy) > 4: Input.action_press(&"move_down" if dy > 0 else &"move_up")
		if abs(dx) > 26: Input.action_press(&"move_right" if dx > 0 else &"move_left")
		elif abs(dy) <= 6 and frame % 9 == 0:
			if p.face != sign(dx): Input.action_press(&"move_right" if dx > 0 else &"move_left")
			var r := frame / 9 % 7
			if r == 3: _press(&"grab")
			elif r == 5: _press(&"kick")
			elif r == 6: _press(&"jump")
			else: _press(&"punch")
	else:
		Input.action_press(&"move_right")
	if frame % 120 == 0:
		_log("p x=%d y=%d hp=%d state=%s lives=%d | enemies alive=%d | cam bound=%s | wave=%d" % [p.position.x, p.position.y, p.health.current_hp, p.state, p.lives, get_tree().get_nodes_in_group(&"enemies").size(), str(level.get_node("BeatCamera").level_bound), level.get_node("World/WaveManager").current])
	if frame > 60 * 150:
		_log("timeout")
		for e in get_tree().get_nodes_in_group(&"enemies"):
			_log("  left: %s %s state=%s pos=%s hp=%d alert=%d" % [e.name, e.display_name, e.state, e.position, e.health.current_hp, e.alert_t])
		get_tree().quit()


func shot_frames_for(args: PackedStringArray) -> Array:
	var out := []
	for a in args[1].split(","):
		out.append(int(a))
	return out
