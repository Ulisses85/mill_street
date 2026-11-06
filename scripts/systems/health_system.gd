@tool
class_name HealthSystem
extends Node
## HP, hit flash and hit shake for units and breakable objects.

signal damaged(amount: int, source: Node)
signal died(source: Node)
signal changed(current: int, maximum: int)

@export var max_hp := 100:
	set(v):
		max_hp = maxi(1, v)
		if not Engine.is_editor_hint():
			current_hp = mini(current_hp, max_hp)
@export var current_hp := 100
## Blocks damage and destruction.
@export var invulnerable := false

@export_group("Small Health Bar")
## Shows a small bar above the sprite.
@export var show_small_health_bar := false
@export var bar_offset := Vector2(0, -66)

@export_group("Hit Flash")
@export var hit_flash := true
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_duration := 0.1

@export_group("Shake")
@export var shake := true
@export var shake_intensity := 1.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var shake_duration := 0.1

@export_group("SFX and Effects")
@export var hit_sfx: AudioStream
@export var destroy_sfx: AudioStream

var flash_left := 0
var shake_left := 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		current_hp = clampi(current_hp, 0, max_hp)


func is_dead() -> bool:
	return current_hp <= 0


func damage(amount: int, source: Node = null) -> void:
	if invulnerable or is_dead():
		return
	current_hp = maxi(0, current_hp - amount)
	if hit_flash:
		flash_left = int(flash_duration * 60.0)
	if shake:
		shake_left = int(shake_duration * 60.0)
	damaged.emit(amount, source)
	changed.emit(current_hp, max_hp)
	if current_hp == 0:
		died.emit(source)


func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)
	changed.emit(current_hp, max_hp)


func restore() -> void:
	current_hp = max_hp
	changed.emit(current_hp, max_hp)


## Call once per tick. Returns the horizontal shake offset to apply to the sprite.
func tick() -> float:
	if flash_left > 0:
		flash_left -= 1
	if shake_left > 0:
		shake_left -= 1
		return shake_intensity * (1.0 if shake_left % 2 == 0 else -1.0)
	return 0.0


func flashing() -> bool:
	return flash_left > 0 and flash_left % 2 == 1
