class_name BeatCamera
extends Camera2D
## Side-scrolling beat 'em up camera. Follows the centre of its targets (players by default),
## never scrolls past the current level bound (set by the WaveManager) and keeps targets on screen.

## Nodes to follow. Empty = every node in the "player" group.
@export var targets: Array[Node2D] = []
@export var restrict_targets_to_cam_view := true
@export var border_margin := 12.0
@export var y_offset := 0.0
## Higher = snappier. 0 = no smoothing.
@export var damp_x := 7.0
@export var damp_y := 4.0
## The area the camera may show.
@export var view_area := Rect2(0, 0, 2600, 270)
@export var allow_backtracking := true
## How far back (pixels) the camera may scroll from the furthest point reached.
@export var back_track_margin := 64.0

## Right edge the camera may not pass (world x). Set by the WaveManager.
var level_bound := INF
var furthest_left := 0.0
var half: Vector2


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	half = get_viewport_rect().size * 0.5
	position = Vector2(view_area.position.x + half.x, view_area.position.y + half.y + y_offset)
	furthest_left = view_area.position.x
	make_current()


func _physics_process(delta: float) -> void:
	var list := _targets()
	if list.is_empty():
		return
	var c := Vector2.ZERO
	for n in list:
		c += n.position
	c /= list.size()
	var min_left := furthest_left - (back_track_margin if allow_backtracking else 0.0)
	min_left = maxf(min_left, view_area.position.x)
	var max_left := minf(view_area.end.x, level_bound) - half.x * 2.0
	var target_left := clampf(c.x - half.x * 0.84, min_left, maxf(min_left, max_left))
	var left := position.x - half.x
	left = lerpf(left, target_left, 1.0 - exp(-damp_x * delta)) if damp_x > 0.0 else target_left
	left = clampf(left, min_left, maxf(min_left, max_left))
	position.x = left + half.x
	position.y = view_area.position.y + half.y + y_offset
	furthest_left = maxf(furthest_left, left)
	offset = Vector2(Game.fx_rng.randf_range(-1, 1), Game.fx_rng.randf_range(-0.6, 0.6)) * Game.shake if Game.shake > 0.0 else Vector2.ZERO
	if restrict_targets_to_cam_view:
		var right_edge := minf(left + half.x * 2.0, level_bound)
		for n in list:
			n.position.x = clampf(n.position.x, left + border_margin, right_edge - border_margin)


func _targets() -> Array:
	if not targets.is_empty():
		return targets.filter(func(n): return is_instance_valid(n))
	return get_tree().get_nodes_in_group(&"player")


func screen_left() -> float:
	return position.x - half.x


func screen_right() -> float:
	return position.x + half.x
