class_name Enemy
extends Unit
## AI fighter. Waits until it spots the player (field of view) or its wave starts, then closes in,
## takes turns attacking (only a few enemies attack at once), defends sometimes, and can be grabbed.
## Optional moves (any enemy, typically bosses): dodge the player's attacks, charge across the screen,
## throw knives, grab and slam the player, and rage at low health.

@export_group("Attack")
@export var attack: AttackData
## Telegraph before the attack: a "!" flashes over the enemy.
@export_range(0.0, 2.0, 0.01, "suffix:s") var windup_time := 0.27
@export_range(0.0, 5.0, 0.05, "suffix:s") var attack_cooldown_min := 0.85
@export_range(0.0, 5.0, 0.05, "suffix:s") var attack_cooldown_max := 1.5

@export_group("Weapons ")
@export var can_pick_up_weapons := false
@export var weapon_search_range := 170.0

@export_group("Drops")
@export_range(0.0, 1.0, 0.05) var drop_health_chance := 0.0
@export var drop_health_amount := 15
@export var drop_health_texture: Texture2D

@export_group("Boss")
## Big health bar, name banner when it engages, cannot be grabbed.
@export var is_boss := false
## Light hits do not interrupt its windup or attack.
@export var super_armor := false

@export_group("AI")
## How many enemies may wind up or attack at the same time (shared by all enemies).
@export var max_simultaneous_attackers := 2
## Distance kept from the player while waiting for a turn.
@export var wait_distance := 70.0
@export var score_value := 200

@export_group("Enemy Defence")
@export_range(0, 100) var defend_chance := 18
@export_range(0.0, 3.0, 0.05, "suffix:s") var defend_duration := 0.47

@export_group("Grab ")
@export var can_be_grabbed := true

@export_group("Special Moves")
## Chance (0-100) to backstep out of the way when the player starts an attack in front of it.
@export_range(0, 100) var dodge_chance := 0
## Charge: runs across the screen at the player, knocking down whatever it hits.
@export var charge_attack: AttackData
@export_range(0, 100) var charge_chance := 0
@export var charge_speed := 230.0
## Only charges from at least this far away.
@export var charge_min_distance := 90.0
## Throw: throws this weapon's projectile (e.g. a knife) from range. Doesn't use up a held weapon.
@export var throw_weapon: WeaponData
@export_range(0, 100) var throw_chance := 0
@export var throw_min_distance := 80.0
## Grab: grabs the player at close range, holds, then slams. The player escapes by mashing buttons.
## The slam uses grab_attack, or the normal attack if empty.
@export_range(0, 100) var grab_chance := 0
@export var grab_attack: AttackData
@export_range(0.2, 3.0, 0.05, "suffix:s") var grab_hold_time := 0.8
## Seconds between special moves.
@export_range(0.0, 10.0, 0.1, "suffix:s") var special_cooldown := 2.5
## Below this share of health, rage: faster, shorter wind-ups and cooldowns (0 = never).
@export_range(0.0, 1.0, 0.05) var rage_at := 0.0
@export_range(1.0, 2.0, 0.05) var rage_speed_scale := 1.15

@export_group("Field of View")
## If off, the enemy always knows where the player is once its wave is active.
@export var enable_fov := true
@export var view_distance := 180.0
@export_range(0.0, 360.0, 1.0, "degrees") var view_angle := 70.0
## Eye position relative to the feet.
@export var view_pos_offset := Vector2(0, -40)
## Turns around every few seconds while waiting (0 = never).
@export_range(0.0, 10.0, 0.1, "suffix:s") var look_around_time := 2.7
## Seconds the enemy waits on screen after its wave starts before noticing the player anyway.
@export_range(0.0, 10.0, 0.1, "suffix:s") var alert_delay := 0.75
@export var show_fov_cone := false:
	set(v):
		show_fov_cone = v
		queue_redraw()

## Read-only debug flag.
var target_in_sight := false
var wave: Node = null
var cooldown := 0
var alert_t := 0
var grabber: Unit = null
var weapon_goal: Pickup = null
## Spreads waiting enemies around the player (seeded, so bot runs replay exactly).
var spacing_slot := 0
var special_cd := 0
var raged := false
var _seen_player_attack := false
var held_player: Unit = null


