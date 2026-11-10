class_name Player
extends Unit
## Player-controlled fighter: move, run, jump with air attacks, attack combos with directional
## finishers, specials and supers on a power meter, dodge (or block), taunt, grab (knee / throw),
## hurt, knockdown, get up, lives.
##
## Two control styles, chosen by what is set in the Inspector:
## - Brawler (Shredder's Revenge style): Attack = punch_combo, Special = special_attack (costs power),
##   Special + Jump = super_attack (full power), Defend = dodge.
## - Classic: leave special_attack empty and Kick plays kick_combo; set defence_mode to Block.

@export_group("Run")
## Double-tap left or right to run.
@export var can_run := true
@export_range(1.0, 3.0, 0.05) var run_speed_scale := 1.6
@export_range(0.1, 0.5, 0.01, "suffix:s") var double_tap_window := 0.25

@export_group("Combat")
## The Attack button's combo (punch action).
@export var punch_combo: ComboData
## Classic controls: the Kick button's combo. Ignored when special_attack is set.
@export var kick_combo: ComboData
## Last hit of punch_combo when holding away from the enemy: slams it over your shoulder.
@export var back_finisher: AttackData
## Attack while running.
@export var dash_attack: AttackData
## Attack in the air after jumping from a run.
@export var dash_jump_attack: AttackData
## Down + Attack in the air: drop onto the enemy.
@export var dive_attack: AttackData
## Air attacks stay active for their whole duration while airborne.
@export var jump_punch: AttackData
@export var jump_kick: AttackData

@export_group("Special and Super")
## Kick button: costs special_cost power. Leave empty for classic punch + kick controls.
@export var special_attack: AttackData
## Kick + Jump together with a full power meter: hits every enemy on screen.
@export var super_attack: AttackData
@export var max_power := 100.0
@export var special_cost := 34.0
## Power gained per point of damage dealt, and taken.
@export var power_per_damage := 1.2
@export var power_per_damage_taken := 0.6
@export var taunt_power := 20.0

@export_group("Defence ")
@export_enum("Dodge", "Block") var defence_mode := 0
@export var can_change_dir_while_defending := true
## Dodge: a quick dash (in the held direction, or backwards) with no damage taken.
@export var dodge_distance := 58.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var dodge_time := 0.22
## Dodging just as an attack would land slows enemies down and gives power.
@export_range(0.0, 0.5, 0.01, "suffix:s") var perfect_dodge_window := 0.12
@export_range(0.0, 3.0, 0.05, "suffix:s") var perfect_dodge_slowmo := 0.9

@export_group("Grab")
@export var grab_range := 24.0
## Where the held enemy is placed relative to the player (x is mirrored with facing).
@export var grab_position := Vector2(15, 0)
@export_range(0.2, 5.0, 0.05, "suffix:s") var grab_duration := 1.8
@export var grab_knee: AttackData
## Replaces grab_knee on the last knee.
@export var grab_knee_finisher: AttackData
@export var knees_before_finisher := 3
## Damage dealt to the thrown enemy.
@export var throw_attack: AttackData
## Damage dealt to other enemies the thrown body crashes into.
@export var thrown_body_hit: AttackData

@export_group("Carry")
## Attack used when a lifted crate or barrel hits an enemy.
@export var carry_throw_attack: AttackData
@export_range(0.1, 1.0, 0.05) var carry_speed_scale := 0.7

@export_group("Lives")
@export var lives := 2
@export_range(0.0, 5.0, 0.1, "suffix:s") var respawn_invulnerable_time := 2.5

var chain: ComboData = null
var combo_index := 0
var combo_timer := 0
var last_chain: ComboData = null
var last_index := 0
var last_connected := false
var queued := false
var connected := false
var air_attack: AttackData = null
var air_t := 0
var grabbed: Unit = null
var knees := 0
var knee_t := 0
var move := Vector2.ZERO
var running := false
var _tap_dir := 0
var _prev_move_x := 0.0
var _since_tap := 999
var combo_count := 0
var combo_count_timer := 0
var power := 0.0
var dash_jumping := false
var dodge_vel := Vector2.ZERO
var perfect_done := false
var _special_buffer := 0

