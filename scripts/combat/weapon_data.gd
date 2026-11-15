@tool
class_name WeaponData
extends Resource
## A weapon that can lie on the floor and be picked up. Melee weapons swing with `attack`;
## thrown weapons (knives) fire `projectile_attack` as a projectile, one use per throw.

@export var weapon_name := "BAT"
## Held and floor sprite. Points right; the grip is at `grip`.
@export var texture: Texture2D
@export var grip := Vector2(6, 6)
## Hits (melee) or throws (thrown) before the weapon is used up.
@export var uses := 10
@export var enemy_uses := 7
@export var thrown := false
## Blades cut: more blood, and finishers with them take the head off.
@export var blade := false
## When its uses run out it turns into this instead of breaking (a bottle becomes a broken bottle).
@export var breaks_into: WeaponData

@export_group("Melee")
@export var attack: AttackData
@export var enemy_attack: AttackData

@export_group("Thrown")
@export var throw_attack: AttackData
@export var projectile_attack: AttackData
@export var projectile_speed := 390.0
@export var projectile_height := 30.0
