@tool
extends Node2D
## Soft ellipse on the floor under a unit. Shrinks as the unit gets higher.

@export var radius := Vector2(14, 3.5)
@export var color := Color(0.12, 0.11, 0.17, 0.28)


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := i / 20.0 * TAU
		pts.append(Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)
