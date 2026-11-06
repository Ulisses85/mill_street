@tool
class_name WaveManager
extends Node2D
## Runs the level's waves in order (children named Wave1, Wave2, ... of type Wave).
## The camera stops at each wave's LevelBound until all of that wave's enemies are defeated.

signal wave_started(index: int)
signal wave_cleared(index: int)
signal all_waves_cleared

## If off, end the level some other way (for example a trigger) by calling finish_level().
@export var end_level_when_all_enemies_defeated := true
@export var camera_path: NodePath = ^"../../BeatCamera"

## Live data (read-only).
var current := 0
var enemies_left := 0
var waves_left := 0

var _waves: Array = []
var _done := false


func _ready() -> void:
	y_sort_enabled = true
	if Engine.is_editor_hint():
		return
	_waves = get_children().filter(func(n): return n is Wave)
	_start(0)


func _start(i: int) -> void:
	current = i
	for w in _waves:
		w.active = false
	if i < _waves.size():
		_waves[i].active = true
		wave_started.emit(i)
	_update_bound()


func _update_bound() -> void:
	var cam := get_node_or_null(camera_path) as BeatCamera
	if cam == null:
		return
	cam.level_bound = _waves[current].bound_x() if current < _waves.size() else INF


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _done:
		return
	waves_left = _waves.size() - current
	if current >= _waves.size():
		return
	enemies_left = _waves[current].remaining()
	if enemies_left == 0:
		wave_cleared.emit(current)
		if current + 1 < _waves.size():
			Sfx.play(&"go")
			Game.go_arrow.emit(true)
			_start(current + 1)
		else:
			current = _waves.size()
			_update_bound()
			all_waves_cleared.emit()
			if end_level_when_all_enemies_defeated:
				finish_level()


func finish_level() -> void:
	if _done:
		return
	_done = true
	Game.level_finished.emit()
