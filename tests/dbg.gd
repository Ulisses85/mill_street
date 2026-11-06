extends Node
var level; var frame := 0
func _ready():
	level = load("res://scenes/levels/level_01.tscn").instantiate(); add_child(level)
	await get_tree().process_frame
	for e in get_tree().get_nodes_in_group(&"enemies"):
		e.state_changed.connect(func(s): if s in [&"windup", &"attack"]: print("[%d] %s %s dx=%d dy=%d pstate=%s" % [frame, e.display_name, s, Game.player.position.x - e.position.x, Game.player.position.y - e.position.y, Game.player.state]))
	Game.player.position = Vector2(560, 210)
func _physics_process(_d):
	frame += 1
	if frame == 400:
		var p = Game.player
		print("player hp ", p.health.current_hp, " state ", p.state)
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e.state != &"wait": print(e.display_name, " ", e.state, " cd=", e.cooldown, " pos=", e.position)
		get_tree().quit()
