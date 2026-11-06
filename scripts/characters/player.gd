class_name Player
extends Unit
## Player-controlled fighter: move, jump with air attacks, punch and kick combos, defend,
## grab (knee / throw), hurt, knockdown, get up, lives.

@export_group("Combat")
@export var punch_combo: ComboData
@export var kick_combo: ComboData
## Air attacks stay active for their whole duration while airborne.
@export var jump_punch: AttackData
@export var jump_kick: AttackData

@export_group("Defence ")
@export var can_change_dir_while_defending := true

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
var combo_count := 0
var combo_count_timer := 0

signal combo_changed(count: int)


func _ready() -> void:
	team = Team.PLAYER
	super._ready()
	add_to_group(&"player")
	Game.player = self
	Game.player_spawned.emit(self)


func _read_move() -> Vector2:
	var m := Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"move_up", &"move_down"))
	return Vector2(signf(m.x) if absf(m.x) > 0.3 else 0.0, signf(m.y) if absf(m.y) > 0.3 else 0.0)


func _tick() -> void:
	move = _read_move()
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
		&"dead":
			_state_dead()


func _state_ground() -> void:
	if combo_timer > 0:
		combo_timer -= 1
	if Input.is_action_just_pressed(&"jump"):
		vz = jump_velocity()
		air_attack = null
		air_t = 0
		set_state(&"jump", &"jump")
		Sfx.play(&"jump")
		return
	if Input.is_action_just_pressed(&"grab") and _try_grab():
		return
	if Input.is_action_just_pressed(&"punch") and punch_combo:
		_start_chain(punch_combo)
		return
	if Input.is_action_just_pressed(&"kick") and kick_combo:
		_start_chain(kick_combo)
		return
	if Input.is_action_pressed(&"defend"):
		vx = 0.0
		set_state(&"defend", &"defend")
		return
	ground_move(move)
	if move != Vector2.ZERO:
		if move.x != 0.0:
			face = int(move.x)
		if state != &"walk":
			state = &"walk"
			play_anim(&"run")
		if anim_t % 11 == 0:
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
	begin_attack(c.attacks[idx])
	Sfx.play(&"swish")


func _chain_action(c: ComboData) -> StringName:
	return &"punch" if c == punch_combo else &"kick"


func _state_attack() -> void:
	var a := current_attack
	if chain and t >= 3 and Input.is_action_just_pressed(_chain_action(chain)):
		queued = true
	if process_attack_hits(a) > 0:
		connected = true
		_count_combo()
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
	vx = move_toward(vx, move.x * move_speed_air, 600.0 * Game.TICK)
	position.x += vx * Game.TICK
	if air_attack == null:
		if Input.is_action_just_pressed(&"punch") and jump_punch:
			air_attack = jump_punch
		elif Input.is_action_just_pressed(&"kick") and jump_kick:
			air_attack = jump_kick
		if air_attack:
			air_t = 0
			hit_this_attack.clear()
			play_anim(air_attack.animation)
			Sfx.play(&"swish")
	else:
		air_t += 1
		if process_attack_hits(air_attack, air_t) > 0:
			_count_combo()
	if air_step():
		air_attack = null
		vx = 0.0
		squash = 6
		Effects.puff(get_parent(), position + Vector2(-6, 0), 3.5)
		Effects.puff(get_parent(), position + Vector2(6, 0), 3.5)
		set_state(&"idle", &"idle")


# ---------- grab ----------
func _try_grab() -> bool:
	for u in get_tree().get_nodes_in_group(&"enemies"):
		var e := u as Enemy
		if not e.can_be_grabbed_now():
			continue
		var dx := (e.position.x - position.x) * face
		if dx > 4.0 and dx < grab_range and absf(e.position.y - position.y) < 8.0 and e.z == 0.0:
			grabbed = e
			knees = 0
			knee_t = 0
			vx = 0.0
			e.become_grabbed(self)
			set_state(&"grab", &"grab")
			Sfx.play(&"thud")
			return true
	return false


func _state_grab() -> void:
	if grabbed == null or not is_instance_valid(grabbed) or grabbed.state != &"grabbed":
		grabbed = null
		set_state(&"idle", &"idle")
		return
	grabbed.position = position + Vector2(grab_position.x * face, grab_position.y)
	grabbed.face = -face
	if knee_t > 0:
		knee_t -= 1
	var attack_pressed := Input.is_action_just_pressed(&"punch") or Input.is_action_just_pressed(&"kick")
	if Input.is_action_just_pressed(&"jump") or Input.is_action_just_pressed(&"grab") or (attack_pressed and move.x == -face):
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
