class_name Gore
extends Node2D
## Blood: drops that fly and land, splats and pools that stay on the floor, and body pieces for
## finishers. One Gore node per level draws the floor stains (under the fighters); its child draws
## the drops in the air (over them). All cosmetic: uses Game.fx_rng and never affects gameplay.
## Turned off by Options > Gore (Game.settings.gore).

const DARK := Color("#7a0c12")
const MID := Color("#b5121b")
const LIGHT := Color("#e23a3f")
const MAX_STAINS := 700
const GRAVITY := 0.32

static var current: Gore

## Flying drops: [x, floor_y, z, vx, vy, vz, size]
var drops: Array = []
## Floor stains: [x, y, w, h, shade]. Pools: [x, y, radius_now, radius_goal]
var stains: Array = []
var pools: Array = []
var air: Node2D


static func on() -> bool:
	return current != null and is_instance_valid(current) and bool(Game.settings.get("gore", true))


## Called by Level: the stain layer goes under the World node, the drop layer over it.
static func setup(level: Node) -> void:
	var world := level.get_node_or_null("World")
	if world == null:
		return
	var g := Gore.new()
	g.name = "Gore"
	level.add_child(g)
	level.move_child(g, world.get_index())
	g.air = Node2D.new()
	g.air.name = "GoreAir"
	g.air.z_index = 20
	g.air.draw.connect(g._draw_air)
	level.add_child(g.air)
	level.move_child(g.air, world.get_index() + 1)
	current = g


## Blood flying out of a hit. `pos` is the floor point under it, `height` how far up it starts.
static func spray(pos: Vector2, height: float, dir: float, amount: int, power := 1.0) -> void:
	if not on():
		return
	var r := Game.fx_rng
	for i in amount:
		current.drops.append([pos.x + r.randf_range(-2, 2), pos.y + r.randf_range(-3, 3), height + r.randf_range(-4, 4),
			dir * r.randf_range(0.4, 2.6) * power + r.randf_range(-0.5, 0.5), r.randf_range(-0.25, 0.25),
			r.randf_range(0.6, 3.4) * power, 1 if r.randf() < 0.7 else 2])


## A splat on the floor right now (landings, stomps).
static func splat(pos: Vector2, size: float) -> void:
	if not on():
		return
	var r := Game.fx_rng
	for i in int(size):
		var a := r.randf() * TAU
		var d := r.randf() * size
		current._stain(pos.x + cos(a) * d * 1.6, pos.y + sin(a) * d * 0.5, r.randi_range(1, 3), 1)
	current._stain(pos.x - size * 0.6, pos.y - 1, int(size * 1.2), 2)


## A pool that spreads under a body.
static func pool(pos: Vector2, radius: float) -> void:
	if on():
		current.pools.append([pos.x, pos.y, 1.0, radius])


## A head (or any part of a unit's current frame) flying off. Returns the piece, or null with gore off.
static func piece(u: Unit, cell_rect: Rect2, vel: Vector3, spin: float, topple := 0.0) -> GorePiece:
	if not on() or u.body == null or u.body.texture == null:
		return null
	return GorePiece.spawn(u, cell_rect, vel, spin, topple)


func _stain(x: float, y: float, w: int, h: int) -> void:
	stains.append([roundf(x), roundf(y), w, h, Game.fx_rng.randi_range(0, 2)])
	if stains.size() > MAX_STAINS:
		stains = stains.slice(stains.size() - MAX_STAINS)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if Game.hitstop > 0:
		return
	if not drops.is_empty():
		var keep: Array = []
		for d in drops:
			d[5] -= GRAVITY
			d[0] += d[3]
			d[1] += d[4]
			d[2] += d[5]
			if d[2] <= 0.0:
				_stain(d[0], d[1], int(d[6]) + (1 if Game.fx_rng.randf() < 0.3 else 0), int(d[6]))
			else:
				keep.append(d)
		drops = keep
		air.queue_redraw()
	if not pools.is_empty():
		var growing := false
		for p in pools:
			if p[2] < p[3]:
				p[2] = minf(p[3], p[2] + 0.12)
				growing = true
		if growing:
			queue_redraw()
		if pools.size() > 40:
			pools = pools.slice(pools.size() - 40)


func _draw() -> void:
	for p in pools:
		var r: float = p[2]
		draw_set_transform(Vector2(p[0], p[1]), 0.0, Vector2(1.0, 0.36))
		draw_circle(Vector2.ZERO, r + 1.0, DARK)
		draw_circle(Vector2.ZERO, r, MID)
		draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.25, LIGHT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for s in stains:
		draw_rect(Rect2(s[0], s[1], s[2], s[3]), [DARK, MID, MID][s[4]])


func _draw_air() -> void:
	for d in drops:
		air.draw_rect(Rect2(roundf(d[0]), roundf(d[1] - d[2]), d[6], d[6]), LIGHT if d[5] > 0.0 else MID)


func _exit_tree() -> void:
	if current == self:
		current = null
