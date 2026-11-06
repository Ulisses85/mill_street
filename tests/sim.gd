extends Node
## Headless smoke test: plays level 1 with scripted input and prints what happened.
## Run: godot --headless --path . res://tests/sim.tscn

var level: Node
var frame := 0
var log_lines: Array[String] = []
var script_steps := []

func _ready() -> void:
	level = load("res://scenes/levels/level_01.tscn").instantiate()
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

func _physics_process(_d: float) -> void:
	frame += 1
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
	if frame > 60 * 120:
		_log("timeout"); get_tree().quit()
