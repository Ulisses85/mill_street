class_name GorePiece
extends Sprite2D
## A cut-out part of a unit's sprite (a head, or the body without it) that flies, bounces and
## rests on the floor, bleeding, then fades. Made by Gore.piece(). Cosmetic only.

var floor_y := 0.0
var z := 0.0
var vel := Vector3.ZERO            # x along the street, y depth, z up
var spin := 0.0
## For bodies: fall over to this angle (radians) instead of flying.
var topple := 0.0
var bleed_from := Vector2.ZERO     # local point that spurts blood (the neck)
var bleed_ticks := 0
var life := 0
var rest_ticks := 300


static func spawn(u: Unit, cell_rect: Rect2, v: Vector3, spin_speed: float, topple_to: float) -> GorePiece:
	var b := u.body
	var g := GorePiece.new()
	g.texture = b.texture
	g.region_enabled = true
	g.region_rect = Rect2(b.region_rect.position + cell_rect.position, cell_rect.size)
	g.flip_h = b.flip_h
	g.scale = Vector2(b.res, b.res)
	g.texture_filter = b.texture_filter
	g.centered = true
	# where this part sits relative to the unit's feet (the anchor is at -b.offset in the cell)
	var anchor := -b.offset
	var centre := (cell_rect.position + cell_rect.size * 0.5 - anchor) * b.res
	if b.flip_h:
		centre.x = -centre.x
	g.floor_y = u.position.y
	g.z = -centre.y + u.z
	g.position = Vector2(u.position.x + centre.x, u.position.y - g.z)
	g.vel = v
	g.spin = spin_speed
	g.topple = topple_to
	if topple_to != 0.0:
		# pivot at the feet so the body falls over rather than spinning in place
		g.centered = false
		g.offset = Vector2(-cell_rect.size.x * 0.5, -cell_rect.size.y)
		g.position = Vector2(u.position.x + centre.x, u.position.y - u.z)
		g.z = u.z
		g.bleed_from = Vector2(0, -cell_rect.size.y * b.res)
	g.z_index = 0
	u.get_parent().add_child(g)
	return g


func _physics_process(_delta: float) -> void:
	if Game.hitstop > 0:
		return
	life += 1
	if topple != 0.0:
		rotation = move_toward(rotation, topple, 0.02 + absf(rotation) * 0.1)
		if is_equal_approx(rotation, topple) and life < 1000:
			life = 1000
			Gore.splat(position + Vector2(signf(topple) * 20, 0), 5.0)
			Gore.pool(position + Vector2(signf(topple) * 26, 2), 13.0)
	else:
		vel.z -= 0.3
		z += vel.z
		position.x += vel.x
		floor_y += vel.y
		rotation += spin
		if z <= 0.0:
			z = 0.0
			if absf(vel.z) > 1.2:
				Gore.splat(Vector2(position.x, floor_y), 3.0)
				vel.z = -vel.z * 0.4
				vel.x *= 0.6
				spin *= 0.6
			else:
				vel = Vector3.ZERO
				spin = 0.0
		position.y = floor_y - z - 4.0
	if bleed_ticks > 0:
		bleed_ticks -= 1
		var at := position + bleed_from.rotated(rotation)
		if life % 2 == 0:
			Gore.spray(Vector2(at.x, floor_y if topple == 0.0 else position.y), (floor_y if topple == 0.0 else position.y) - at.y, signf(topple) if topple != 0.0 else 0.0, 2, 0.9)
	rest_ticks -= 1
	if rest_ticks < 60:
		modulate.a = maxf(0.0, rest_ticks / 60.0)
	if rest_ticks <= 0:
		queue_free()