signal combo_changed(count: int)
signal power_changed(value: float, max_value: float)


## Input buffer: buttons pressed during hit-stop (when the game freezes on impact) still count
## on the first tick after it, instead of being lost.
const BUFFERED := [&"punch", &"kick", &"jump", &"defend", &"grab", &"taunt"]
var _late: Array = []


func _jp(action: StringName) -> bool:
	return Input.is_action_just_pressed(action) or action in _late


func _physics_process(delta: float) -> void:
	var frozen := Game.hitstop > 0
	if frozen:
		for a in BUFFERED:
			if Input.is_action_just_pressed(a) and not (a in _late):
				_late.append(a)
	super._physics_process(delta)
	if not frozen:
		_late.clear()


func _ready() -> void:
	team = Team.PLAYER
	super._ready()
	add_to_group(&"player")
	Game.player = self
	Game.player_spawned.emit(self)


## Double-tap detection: a second press in the same direction within double_tap_window starts a run;
## it lasts until the player lets go, turns round or does anything else.
func _read_run() -> void:
	_since_tap += 1
	var tap := 0
	if move.x != 0.0 and _prev_move_x == 0.0:       # a new press left or right (keys, d-pad or stick)
		tap = int(move.x)
	_prev_move_x = move.x
	if tap != 0:
		if can_run and tap == _tap_dir and _since_tap <= int(double_tap_window * 60.0) and state in [&"idle", &"walk"]:
			running = true
		_tap_dir = tap
		_since_tap = 0
	if running and (move.x == 0.0 or int(move.x) != _tap_dir or not (state in [&"idle", &"walk"])):
		running = false


func _read_move() -> Vector2:
	var m := Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"move_up", &"move_down"))
	return Vector2(signf(m.x) if absf(m.x) > 0.3 else 0.0, signf(m.y) if absf(m.y) > 0.3 else 0.0)


func _tick() -> void:
	move = _read_move()
	_read_run()
	if combo_count_timer > 0:
		combo_count_timer -= 1
		if combo_count_timer == 0:
			combo_count = 0
			combo_changed.emit(0)
	match state:
		&"idle", &"walk":
			_state_ground()
		&"attack":
			_state_attack()
		&"jump":
			_state_jump()
		&"dodge":
			_state_dodge()
		&"taunt":
			if t == 30:
				add_power(taunt_power)
				Effects.float_text(get_parent(), position + Vector2(0, -body_height - 8), "POWER UP", Color("#7fd4ff"))
			if t >= 40 or (t > 8 and (move != Vector2.ZERO or _jp(&"punch"))):
				set_state(&"idle", &"idle")
		&"defend":
			if not Input.is_action_pressed(&"defend"):
				set_state(&"idle", &"idle")
			elif can_change_dir_while_defending and move.x != 0.0:
				face = int(move.x)
		&"hurt":
			if t >= int(hit_stun_time * 60.0):
				set_state(&"idle", &"idle")
		&"knockdown":
			if knockdown_step():
				start_getup()
		&"getup":
			if t >= 20:
				set_state(&"idle", &"idle")
		&"grab":
			_state_grab()
		&"throw":
			if t >= 20:
				set_state(&"idle", &"idle")
		&"pickup":
			if t >= 10:
				set_state(&"idle", &"idle")
		&"carry":
			_state_carry()
		&"dead":
			_state_dead()


