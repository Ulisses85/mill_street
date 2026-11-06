@tool
class_name Breakable
extends Node2D
## A destructible object (wooden crate, drum barrel). Uses a HealthSystem child. Blocks movement,
## can be lifted with Grab and thrown, and spawns an item when destroyed.

@export var texture: Texture2D:
	set(v):
		texture = v
		_refresh()
@export var damaged_texture: Texture2D
## Debris colours.
@export var debris_colors: PackedColorArray = PackedColorArray([Color("#a8743e"), Color("#8a5a2e"), Color("#5e3b1c")])
@export var can_be_lifted := true
@export var half_width := 12.0

@export_group("Spawn On Destroy")
@export var spawn_weapon: WeaponData
@export var spawn_health_texture: Texture2D
@export var spawn_health_amount := 0

var _sprite: Sprite2D
var flash_t := 0
@onready var health: HealthSystem = get_node_or_null("HealthSystem")


func _ready() -> void:
	_refresh()
	if Engine.is_editor_hint():
		return
	add_to_group(&"breakables")
	if health:
		health.died.connect(func(src): destroy(src.position.x if src is Node2D else position.x))


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.centered = false
	if texture:
		_sprite.offset = Vector2(-texture.get_width() / 2.0, -texture.get_height() + 2)


func _physics_process(_d: float) -> void:
	if Engine.is_editor_hint() or health == null:
		return
	var jolt := health.tick()
	_sprite.position.x = round(jolt)
	_sprite.material = null
	_sprite.modulate = Color(3, 3, 3) if health.flashing() else Color.WHITE


func can_be_hit() -> bool:
	return health != null and not health.is_dead()


## Called by attacks. Returns true when the hit landed.
func receive_hit(attacker: Node2D, a: AttackData) -> bool:
	if not can_be_hit():
		return false
	var dir := signf(position.x - attacker.position.x)
	Effects.burst(get_parent(), position + Vector2(-dir * 6, -12), 6.0)
	Sfx.play(&"hit")
	Game.request_shake(2.0)
	health.damage(a.damage, attacker)
	if not health.is_dead() and damaged_texture and health.current_hp <= health.max_hp / 2:
		_sprite.texture = damaged_texture
	return true


func destroy(from_x: float, at := Vector2.INF, height := 12.0) -> void:
	var pos := position if at == Vector2.INF else at
	var parent := get_parent()
	Sfx.play(&"break")
	Game.request_shake(4.0)
	Game.add_score(50)
	Effects.burst(parent, pos + Vector2(0, -height), 12.0)
	for i in 9:
		var c: Color = debris_colors[i % debris_colors.size()]
		Effects.chunk(parent, pos + Vector2(randf_range(-8, 8), -height + randf_range(-6, 6)), c,
			Vector2(randf_range(-2.4, 2.4) + signf(pos.x - from_x) * 1.2, randf_range(-4.2, -1.6)),
			pos.y + randf_range(-4, 4), Vector2(randf_range(5, 13), randf_range(2, 5)))
	for i in 5:
		Effects.puff(parent, pos + Vector2(randf_range(-10, 10), -randf_range(0, 10)), randf_range(3, 6))
	if spawn_weapon:
		Pickup.spawn_weapon(parent, pos, spawn_weapon)
	elif spawn_health_texture and spawn_health_amount > 0:
		Pickup.spawn_health(parent, pos, spawn_health_texture, spawn_health_amount)
	queue_free()


## Units cannot walk through breakables.
static func push_out(u: Node2D, half: float) -> void:
	for b in u.get_tree().get_nodes_in_group(&"breakables"):
		var br := b as Breakable
		if br.is_queued_for_deletion() or absf(br.position.y - u.position.y) > 7.0:
			continue
		var dx := u.position.x - br.position.x
		var min_d := br.half_width + half
		if absf(dx) < min_d:
			u.position.x = br.position.x + (min_d if dx >= 0.0 else -min_d)
