@tool
class_name LevelBound
extends Marker2D
## The camera stops at this x until every enemy in the parent Wave is defeated.
## Shown as a vertical yellow line in the editor.

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(0, -position.y), Vector2(0, 270 - position.y), Color(1, 0.85, 0.1, 0.9), 2.0)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