func _state_ground() -> void:
	if combo_timer > 0:
		combo_timer -= 1
	if super_attack and power >= max_power and (
			(_jp(&"kick") and Input.is_action_pressed(&"jump")) or
			(_jp(&"jump") and (Input.is_action_pressed(&"kick") or _special_buffer > 0))):
		_special_buffer = 0
		_start_super()
		return
	if _jp(&"jump"):
		vz = jump_velocity()
		air_attack = null
		air_t = 0
		dash_jumping = running
		if dash_jumping:
			vx = face * move_speed * run_speed_scale
		set_state(&"jump", &"jump")
		Sfx.play(&"jump")
		return
	if _jp(&"grab") and _try_grab():
		return
	if _jp(&"punch"):
		if held_weapon == null:
			var pk := _weapon_underfoot()
			if pk:
				equip(pk.weapon, pk.weapon_uses())
				pk.queue_free()
				vx = 0.0
				set_state(&"pickup", &"pickup")
				return
		else:
			vx = 0.0
			chain = null
			begin_attack(held_weapon.throw_attack if held_weapon.thrown else held_weapon.attack)
			Sfx.play(&"swish")
			return
		if running and dash_attack:
			chain = null
			begin_attack(dash_attack)
			Sfx.play(&"swish")
			return
		if punch_combo:
			_start_chain(punch_combo)
			return
	# With a full meter, wait a few ticks after Special for Jump (the super), then do the special.
	var kick_now := _jp(&"kick")
	if kick_now and special_attack and super_attack and power >= max_power:
		_special_buffer = 4
		kick_now = false
	elif _special_buffer > 0:
		_special_buffer -= 1
		kick_now = _special_buffer == 0
	if kick_now:
		if special_attack:
			if power >= special_cost:
				add_power(-special_cost)
				vx = 0.0
				chain = null
				begin_attack(special_attack)
				Sfx.play(&"swish")
				Effects.flash_screen(self, Color(0.5, 0.8, 1.0, 0.25), 8)
				return
			Effects.float_text(get_parent(), position + Vector2(0, -body_height - 8), "NO POWER", Color("#c5ccd3"))
		elif kick_combo:
			_start_chain(kick_combo)
			return
	if _jp(&"taunt"):
		vx = 0.0
		set_state(&"taunt", &"taunt" if body.has_animation(&"taunt") else &"idle")
		Effects.float_text(get_parent(), position + Vector2(0, -body_height - 8), "COME ON!", Color.WHITE)
		return
	if defence_mode == 0:
		if _jp(&"defend"):
			_start_dodge()
			return
	elif Input.is_action_pressed(&"defend"):
		vx = 0.0
		set_state(&"defend", &"defend")
		return
	ground_move(move, run_speed_scale if running else 1.0)
	if move != Vector2.ZERO:
		if move.x != 0.0:
			face = int(move.x)
		# Walk and run use their own animations when the sheet has both; otherwise one cycle, played faster.
		var has_walk := body.has_animation(&"walk")
		var want := &"run" if running or not has_walk else &"walk"
		if state != &"walk" or anim != want:
			state = &"walk"
			play_anim(want)
		var speed := Vector2(vx, vy).length() / maxf(move_speed, 1.0)
		anim_rate = clampf(speed, 0.5, 1.2) * (1.35 if running and not has_walk else 1.0)
		if running and t % 6 == 0:
			Effects.puff(get_parent(), position + Vector2(-face * 8, 0), 3.0)
		elif not running and anim_t % 11 == 0:
			Effects.puff(get_parent(), position + Vector2(-face * 4, 0), 2.5)
	elif state != &"idle" or anim != &"idle":
		state = &"idle"
		play_anim(&"idle")


# ---------- combos ----------
func _start_chain(c: ComboData) -> void:
	var idx := 0
	if combo_timer > 0 and last_chain == c and (last_connected or not c.continue_combo_on_hit):
		idx = (last_index + 1) % c.attacks.size()
	chain = c
	combo_index = idx
	queued = false
	connected = false
	vx = 0.0
	var a: AttackData = c.attacks[idx]
	if c == punch_combo and back_finisher and idx == c.attacks.size() - 1 and move.x != 0.0 and int(move.x) == -face:
		a = back_finisher
	begin_attack(a)
	Sfx.play(&"swish")


func _weapon_underfoot() -> Pickup:
	for n in get_tree().get_nodes_in_group(&"pickups"):
		var pk := n as Pickup
		if pk.kind == Pickup.Kind.WEAPON and pk.weapon and pk.in_reach(self) and not pk.is_queued_for_deletion():
			return pk
	return null


