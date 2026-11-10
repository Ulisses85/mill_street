@tool
class_name AttackData
extends Resource
## One attack: timing, damage, reach and how it affects the target.
## Times are in seconds; the game runs at 60 ticks per second.

@export var attack_name := ""
## Subtracted from the target's HP.
@export var damage := 5
## Knocks the target off its feet. Knockdown attacks also break an enemy's guard.
@export var knockdown := false
## Animation in the unit's sprite sheet (sheet.json "anims" key).
@export var animation := &"punch_1"

@export_group("Timing")
## Total length of the attack.
@export_range(0.02, 2.0, 0.01, "suffix:s") var duration := 0.22
## Hit window start and end.
@export_range(0.0, 2.0, 0.01, "suffix:s") var active_from := 0.05
@export_range(0.0, 2.0, 0.01, "suffix:s") var active_to := 0.1

@export_group("Hitbox")
## Horizontal reach in front of the attacker, from feet position (pixels).
@export var reach_from := 2.0
@export var reach_to := 30.0
## How far apart in depth (up/down on the floor) the target may be.
@export var depth_range := 12.0
## How far apart in height (jumping) the target may be.
@export var height_range := 22.0
## Hits on both sides of the attacker.
@export var hits_both_sides := false

@export_group("Effect")
## Push applied to a target that is hurt but not knocked down (pixels).
@export var knockback := 2.4
## Multiplies the target's knockdown distance.
@export var knockdown_force := 1.0
## Forward movement of the attacker while the hit window is open (pixels per second).
@export var forward_step := 0.0
@export var hitstop_frames := 2
@export var screen_shake := 2.0
@export var hit_sfx: AudioStream


func ticks(seconds: float) -> int:
	return int(round(seconds * 60.0))


func is_active(t: int) -> bool:
	return t >= ticks(active_from) and t <= ticks(active_to)


func is_finished(t: int) -> bool:
	return t >= ticks(duration)
