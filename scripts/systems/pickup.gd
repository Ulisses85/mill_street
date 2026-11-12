@tool
class_name Pickup
extends Node2D
## An item on the floor. Health items are collected by walking over them; weapons are picked
## up by pressing Punch while standing on them (enemies that can use weapons walk over to them).

enum Kind { HEALTH, WEAPON }

@export var kind := Kind.HEALTH:
	set(v):
		kind = v
		_refresh()
@export var heal_amount := 35
@export var weapon: WeaponData:
	set(v):
		weapon = v
		_refresh()
@export var texture: Texture2D:
	set(v):
		texture = v
		_refresh()
## -1 = the weapon's full uses. Set when a weapon is dropped part-used.
@export var uses_left := -1
@export var pickup_range := Vector2(16, 10)

var t := 0
var claimed_by: Node = null
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group(&"pickups")
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	var tex := texture
	if kind == Kind.WEAPON and weapon and weapon.texture:
		tex = weapon.texture
	_sprite.texture = tex
	if tex:
		_sprite.centered = false
		_sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 2)
	queue_redraw()


func _physics_process(_d: float) -> void:
	if Engine.is_editor_hint():
		return
	t += 1
	if kind == Kind.HEALTH and _sprite:
		_sprite.position.y = round(sin(t * 0.12) * 1.5)
	var p := Game.player as Unit
	if p == null or not p.is_alive():
		return
	var near := in_reach(p)
	if kind == Kind.HEALTH and near and p.state in [&"idle", &"walk"] and p.z < 4.0:
		p.health.heal(heal_amount)
		Effects.float_text(get_parent(), position + Vector2(0, -20), "+%d HP" % heal_amount, Color("#7fe0a8"))
		Sfx.play(&"pickup")
		Game.add_score(100)
		queue_free()
	queue_redraw()


func in_reach(u: Node2D) -> bool:
	return absf(u.position.x - position.x) < pickup_range.x and absf(u.position.y - position.y) < pickup_range.y


func weapon_uses(for_enemy := false) -> int:
	if uses_left >= 0:
		return uses_left
	return weapon.enemy_uses if for_enemy else weapon.uses


func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	var pts := PackedVector2Array()
	for i in 16:
		var a := i / 16.0 * TAU
		pts.append(Vector2(cos(a) * 9, sin(a) * 2.5))
	draw_colored_polygon(pts, Color(0.12, 0.11, 0.17, 0.3))
	if Engine.is_editor_hint() or kind != Kind.WEAPON:
		return
	var p := Game.player as Unit
	if p and p.get("held_weapon") == null and in_reach(p) and (t / 16) % 2 == 0:
		var s := "PUNCH: PICK UP"
		var f := Effects.font()
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(f, Vector2(-w / 2 + 1, -13), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Effects.INK)
		draw_string(f, Vector2(-w / 2, -14), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#ffd23a"))


## Spawns a pickup into `parent` at `pos`.
static func spawn_weapon(parent: Node, pos: Vector2, w: WeaponData, uses := -1) -> Pickup:
	var p := Pickup.new()
	p.kind = Kind.WEAPON
	p.weapon = w
	p.uses_left = uses
	p.position = pos
	parent.add_child(p)
	return p


static func spawn_health(parent: Node, pos: Vector2, tex: Texture2D, amount: int) -> Pickup:
	var p := Pickup.new()
	p.kind = Kind.HEALTH
	p.texture = tex
	p.heal_amount = amount
	p.position = pos
	parent.add_child(p)
	return p
