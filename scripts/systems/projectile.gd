class_name Projectile
extends Node2D
## Something flying along the street: a thrown knife (flat, fast) or a lifted crate (arcs, spins,
## smashes on impact). Hits the first opposing unit in its lane.

var team := Unit.Team.PLAYER
var attack: AttackData
var vx := 0.0
var z := 30.0
var vz := 0.0
var gravity := 0.0
var spin := 0.0
var life := 120
var source: Node2D = null
## A Breakable being thrown: it is destroyed when the projectile ends.
var carried: Breakable = null
var _sprite: Sprite2D
var _shadow: Node2D


static func launch(parent: Node, pos: Vector2, tex: Texture2D, offset: Vector2, team_: int, a: AttackData, speed: float, height: float) -> Projectile:
	var p := Projectile.new()
	p.position = pos
	p.team = team_
	p.attack = a
	p.vx = speed
	p.z = height
	p._sprite = Sprite2D.new()
	p._sprite.texture = tex
	p._sprite.centered = false
	p._sprite.offset = offset
	p._sprite.flip_h = speed < 0
	p.add_child(p._sprite)
	parent.add_child(p)
	return p


func _ready() -> void:
	_shadow = preload("res://scripts/core/unit_shadow.gd").new()
	_shadow.radius = Vector2(9, 2.5)
	add_child(_shadow)
	move_child(_shadow, 0)


func _physics_process(_d: float) -> void:
	if Game.hitstop > 0:
		return
	life -= 1
	position.x += vx * Game.TICK
	if gravity > 0.0:
		vz -= gravity * Game.TICK
		z += vz * Game.TICK
	_sprite.position.y = -z
	_sprite.rotation += spin
	if Engine.get_physics_frames() % 2 == 0 and gravity == 0.0:
		Effects.puff(get_parent(), position + Vector2(-signf(vx) * 10, -z), 1.5)
	for u in get_tree().get_nodes_in_group(&"units"):
		var t := u as Unit
		if t.team == team or not t.can_be_hit() or absf(t.position.y - position.y) > 10.0 or absf(t.position.x - position.x) > (16.0 if carried else 12.0):
			continue
		if absf(t.z - (z - 20.0)) > 40.0:
			continue
		t.receive_hit(self, attack)
		_end()
		return
	if not carried:
		for b in get_tree().get_nodes_in_group(&"breakables"):
			var br := b as Breakable
			if br.can_be_hit() and absf(br.position.y - position.y) < 10.0 and absf(br.position.x - position.x) < 10.0:
				br.receive_hit(self, attack)
				_end()
				return
	var cam := get_viewport().get_camera_2d()
	var off := cam and absf(position.x - cam.get_screen_center_position().x) > 300.0
	if life <= 0 or (gravity > 0.0 and z <= 0.0) or off:
		_end()


func _end() -> void:
	if carried and is_instance_valid(carried):
		carried.destroy(position.x - vx, position, max(z, 4.0))
	queue_free()


## Read by Unit.receive_hit for knockback direction.
var face: int:
	get:
		return 1 if vx >= 0.0 else -1