func _chain_action(c: ComboData) -> StringName:
	return &"punch" if c == punch_combo else &"kick"


func _state_attack() -> void:
	var a := current_attack
	if held_weapon and held_weapon.thrown and a == held_weapon.throw_attack and t == a.ticks(a.active_from):
		var w := held_weapon
		var pr := Projectile.launch(get_parent(), position + Vector2(face * 14, 0), w.texture, -w.grip, team, w.projectile_attack, face * w.projectile_speed, w.projectile_height)
		pr.source = self
		Sfx.play(&"throw")
		weapon_uses -= 1
		if weapon_uses <= 0:
			held_weapon = null
	if chain and t >= 3 and _jp(_chain_action(chain)):
		queued = true
	if a.invulnerable and t % 3 == 0:
		Effects.ghost(self)
	var hits := _whole_screen_hits(a) if a.hits_whole_screen else process_attack_hits(a)
	if hits > 0:
		connected = true
		for i in hits:
			_count_combo()
		if not a.hits_whole_screen:
			add_power(a.power_gain if a.power_gain > 0.0 else a.damage * power_per_damage * hits)
	if a.is_active(t) and a.forward_step != 0.0:
		position.x += face * a.forward_step * Game.TICK
	if a.is_finished(t):
		var c := chain
		last_chain = c
		last_index = combo_index
		last_connected = connected
		combo_timer = int(c.combo_reset_time * 60.0) if c else 0
		chain = null
		set_state(&"idle", &"idle")
		if queued and c:
			_start_chain(c)


func _count_combo() -> void:
	combo_count += 1
	combo_count_timer = 70
	combo_changed.emit(combo_count)


# ---------- jump ----------
func _state_jump() -> void:
	if not dash_jumping:
		vx = move_toward(vx, move.x * move_speed_air, 600.0 * Game.TICK)
	position.x += vx * Game.TICK
	if air_attack == null:
		if _jp(&"punch") and dive_attack and move.y > 0.0:
			air_attack = dive_attack
			vz = -260.0
			vx = face * 150.0
			dash_jumping = true
		elif _jp(&"punch") and dash_jumping and dash_jump_attack:
			air_attack = dash_jump_attack
		elif _jp(&"punch") and jump_punch:
			air_attack = jump_punch
		elif _jp(&"kick") and jump_kick:
			air_attack = jump_kick
		if air_attack:
			air_t = 0
			hit_this_attack.clear()
			play_anim(air_attack.animation)
			Sfx.play(&"swish")
	else:
		air_t += 1
		if air_attack == dive_attack and air_t % 2 == 0:
			Effects.ghost(self)
		var n := process_attack_hits(air_attack, air_t)
		if n > 0:
			_count_combo()
			add_power(air_attack.damage * power_per_damage * n)
			if air_attack == dive_attack:              # bounce off the enemy's head
				vz = 180.0
				vx = -face * 60.0
	if air_step():
		if air_attack == dive_attack:
			Effects.dust(get_parent(), position)
			Game.request_shake(3.0)
		air_attack = null
		dash_jumping = false
		vx = 0.0
		squash = 6
		Effects.puff(get_parent(), position + Vector2(-6, 0), 3.5)
		Effects.puff(get_parent(), position + Vector2(6, 0), 3.5)
		set_state(&"idle", &"idle")


# ---------- special, super, dodge, power ----------
func add_power(v: float) -> void:
	var before := power
	power = clampf(power + v, 0.0, max_power)
	if power != before:
		power_changed.emit(power, max_power)
		if before < max_power and power >= max_power and super_attack:
			Effects.float_text(get_parent(), position + Vector2(0, -body_height - 14), "SUPER READY", Color("#ffd23a"))


func _start_super() -> void:
	add_power(-max_power)
	vx = 0.0
	chain = null
	Game.request_hitstop(18)
	Effects.flash_screen(self, Color(1, 1, 1, 0.85), 16)
	Game.request_shake(8.0)
	begin_attack(super_attack)
	Sfx.play(&"swish")