func _ready() -> void:
	team = Team.ENEMY
	if is_boss:
		can_be_grabbed = false
	super._ready()
	add_to_group(&"enemies")
	defeated.connect(_drop_loot)
	cooldown = int(randf_range(0.5, 1.2) * 60.0)
	spacing_slot = randi() % 6
	set_state(&"wait", &"lurk" if enable_fov else &"idle")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if show_fov_cone:
		queue_redraw()


func _tick() -> void:
	if cooldown > 0:
		cooldown -= 1
	if special_cd > 0:
		special_cd -= 1
	_check_rage()
	if state != &"wait":
		var cam := get_viewport().get_camera_2d() as BeatCamera
		if cam and cam.level_bound < INF and wave != null and wave.get("active") == true:
			position.x = minf(position.x, cam.level_bound - 10.0)
	var p := Game.player as Unit
	match state:
		&"wait":
			_state_wait(p)
		&"idle", &"approach":
			if not _maybe_dodge(p):
				_state_chase(p)
		&"evade":
			position.x -= face * 170.0 * Game.TICK * (1.0 - float(t) / 16.0)
			if t % 2 == 0:
				Effects.ghost(self, Color(1.0, 0.5, 0.45, 0.55))
			if t >= 14:
				cooldown = mini(cooldown, 10)
				set_state(&"idle", &"idle")
		&"charge_windup":
			if t % 6 == 0:
				Effects.puff(get_parent(), position + Vector2(-face * 8, 0), 3.0)
			if t >= int(windup_time * 60.0 * 1.6):
				begin_attack(charge_attack)
				state = &"charge"
		&"charge":
			_state_charge(p)
		&"throw_windup":
			if t >= int(windup_time * 60.0):
				_throw_projectile()
				set_state(&"throw", _anim_or(&"throw", attack.animation if attack else &"idle"))
		&"throw":
			if t >= 16:
				cooldown = int(randf_range(attack_cooldown_min, attack_cooldown_max) * 60.0)
				set_state(&"idle", &"idle")
		&"grab_hold":
			_state_grab_hold()
		&"windup":
			if t >= int(windup_time * 60.0):
				begin_attack(_current_attack())
		&"pickup":
			if t >= 14:
				cooldown = mini(cooldown, 20)
				set_state(&"idle", &"idle")
		&"attack":
			process_attack_hits(current_attack)
			if current_attack.is_active(t) and current_attack.forward_step != 0.0:
				position.x += face * current_attack.forward_step * Game.TICK
			if current_attack.is_finished(t):
				cooldown = int(randf_range(attack_cooldown_min, attack_cooldown_max) * 60.0)
				set_state(&"idle", &"idle")
		&"hurt":
			if t >= int(hit_stun_time * 60.0):
				cooldown = maxi(cooldown, 20)
				set_state(&"idle", &"idle")
		&"defend":
			if p:
				face = 1 if p.position.x >= position.x else -1
			if t >= int(defend_duration * 60.0):
				cooldown = mini(cooldown, 12)
				set_state(&"idle", &"idle")
		&"grabbed":
			if grabber == null or not is_instance_valid(grabber) or grabber.state != &"grab":
				release()
		&"knockdown":
			if knockdown_step():
				start_getup()
		&"getup":
			if t >= 22:
				cooldown = 30
				set_state(&"idle", &"idle")
		&"dead":
			if t > 44:
				queue_free()


# ---------- waiting / FOV ----------
func _state_wait(p: Unit) -> void:
	target_in_sight = p != null and sees(p)
	var wave_active: bool = wave != null and wave.get("active") == true
	if look_around_time > 0.0 and enable_fov and t > 0 and t % int(look_around_time * 60.0) == 0:
		face = -face
	var on_screen := _on_screen(120.0)
	if wave_active and on_screen:
		alert_t += 1
	if target_in_sight or (p and position.distance_to(p.position) < 48.0) or (wave_active and not enable_fov) or (wave_active and on_screen and alert_t > int(alert_delay * 60.0)):
		activate()


