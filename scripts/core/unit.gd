class_name Unit
extends Node2D
## Base for every fighter. A unit lives on a 2.5D floor: node position is the point on the
## floor under its feet (x = along the street, y = depth), and `z` is its height above it.
## The World node y-sorts units by their feet so nearer units draw in front.
##
## Children expected: Body (SpriteAnimator), Shadow (UnitShadow), HealthSystem.

signal state_changed(new_state: StringName)
signal knocked_down
signal defeated

enum Team { PLAYER, ENEMY }

@export var team := Team.ENEMY

@export_group("Name and Portrait")
@export var unit_name := "Unit"
@export var show_name_in_all_caps := true
## Pick a random name from this file (one per line) when the unit spawns.
@export_file("*.txt") var random_name_file := ""
@export var portrait: Texture2D

@export_group("Movement")
@export_enum("Left:-1", "Right:1") var start_direction := 1
## Pixels per second along the street. Depth movement uses `vertical_speed_factor` of this.
@export var move_speed := 126.0
@export var move_speed_air := 132.0
@export var use_acceleration := true
@export var move_acceleration := 1300.0
@export var move_deceleration := 1600.0
@export_range(0.0, 1.0, 0.05) var vertical_speed_factor := 0.8

@export_group("Jump")
@export var jump_height := 46.0
## Pixels per second squared. Higher gravity makes a snappier, lower jump unless jump_height is raised.
@export var gravity := 1150.0

@export_group("Hit Reaction")
@export_range(0.0, 2.0, 0.01, "suffix:s") var hit_stun_time := 0.28

@export_group("Knockdown")
@export var can_be_knocked_down := true
@export var knockdown_height := 18.0
@export var knockdown_distance := 54.0
## Time spent lying on the floor before getting up.
@export_range(0.0, 5.0, 0.05, "suffix:s") var knockdown_floor_time := 0.7
@export var knockdown_bounce := true
@export_range(0.0, 3.0, 0.05, "suffix:s") var getup_invulnerable_time := 0.6

@export_group("Throw")
## How high and how far this unit flies when it is thrown.
@export var throw_height := 33.0
@export var throw_distance := 112.0

@export_group("Defence")
## Blocks attacks from behind too.
@export var rear_defence_enabled := false
## If off, knockdown attacks break this unit's guard.
@export var defence_stops_knockdown_attacks := false

@export_group("Hurtbox")
## Half-width of the body for hit checks (pixels).
@export var body_half_width := 9.0
@export var body_height := 58.0

# --- runtime ---
var z := 0.0
var vz := 0.0
var vx := 0.0  ## horizontal velocity, px/s
var vy := 0.0  ## depth velocity, px/s
var face := 1
var state: StringName = &"idle"
var t := 0  ## ticks spent in the current state
var anim: StringName = &"idle"
var anim_t := 0
var bounced := false
var landed := true
var slide := 0.0
var thrown_by: Unit = null
var thrown_hits: Array = []
var invulnerable_ticks := 0
var squash := 0
var current_attack: AttackData = null
var hit_this_attack: Array = []
var display_name := ""

@onready var body: SpriteAnimator = $Body
@onready var shadow: Node2D = $Shadow
@onready var health: HealthSystem = $HealthSystem


func _ready() -> void:
	face = start_direction
	add_to_group(&"units")
	display_name = Game.random_line(random_name_file, unit_name)
	if show_name_in_all_caps:
		display_name = display_name.to_upper()
	health.died.connect(_on_died)


# ---------- per-tick ----------
func _physics_process(_delta: float) -> void:
	if Game.hitstop > 0:
		return
	t += 1
	anim_t += 1
	if invulnerable_ticks > 0:
		invulnerable_ticks -= 1
	if squash > 0:
		squash -= 1
	_tick()
	_clamp_to_floor()
	_update_visuals()


## Override in Player / Enemy.
func _tick() -> void:
	pass


func set_state(s: StringName, play: StringName = &"") -> void:
	state = s
	t = 0
	if play != &"":
		play_anim(play)
	state_changed.emit(s)


