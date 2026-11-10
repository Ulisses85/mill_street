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

@export_group("Weapons")
## Swing held weapons from the attack timing (raise, whip through, follow through) instead of
## the sheet's per-frame weapon angles. Turn off for art that already animates the swing.
@export var procedural_weapon_swing := true
@export var lose_weapon_when_hit := false
@export var lose_weapon_when_knocked_down := true

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
## Playback speed of the current animation (1.0 = as authored). Walk/run cycles follow movement speed.
var anim_rate := 1.0
var _anim_acc := 0.0
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
var held_weapon: WeaponData = null
var weapon_uses := 0
var carrying: Breakable = null
var _weapon_sprite: Sprite2D
var _carry_sprite: Sprite2D
var _small_bar: Node2D

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
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.centered = false
	_weapon_sprite.visible = false
	add_child(_weapon_sprite)
	_carry_sprite = Sprite2D.new()
	_carry_sprite.centered = false
	_carry_sprite.visible = false
	add_child(_carry_sprite)
	if health.show_small_health_bar:
		_small_bar = preload("res://scripts/ui/small_health_bar.gd").new()
		_small_bar.health = health
		_small_bar.position = health.bar_offset
		add_child(_small_bar)


# ---------- per-tick ----------
func _physics_process(_delta: float) -> void:
	if Game.hitstop > 0:
		return
	t += 1
	_anim_acc += anim_rate
	while _anim_acc >= 1.0:
		_anim_acc -= 1.0
		anim_t += 1
	if invulnerable_ticks > 0:
		invulnerable_ticks -= 1
	if squash > 0:
		squash -= 1
	_tick()
	_attack_smear()
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
		_anim_acc = 0.0
		anim_rate = 1.0
	anim = a


## A white motion arc in front of the unit on the first active tick of each attack.
func _attack_smear() -> void:
	if state != &"attack" or current_attack == null or z > 1.0 and current_attack.duration > 5.0:
		return
	var a := current_attack
	if t != a.ticks(a.active_from) or a.reach_to <= 0.0:
		return
	var armed := held_weapon != null and a == held_weapon.attack
	var hand := body.hand_at(anim, anim_t)
	var c := position + Vector2(face * 4, hand.y * 0.6 - z)
	var r := clampf(a.reach_to * 0.7, 14.0, 34.0) + (6.0 if armed else 0.0)
	if armed:
		Effects.swoosh(get_parent(), c, face, r, -100.0, 40.0, 4.0)
	elif a.knockdown:
		Effects.swoosh(get_parent(), c, face, r, -60.0, 30.0, 3.0)
	else:
		Effects.swoosh(get_parent(), c + Vector2(0, -2), face, r * 0.8, -25.0, 15.0, 2.0)


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
	_update_held(jolt)
	shadow.scale = Vector2.ONE * (1.0 - minf(z, 60.0) / 120.0)
	if state == &"dead":
		visible = (t / 4) % 2 == 0


func _update_held(jolt: float) -> void:
	var tossed := state == &"attack" and current_attack and held_weapon and held_weapon.thrown and t >= current_attack.ticks(current_attack.active_from)
	_weapon_sprite.visible = held_weapon != null and not (state in [&"knockdown", &"dead", &"grabbed"]) and not tossed
	if _weapon_sprite.visible:
		var hand := body.hand_at(anim, anim_t) * Vector2(body.scale.x, body.scale.y)
		var ang := body.weapon_angle_at(anim, anim_t)
		var a := current_attack
		if procedural_weapon_swing and state == &"attack" and a and a == held_weapon.attack and not held_weapon.thrown:
			var sw := _swing_pose(a)
			ang = sw.x
			hand += Vector2(sw.y, sw.z)
		if held_weapon.thrown and not (state == &"attack" and current_attack == held_weapon.throw_attack):
			ang = -0.25
		_weapon_sprite.texture = held_weapon.texture
		_weapon_sprite.offset = -held_weapon.grip
		_weapon_sprite.position = Vector2(hand.x * face + round(jolt), hand.y - round(z))
		_weapon_sprite.rotation = ang if face > 0 else PI - ang
		_weapon_sprite.flip_v = face < 0
		_weapon_sprite.z_index = 1
	_carry_sprite.visible = carrying != null
	if carrying:
		var tex := carrying.texture
		_carry_sprite.texture = tex
		_carry_sprite.position = Vector2(-tex.get_width() / 2.0, -round(z) - body_height - tex.get_height() + 8 + (1 if anim == &"carry" and (anim_t / 6) % 2 == 0 else 0))
		_carry_sprite.z_index = 1