func sees(p: Unit) -> bool:
	if not enable_fov:
		return false
	var eye := position + Vector2(view_pos_offset.x * face, view_pos_offset.y)
	var target := p.position + Vector2(0, -p.body_height * 0.5 - p.z)
	var to := target - eye
	if to.length() > view_distance:
		return false
	var ang := rad_to_deg(absf(Vector2(face, 0).angle_to(to)))
	return ang <= view_angle * 0.5


func activate() -> void:
	if state != &"wait":
		return
	var p := Game.player as Unit
	if p:
		face = 1 if p.position.x >= position.x else -1
	cooldown = 36
	Effects.float_text(get_parent(), position + Vector2(0, -body_height - 10), "!", Color("#ff3a2a"))
	Sfx.play(&"alert")
	Game.enemy_engaged.emit(self)
	if is_boss:
		Game.message(display_name, 2.2, true)
	set_state(&"idle", &"idle")


func _current_attack() -> AttackData:
	if held_weapon and held_weapon.enemy_attack:
		return held_weapon.enemy_attack
	return attack


func _seek_weapon() -> bool:
	if not can_pick_up_weapons or held_weapon:
		return false
	if weapon_goal and (not is_instance_valid(weapon_goal) or weapon_goal.is_queued_for_deletion()):
		weapon_goal = null
	if weapon_goal == null:
		for n in get_tree().get_nodes_in_group(&"pickups"):
			var pk := n as Pickup
			if pk.kind != Pickup.Kind.WEAPON or pk.weapon == null or pk.weapon.thrown or pk.claimed_by != null:
				continue
			if pk.position.distance_to(position) < weapon_search_range and _on_screen(-10.0, pk.position.x):
				weapon_goal = pk
				pk.claimed_by = self
				break
	if weapon_goal == null:
		return false
	var to := weapon_goal.position - position
	if absf(to.x) < 6.0 and absf(to.y) < 5.0:
		equip(weapon_goal.weapon, weapon_goal.weapon_uses(true))
		weapon_goal.queue_free()
		weapon_goal = null
		set_state(&"pickup", &"pickup")
		return true
	position += Vector2(signf(to.x) * minf(move_speed * 1.15 * Game.TICK, absf(to.x)), signf(to.y) * minf(move_speed * 0.8 * Game.TICK, absf(to.y)))
	face = 1 if to.x >= 0.0 else -1
	state = &"approach"
	play_anim(&"walk", false)
	return true


func _on_screen(margin: float, at_x := INF) -> bool:
	var x := position.x if at_x == INF else at_x
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var left := (Level.view_center_x() if Level.current else cam.get_screen_center_position().x) - 240.0
	return x > left - margin and x < left + 480.0 + margin


# ---------- chase / attack ----------
func _state_chase(p: Unit) -> void:
	if p == null or not p.is_alive():
		play_anim(&"idle", false)
		return
	if _seek_weapon():
		return
	var p_busy: bool = p.state in [&"knockdown", &"getup", &"dead", &"held"] or p.invulnerable_ticks > 60
	var attackers := 0
	for u in get_tree().get_nodes_in_group(&"enemies"):
		if u != self and (u.state == &"windup" or u.state == &"attack"):
			attackers += 1
	var hang := p_busy or attackers >= max_simultaneous_attackers
	var side := -1.0 if position.x < p.position.x else 1.0
	var cur := _current_attack()
	var reach := cur.reach_to if cur else 28.0
	var tx := p.position.x + side * ((wait_distance + float(spacing_slot % 3) * 14.0) if hang else reach - 10.0)
	var ty := p.position.y
	if hang and Level.current:
		ty = clampf(p.position.y + (-20.0 if spacing_slot % 2 == 1 else 20.0), Level.current.walk_area.position.y, Level.current.walk_area.end.y)
	var to := Vector2(tx - position.x, ty - position.y)
	var step := Vector2(signf(to.x) * minf(move_speed * Game.TICK, absf(to.x)) if absf(to.x) > 2.0 else 0.0,
		signf(to.y) * minf(move_speed * vertical_speed_factor * Game.TICK, absf(to.y)) if absf(to.y) > 2.0 else 0.0)
	position += step
	face = 1 if p.position.x >= position.x else -1
	var moving := step != Vector2.ZERO
	var new_state := &"approach" if moving else &"idle"
	if new_state != state:
		state = new_state
	play_anim(&"walk" if moving else &"idle", false)
	var adx := absf(p.position.x - position.x)
	if not hang and cooldown <= 0 and _try_special(p, adx, absf(p.position.y - position.y)):
		return
	if not hang and cooldown <= 0 and cur and adx <= reach - 2.0 and adx >= 6.0 and absf(p.position.y - position.y) < 8.0 and p.z < 20.0:
		set_state(&"windup", &"windup_armed" if held_weapon and body.has_animation(&"windup_armed") else &"windup")