func play_anim(a: StringName, restart := true) -> void:
	if a != anim or restart:
		anim_t = 0
	anim = a


func _update_visuals() -> void:
	var jolt := health.tick()
	if state == &"hurt" and t < 5:
		jolt -= face * 2.0
	body.flip_h = face < 0
	body.position = Vector2(round(jolt), -round(z))
	var sq := squash * 0.035
	body.scale = Vector2(1.0 + sq, 1.0 - sq)
	body.set_flash(health.flashing())
	body.show_frame(anim, anim_t)
	shadow.scale = Vector2.ONE * (1.0 - minf(z, 60.0) / 120.0)
	if state == &"dead":
		visible = (t / 4) % 2 == 0


func _clamp_to_floor() -> void:
	var lvl := Level.current
	if lvl:
		position.y = clamp(position.y, lvl.walk_area.position.y, lvl.walk_area.end.y)
		position.x = clamp(position.x, lvl.walk_area.position.x + 8, lvl.walk_area.end.x - 8)


# ---------- movement helpers ----------
func ground_move(dir: Vector2, speed_scale := 1.0) -> void:
	var tx := dir.x * move_speed * speed_scale
	var ty := dir.y * move_speed * vertical_speed_factor * speed_scale
	if use_acceleration:
		var ax := (move_acceleration if abs(tx) > abs(vx) else move_deceleration) * Game.TICK
		vx = move_toward(vx, tx, ax)
	else:
		vx = tx
	vy = ty
	position += Vector2(vx, vy) * Game.TICK


func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_height)


## Integrates height. Returns true on the tick the unit touches the floor.
func air_step() -> bool:
	vz -= gravity * Game.TICK
	z += vz * Game.TICK
	if z <= 0.0 and vz < 0.0:
		z = 0.0
		return true
	return false


# ---------- combat: dealing hits ----------
func begin_attack(a: AttackData) -> void:
	current_attack = a
	hit_this_attack.clear()
	set_state(&"attack", a.animation)


## Checks the current attack's hit window against every opposing unit. Returns how many connected.
func process_attack_hits(a: AttackData, from_t: int = -1) -> int:
	var tt := t if from_t < 0 else from_t
	if not a.is_active(tt):
		return 0
	var n := 0
	for u in get_tree().get_nodes_in_group(&"units"):
		var target := u as Unit
		if target == self or target.team == team or target in hit_this_attack:
			continue
		if not target.can_be_hit() or not overlaps(a, target):
			continue
		hit_this_attack.append(target)
		if target.receive_hit(self, a):
			n += 1
	return n


func overlaps(a: AttackData, target: Unit) -> bool:
	if abs(target.position.y - position.y) > a.depth_range:
		return false
	if abs(target.z - z) > a.height_range:
		return false
	var dx := (target.position.x - position.x)
	if a.hits_both_sides:
		return abs(dx) <= a.reach_to + target.body_half_width
	dx *= face
	return dx >= a.reach_from - target.body_half_width and dx <= a.reach_to + target.body_half_width


# ---------- combat: taking hits ----------
func can_be_hit() -> bool:
	return invulnerable_ticks <= 0 and not health.invulnerable and not (state in [&"down", &"getup", &"dead", &"knockdown"])


func is_defending() -> bool:
	return state == &"defend"


## Returns true if the hit connected (false if blocked or ignored).
func receive_hit(attacker: Node2D, a: AttackData) -> bool:
	var dir := signf(position.x - attacker.position.x)
	if dir == 0.0:
		dir = float(attacker.get("face") if attacker.get("face") != null else 1)
	var from_front := signf(attacker.position.x - position.x) == float(face) or attacker.position.x == position.x
	if is_defending() and (from_front or rear_defence_enabled):
		if not a.knockdown or defence_stops_knockdown_attacks:
			_on_blocked(attacker, a, dir)
			return false
		guard_broken()
	health.damage(a.damage, attacker)
	_hit_feedback(a, dir)
	if health.is_dead() or (a.knockdown and can_be_knocked_down) or state == &"jump":
		knockdown(dir, a.knockdown_force)
	else:
		hurt(dir, a.knockback)
	_on_hit(attacker, a)
	return true