## Weapon swing driven by the attack's timing, so any sprite swings a held weapon convincingly:
## raise it back during the wind-up, whip it through during the hit window, follow through after.
## Returns (angle, hand dx, hand dy).
func _swing_pose(a: AttackData) -> Vector3:
	var t0 := float(a.ticks(a.active_from))
	var t1 := maxf(t0 + 1.0, float(a.ticks(a.active_to)))
	var tt := float(t)
	if tt < t0:
		var k := ease(tt / maxf(t0, 1.0), 0.5)
		return Vector3(lerpf(-1.2, -2.7, k), lerpf(0.0, -5.0, k), lerpf(0.0, -8.0, k))
	if tt <= t1:
		var k := ease((tt - t0) / (t1 - t0), 0.4)
		return Vector3(lerpf(-2.7, 0.7, k), lerpf(-5.0, 6.0, k), lerpf(-8.0, 2.0, k))
	var k := clampf((tt - t1) / 10.0, 0.0, 1.0)
	return Vector3(lerpf(0.7, 0.2, k), lerpf(6.0, 3.0, k), lerpf(2.0, 0.0, k))


func _clamp_to_floor() -> void:
	if team == Team.PLAYER and not (state in [&"knockdown", &"dead"]):
		Breakable.push_out(self, body_half_width)
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
	if team == Team.PLAYER:
		for b in get_tree().get_nodes_in_group(&"breakables"):
			var br := b as Breakable
			if br in hit_this_attack or not br.can_be_hit() or absf(br.position.y - position.y) > a.depth_range or z > 40.0:
				continue
			var dx := (br.position.x - position.x) * (signf(br.position.x - position.x) if a.hits_both_sides else float(face))
			if dx < -4.0 or dx > a.reach_to + br.half_width:
				continue
			hit_this_attack.append(br)
			br.receive_hit(self, a)
	if n > 0 and held_weapon and not held_weapon.thrown and (a == held_weapon.attack or a == held_weapon.enemy_attack):
		use_weapon()
	return n


# ---------- weapons ----------
func equip(w: WeaponData, uses: int) -> void:
	held_weapon = w
	weapon_uses = uses
	Effects.float_text(get_parent(), position + Vector2(0, -body_height - 6), w.weapon_name + ("!" if team == Team.ENEMY else ""), Color("#c5ccd3") if team == Team.PLAYER else Color("#ff3a2a"))
	Sfx.play(&"pickup" if team == Team.PLAYER else &"alert")


func use_weapon() -> void:
	weapon_uses -= 1
	if weapon_uses <= 0:
		Effects.float_text(get_parent(), position + Vector2(0, -body_height - 6), held_weapon.weapon_name + " BROKE", Color("#c5ccd3"))
		held_weapon = null


func drop_weapon() -> void:
	if held_weapon == null:
		return
	Pickup.spawn_weapon(get_parent(), position, held_weapon, weapon_uses)
	held_weapon = null


func drop_carried() -> void:
	if carrying == null:
		return
	var b := carrying
	carrying = null
	b.position = position + Vector2(face * 14, 0)
	b.visible = true
	b.add_to_group(&"breakables")
	b.process_mode = Node.PROCESS_MODE_INHERIT


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
	if team == Team.PLAYER and Game.god_mode:
		return false
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
	# Heavier hits freeze longer, shake harder and throw out more sparks.
	Game.request_hitstop(a.hitstop_frames + mini(3, a.damage / 5) + (3 if a.knockdown else 0))
	Game.request_shake(a.screen_shake + (1.5 if a.knockdown else 0.0))
	Effects.impact(get_parent(), position + Vector2(-dir * 4, -z - body_height * 0.55), dir, float(a.damage), a.knockdown)
	if a.knockdown:
		Effects.puff(get_parent(), position + Vector2(-dir * 6, 0), 4.0)


func _on_blocked(_attacker: Node2D, a: AttackData, dir: float) -> void:
	position.x += dir * (5.0 if a.knockdown else 2.5)
	Game.request_hitstop(2)
	Effects.shield(get_parent(), position + Vector2(-dir * 10, -z - body_height * 0.5), -dir)


func _on_hit(_attacker: Node2D, _a: AttackData) -> void:
	pass


func guard_broken() -> void:
	Effects.float_text(get_parent(), position + Vector2(0, -body_height - 8), "GUARD BREAK", Color("#ffd23a"))


func hurt(dir: float, push: float) -> void:
	drop_carried()
	if lose_weapon_when_hit:
		drop_weapon()
	position.x += dir * push * 2.0
	face = -int(dir)
	squash = 4
	set_state(&"hurt", &"hurt")


func knockdown(dir: float, force := 1.0) -> void:
	drop_carried()
	if lose_weapon_when_knocked_down or lose_weapon_when_hit:
		drop_weapon()
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
	drop_weapon()
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