## Super: on its hit window, every enemy on screen takes the hit once.
func _whole_screen_hits(a: AttackData) -> int:
	if not a.is_active(t) or Level.current == null or Level.current.camera == null:
		return 0
	var cx := Level.current.camera.get_screen_center_position().x
	var half := get_viewport_rect().size.x * 0.5
	var n := 0
	for u in get_tree().get_nodes_in_group(&"enemies"):
		var e := u as Unit
		if e in hit_this_attack or absf(e.position.x - cx) > half or not (e.can_be_hit() or e.can_be_juggled()):
			continue
		hit_this_attack.append(e)
		if e.receive_hit(self, a):
			n += 1
	return n


func _start_dodge() -> void:
	var d := move if move != Vector2.ZERO else Vector2(-face, 0)
	dodge_vel = d.normalized() * (dodge_distance / dodge_time)
	dodge_vel.y *= vertical_speed_factor
	invulnerable_ticks = maxi(invulnerable_ticks, int(dodge_time * 60.0) + 2)
	perfect_done = false
	vx = 0.0
	set_state(&"dodge", &"dodge" if body.has_animation(&"dodge") else &"defend")
	Sfx.play(&"swish")


func _state_dodge() -> void:
	var k := 1.0 - float(t) / maxf(1.0, dodge_time * 60.0)
	position += dodge_vel * Game.TICK * (0.4 + 1.2 * k)
	if t % 2 == 0:
		Effects.ghost(self)
	if not perfect_done and t <= int(perfect_dodge_window * 60.0) and _attack_incoming():
		perfect_done = true
		Game.slowmo = int(perfect_dodge_slowmo * 60.0)
		add_power(15.0)
		Effects.flash_screen(self, Color(0.5, 0.8, 1.0, 0.35), 10)
		Effects.float_text(get_parent(), position + Vector2(0, -body_height - 8), "PERFECT", Color("#7fd4ff"))
	if t >= int(dodge_time * 60.0):
		set_state(&"idle", &"idle")


## An enemy attack that is active now and would have hit us.
func _attack_incoming() -> bool:
	for u in get_tree().get_nodes_in_group(&"enemies"):
		var e := u as Unit
		if e.state == &"attack" and e.current_attack and e.current_attack.is_active(e.t + 2) and e.overlaps(e.current_attack, self):
			return true
	return false


func _on_hit(_attacker: Node2D, a: AttackData) -> void:
	add_power(a.damage * power_per_damage_taken)


# ---------- grab ----------
func _try_grab() -> bool:
	for u in get_tree().get_nodes_in_group(&"enemies"):
		var e := u as Enemy
		if not e.can_be_grabbed_now():
			continue
		var dx := (e.position.x - position.x) * face
		if dx > 4.0 and dx < grab_range and absf(e.position.y - position.y) < 8.0 and e.z == 0.0 and e.can_be_grabbed:
			grabbed = e
			knees = 0
			knee_t = 0
			vx = 0.0
			e.become_grabbed(self)
			set_state(&"grab", &"grab")
			Sfx.play(&"thud")
			return true
	for n in get_tree().get_nodes_in_group(&"breakables"):
		var b := n as Breakable
		var bdx := (b.position.x - position.x) * face
		if b.can_be_lifted and b.can_be_hit() and bdx > -2.0 and bdx < grab_range + b.half_width and absf(b.position.y - position.y) < 9.0:
			carrying = b
			b.remove_from_group(&"breakables")
			b.visible = false
			b.process_mode = Node.PROCESS_MODE_DISABLED
			vx = 0.0
			set_state(&"carry", &"carry_idle")
			Sfx.play(&"thud")
			if not Game.has_meta(&"carry_tip"):
				Game.set_meta(&"carry_tip", true)
				Game.message("PUNCH, KICK OR JUMP: THROW", 1.4)
			return true
	return false