func _hit_feedback(a: AttackData, dir: float) -> void:
	Game.request_hitstop(a.hitstop_frames + (3 if a.knockdown else 0))
	Game.request_shake(a.screen_shake)
	Effects.burst(get_parent(), position + Vector2(-dir * 4, -z - body_height * 0.55), 13.0 if a.knockdown else 8.0)


func _on_blocked(_attacker: Node2D, a: AttackData, dir: float) -> void:
	position.x += dir * (5.0 if a.knockdown else 2.5)
	Game.request_hitstop(2)
	Effects.shield(get_parent(), position + Vector2(-dir * 10, -z - body_height * 0.5), -dir)


func _on_hit(_attacker: Node2D, _a: AttackData) -> void:
	pass


func guard_broken() -> void:
	Effects.float_text(get_parent(), position + Vector2(0, -body_height - 8), "GUARD BREAK", Color("#ffd23a"))


func hurt(dir: float, push: float) -> void:
	position.x += dir * push * 2.0
	face = -int(dir)
	squash = 4
	set_state(&"hurt", &"hurt")


func knockdown(dir: float, force := 1.0) -> void:
	face = -int(dir)
	var v := sqrt(2.0 * gravity * knockdown_height)
	vz = v
	var air := 2.0 * v / gravity
	vx = dir * knockdown_distance * force / maxf(air, 0.1) * 0.7
	z = maxf(z, 0.1)
	bounced = not knockdown_bounce
	landed = false
	slide = 0.0
	set_state(&"knockdown", &"knockdown")
	knocked_down.emit()


func thrown(by: Unit, dir: float) -> void:
	face = int(dir)
	var v := sqrt(2.0 * gravity * throw_height)
	vz = v
	vx = dir * throw_distance / (2.0 * v / gravity)
	z = 2.0
	bounced = false
	landed = false
	thrown_by = by
	thrown_hits.clear()
	set_state(&"knockdown", &"knockdown")


## Knockdown flight, bounce, slide and floor time. Returns true when the unit should get up.
func knockdown_step() -> bool:
	if not landed:
		position.x += vx * Game.TICK
		if thrown_by:
			_thrown_collisions()
		if air_step():
			Effects.dust(get_parent(), position)
			Game.request_shake(6.0 if thrown_by else 3.0)
			if not bounced:
				bounced = true
				vz = sqrt(2.0 * gravity * knockdown_height) * 0.38
				vx *= 0.55
				squash = 6
			else:
				landed = true
				slide = vx * 1.1 * Game.TICK
				vx = 0.0
				squash = 4
				thrown_by = null
				t = 0
				play_anim(&"down")
		return false
	if absf(slide) > 0.1:
		position.x += slide
		slide *= 0.86
		if Engine.get_physics_frames() % 4 == 0:
			Effects.puff(get_parent(), position + Vector2(-signf(slide) * 8, 0), 3.0 + absf(slide))
	if health.is_dead():
		if t > 24:
			set_state(&"dead")
			defeated.emit()
		return false
	return t > int(knockdown_floor_time * 60.0)


func _thrown_collisions() -> void:
	for u in get_tree().get_nodes_in_group(&"units"):
		var o := u as Unit
		if o == self or o == thrown_by or o.team == thrown_by.team or o in thrown_hits or not o.can_be_hit():
			continue
		if abs(o.position.x - position.x) < 16 and abs(o.position.y - position.y) < 10:
			thrown_hits.append(o)
			o.receive_hit(self, thrown_by.thrown_body_attack() if thrown_by.has_method("thrown_body_attack") else _default_body_hit())


func _default_body_hit() -> AttackData:
	var a := AttackData.new()
	a.damage = 10
	a.knockdown = true
	return a


func start_getup() -> void:
	invulnerable_ticks = int(getup_invulnerable_time * 60.0)
	set_state(&"getup", &"getup")


func _on_died(_source: Node) -> void:
	pass


func is_alive() -> bool:
	return not health.is_dead()
