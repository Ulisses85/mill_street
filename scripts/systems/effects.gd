class_name Effects
extends Node2D
## Small one-shot visual effects drawn in code: hit bursts, block shields, dust puffs,
## debris chunks and floating text. Use the static helpers, e.g. Effects.burst(world, pos, 10).

enum Kind { BURST, SHIELD, PUFF, TEXT, CHUNK }

const INK := Color("#1e1c28")
const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")

var kind := Kind.BURST
var life := 7
var max_life := 7
var radius := 8.0
var dir := 1.0
var vel := Vector2.ZERO
var gravity := 0.0
var text := ""
var color := Color.WHITE
var rot := 0.0
var spin := 0.0
var floor_y := 0.0
var size := Vector2(6, 3)


static func _spawn(parent: Node, pos: Vector2, k: Kind, lifetime: int) -> Effects:
	var e := Effects.new()
	e.kind = k
	e.life = lifetime
	e.max_life = lifetime
	e.position = pos
	e.z_index = 20
	e.z_as_relative = false
	if parent:
		parent.add_child(e)
	return e


static func burst(parent: Node, pos: Vector2, r: float) -> void:
	var e := _spawn(parent, pos, Kind.BURST, 7)
	e.radius = r
	e.rot = randf() * TAU


static func shield(parent: Node, pos: Vector2, facing: float) -> void:
	var e := _spawn(parent, pos, Kind.SHIELD, 9)
	e.radius = 11.0
	e.dir = facing


static func puff(parent: Node, pos: Vector2, r: float) -> void:
	var e := _spawn(parent, pos, Kind.PUFF, 18)
	e.radius = r
	e.vel = Vector2(randf_range(-0.3, 0.3), -0.25)
	e.z_index = 1


static func dust(parent: Node, pos: Vector2) -> void:
	for i in 5:
		puff(parent, pos + Vector2(randf_range(-10, 10), randf_range(-2, 2)), randf_range(3, 5))


static func float_text(parent: Node, pos: Vector2, s: String, c: Color) -> void:
	var e := _spawn(parent, pos, Kind.TEXT, 50)
	e.text = s
	e.color = c
	e.vel = Vector2(0, -0.5)


static func chunk(parent: Node, pos: Vector2, c: Color, v: Vector2, floor_at: float, sz: Vector2) -> void:
	var e := _spawn(parent, pos, Kind.CHUNK, 70)
	e.color = c
	e.vel = v
	e.gravity = 0.26
	e.floor_y = floor_at
	e.size = sz
	e.rot = randf() * TAU
	e.spin = randf_range(-0.3, 0.3)


func _physics_process(_delta: float) -> void:
	if Game.hitstop > 0 and kind != Kind.BURST:
		return
	life -= 1
	if life <= 0:
		queue_free()
		return
	vel.y += gravity
	position += vel
	if kind == Kind.CHUNK:
		rot += spin
		if position.y > floor_y:
			position.y = floor_y
			vel.y *= -0.35
			vel.x *= 0.6
			spin *= 0.5
			if absf(vel.y) < 0.4:
				vel.y = 0.0
				gravity = 0.0
				vel.x *= 0.8
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.BURST:
			var k := 1.0 + (max_life - life) * 0.12
			var r := radius * k
			if life > 1:
				_star(r + 3.0, INK)
				_star(r, Color.WHITE)
			draw_arc(Vector2.ZERO, r * 0.95 + 4.0, 0, TAU, 24, INK, 3.0)
			draw_arc(Vector2.ZERO, r * 0.95 + 4.0, 0, TAU, 24, Color.WHITE, 1.5)
		Kind.SHIELD:
			var a0 := -1.1 if dir > 0 else PI - 1.1
			draw_arc(Vector2.ZERO, radius, a0, a0 + 2.2, 12, INK, 4.0)
			draw_arc(Vector2.ZERO, radius, a0, a0 + 2.2, 12, Color.WHITE if life > 5 else Color("#bfe4ff"), 2.0)
		Kind.PUFF:
			var f := float(life) / max_life
			var r := radius * (1.6 - f * 0.6) * minf(1.0, f * 2.2)
			draw_circle(Vector2(0, 1), r + 1.0, Color("#8f8ea0"))
			draw_circle(Vector2.ZERO, r, Color.WHITE)
		Kind.TEXT:
			var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			draw_string(FONT, Vector2(-w / 2 + 1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
			draw_string(FONT, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
		Kind.CHUNK:
			draw_set_transform(Vector2.ZERO, rot)
			draw_rect(Rect2(-size / 2 - Vector2.ONE, size + Vector2(2, 2)), INK)
			draw_rect(Rect2(-size / 2, size), color)
			draw_set_transform(Vector2.ZERO, 0)


func _star(r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := i / 16.0 * TAU + rot
		var rr := r * 0.42 if i % 2 == 1 else (r * 0.8 if i % 4 != 0 else r * 1.15)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, c)