# ---------- special moves ----------
func _anim_or(a: StringName, fallback: StringName) -> StringName:
	return a if body.has_animation(a) else fallback


## Picks a special move when one fits the distance; returns true if it started one.
func _try_special(p: Unit, adx: float, ady: float) -> bool:
	if special_cd > 0 or p.z > 20.0 or not p.can_be_hit():
		return false
	var cur := _current_attack()
	var grab_reach := maxf(26.0, cur.reach_to if cur else 26.0)
	var can_charge := charge_attack != null and charge_chance > 0 and adx >= charge_min_distance and ady < 14.0
	var can_throw := throw_weapon != null and throw_weapon.projectile_attack != null and throw_chance > 0 and adx >= throw_min_distance and ady < 8.0
	var can_grab := grab_chance > 0 and adx <= grab_reach and adx >= 6.0 and ady < 7.0 and p.has_method(&"grabbed_by_enemy") and p.state in [&"idle", &"walk", &"attack", &"defend"]
	if not (can_charge or can_throw or can_grab):
		return false
	# One roll per chance (not one per tick): if it fails, wait a moment before rolling again.
	var roll := randf() * 100.0
	special_cd = int(0.7 * 60.0)
	if can_charge and roll < charge_chance:
		special_cd = int(special_cooldown * 60.0)
		set_state(&"charge_windup", _anim_or(&"charge_windup", &"windup"))
		Effects.float_text(get_parent(), position + Vector2(0, -body_height - 10), "!!", Color("#ff3a2a"))
		return true
	if can_throw and roll < throw_chance:
		special_cd = int(special_cooldown * 60.0)
		set_state(&"throw_windup", _anim_or(&"throw_windup", &"windup"))
		return true
	if can_grab and roll < grab_chance:
		special_cd = int(special_cooldown * 60.0)
		held_player = p
		p.call(&"grabbed_by_enemy", self)
		set_state(&"grab_hold", _anim_or(&"grab", &"windup"))
		return true
	return false


func _state_charge(p: Unit) -> void:
	position.x += face * charge_speed * Game.TICK
	if t % 3 == 0:
		Effects.ghost(self, Color(1.0, 0.5, 0.45, 0.5))
		Effects.puff(get_parent(), position + Vector2(-face * 10, 0), 3.0)
	play_anim(_anim_or(&"charge", &"walk"), false)
	anim_rate = 2.0
	process_attack_hits(charge_attack, mini(t, charge_attack.ticks(charge_attack.active_from)))
	var passed := p != null and (position.x - p.position.x) * face > 70.0
	var edge := not _on_screen(-20.0)
	if t > 75 or passed or edge:
		cooldown = int(attack_cooldown_max * 60.0)
		set_state(&"idle", &"idle")


func _throw_projectile() -> void:
	var w := throw_weapon
	var tex := w.texture
	Projectile.launch(get_parent(), position + Vector2(face * 14, 0), tex, -w.grip, team, w.projectile_attack, face * w.projectile_speed, w.projectile_height)
	Sfx.play(&"swish")


func _state_grab_hold() -> void:
	var p := held_player
	if p == null or not is_instance_valid(p) or p.state != &"held":
		held_player = null
		cooldown = 30
		set_state(&"idle", &"idle")
		return
	p.position = position + Vector2(face * 18, 0)
	p.face = -face
	if t >= int(grab_hold_time * 60.0):
		var a := grab_attack if grab_attack else attack
		held_player = null
		p.call(&"release_from_enemy")
		begin_attack(a)
		hit_this_attack.append(p)
		p.receive_hit(self, a)
		Game.request_shake(6.0)


