@tool
class_name Wave
extends Node2D
## A group of enemies plus a LevelBound. Put Enemy instances and one LevelBound as children.

## True while this is the WaveManager's current wave.
var active := false


func _ready() -> void:
	y_sort_enabled = true
	if Engine.is_editor_hint():
		return
	for e in enemies():
		e.wave = self


func enemies() -> Array:
	return get_children().filter(func(n): return n is Enemy)


func remaining() -> int:
	var n := 0
	for e in enemies():
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.state != &"dead":
			n += 1
	return n


func bound_x() -> float:
	for c in get_children():
		if c is LevelBound:
			return c.global_position.x
	return INF