func _state_carry() -> void:
	if carrying == null:
		set_state(&"idle", &"idle")
		return
	if _jp(&"punch") or _jp(&"kick") or _jp(&"jump") or _jp(&"grab"):
		var b := carrying
		carrying = null
		var tex := b.texture
		var pr := Projectile.launch(get_parent(), position + Vector2(face * 8, 0), tex, Vector2(-tex.get_width() / 2.0, -tex.get_height() / 2.0), team,
			carry_throw_attack if carry_throw_attack else thrown_body_attack(), face * 300.0, 44.0 + tex.get_height() / 2.0)
		pr.vz = 84.0
		pr.gravity = 576.0
		pr.spin = 0.18 * face
		pr.carried = b
		pr.source = self
		set_state(&"throw", &"throw")
		Sfx.play(&"swish")
		return
	ground_move(move, carry_speed_scale)
	if move.x != 0.0:
		face = int(move.x)
	play_anim(&"carry" if move != Vector2.ZERO else &"carry_idle", false)


func _state_grab() -> void:
	if grabbed == null or not is_instance_valid(grabbed) or grabbed.state != &"grabbed":
		grabbed = null
		set_state(&"idle", &"idle")
		return
	grabbed.position = position + Vector2(grab_position.x * face, grab_position.y)
	grabbed.face = -face
	if knee_t > 0:
		knee_t -= 1
	var attack_pressed := _jp(&"punch") or _jp(&"kick")
	if _jp(&"jump") or _jp(&"grab") or (attack_pressed and move.x == -face):
		_throw_grabbed()
		return
	if attack_pressed and knee_t <= 0:
		knees += 1
		knee_t = 14
		var a := grab_knee_finisher if (knees >= knees_before_finisher and grab_knee_finisher) else grab_knee
		Sfx.play(&"swish")
		if a:
			grabbed.receive_hit(self, a)
			_count_combo()
		if grabbed and grabbed.state == &"hurt":
			grabbed.state = &"grabbed"
		if not grabbed or grabbed.state != &"grabbed":
			grabbed = null
			set_state(&"idle", &"idle")
			return
	play_anim(&"grab_knee" if knee_t > 6 else &"grab", false)
	if t > int(grab_duration * 60.0):
		grabbed.release()
		grabbed = null
		set_state(&"idle", &"idle")


func _throw_grabbed() -> void:
	var e := grabbed
	grabbed = null
	var dir := move.x if move.x != 0.0 else float(-face)
	face = int(dir)
	if throw_attack:
		e.health.damage(throw_attack.damage, self)
		Effects.burst(get_parent(), e.position + Vector2(0, -30), 10.0)
	e.thrown(self, dir)
	set_state(&"throw", &"throw")
	Sfx.play(&"swish")
	Game.request_hitstop(3)


func thrown_body_attack() -> AttackData:
	return thrown_body_hit if thrown_body_hit else _default_body_hit()


# ---------- damage ----------
func hurt(dir: float, push: float) -> void:
	_release_grab()
	super.hurt(dir, push)
	combo_count = 0
	combo_changed.emit(0)


func knockdown(dir: float, force := 1.0) -> void:
	_release_grab()
	super.knockdown(dir, force)


func _release_grab() -> void:
	if grabbed and is_instance_valid(grabbed):
		grabbed.release()
	grabbed = null


func _state_dead() -> void:
	if t < 50:
		return
	if lives > 0:
		lives -= 1
		health.restore()
		visible = true
		invulnerable_ticks = int(respawn_invulnerable_time * 60.0)
		set_state(&"idle", &"idle")
		Game.message("GET UP", 1.2)
		for u in get_tree().get_nodes_in_group(&"enemies"):
			var e := u as Enemy
			if e.is_alive() and e.can_be_hit():
				e.knockdown(signf(e.position.x - position.x) if e.position.x != position.x else 1.0, 0.6)
	elif t == 50:
		Game.player_died.emit()


func _update_visuals() -> void:
	super._update_visuals()
	if state != &"dead" and invulnerable_ticks > 0 and state != &"getup":
		body.visible = (invulnerable_ticks / 4) % 2 == 0
	else:
		body.visible = true