## The player is starting an attack right in front: sometimes step back out of reach.
func _maybe_dodge(p: Unit) -> bool:
	if p == null or dodge_chance <= 0:
		return false
	var attacking := p.state == &"attack" and p.t <= 2
	if not attacking:
		_seen_player_attack = false
		return false
	if _seen_player_attack:
		return false
	_seen_player_attack = true
	var dx := position.x - p.position.x
	if signf(dx) != float(p.face) or absf(dx) > 56.0 or absf(position.y - p.position.y) > 10.0:
		return false
	if randf() * 100.0 >= dodge_chance:
		return false
	face = 1 if p.position.x >= position.x else -1
	invulnerable_ticks = maxi(invulnerable_ticks, 14)
	set_state(&"evade", _anim_or(&"dodge", &"walk"))
	return true


## At low health: faster, shorter wind-ups and cooldowns, and a red tint.
func _check_rage() -> void:
	if raged or rage_at <= 0.0 or health.max_hp <= 0 or float(health.current_hp) / health.max_hp > rage_at or not is_alive():
		return
	raged = true
	move_speed *= rage_speed_scale
	charge_speed *= rage_speed_scale
	windup_time *= 0.85
	attack_cooldown_min *= 0.8
	attack_cooldown_max *= 0.8
	special_cooldown *= 0.75
	body.modulate = Color(1.0, 0.72, 0.72)
	Effects.flash_screen(self, Color(1.0, 0.25, 0.2, 0.25), 10)
	Effects.float_text(get_parent(), position + Vector2(0, -body_height - 12), "RAGE!", Color("#ff3a2a"))
	Game.request_shake(5.0)


# ---------- damage ----------
func receive_hit(attacker: Node2D, a: AttackData) -> bool:
	var from_front := signf(attacker.position.x - position.x) == float(face)
	if from_front and not a.knockdown and state in [&"idle", &"approach"] and randf() * 100.0 < defend_chance:
		set_state(&"defend", &"defend")
	var was_waiting := state == &"wait"
	var ok := super.receive_hit(attacker, a)
	if not ok:
		Effects.float_text(get_parent(), position + Vector2(0, -body_height - 8), "BLOCK", Color("#bfe4ff"))
	if was_waiting and state == &"wait":
		activate()
	return ok


func hurt(dir: float, push: float) -> void:
	if super_armor and state in [&"windup", &"attack", &"charge", &"charge_windup", &"throw_windup"]:
		return
	_drop_held_player()
	super.hurt(dir, push)


func knockdown(dir: float, force := 1.0) -> void:
	_drop_held_player()
	super.knockdown(dir, force)


func _drop_held_player() -> void:
	if held_player and is_instance_valid(held_player) and held_player.state == &"held":
		held_player.call(&"release_from_enemy")
	held_player = null


func _on_hit(_attacker: Node2D, _a: AttackData) -> void:
	Game.enemy_engaged.emit(self)


func can_be_grabbed_now() -> bool:
	return can_be_grabbed and is_alive() and state in [&"wait", &"idle", &"approach", &"hurt", &"defend", &"windup"]


func become_grabbed(by: Unit) -> void:
	grabber = by
	set_state(&"grabbed", &"grabbed")


func release() -> void:
	grabber = null
	if state == &"grabbed":
		cooldown = 20
		set_state(&"hurt", &"hurt")


func _drop_loot() -> void:
	Sfx.play(&"ko")
	if drop_health_texture and randf() < drop_health_chance:
		Pickup.spawn_health(get_parent(), position, drop_health_texture, drop_health_amount)


func _on_died(_source: Node) -> void:
	Game.add_score(score_value)


# ---------- debug ----------
func _draw() -> void:
	if not show_fov_cone:
		return
	var eye := Vector2(view_pos_offset.x * face, view_pos_offset.y)
	var half := deg_to_rad(view_angle * 0.5)
	var base := 0.0 if face > 0 else PI
	var pts := PackedVector2Array([eye])
	for i in 13:
		var a := base - half + (2.0 * half) * i / 12.0
		pts.append(eye + Vector2(cos(a), sin(a)) * view_distance)
	draw_colored_polygon(pts, Color(1, 0.8, 0.2, 0.14 if not target_in_sight else 0.3))
