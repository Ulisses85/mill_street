extends Node2D
## Small health bar above a unit or object (HealthSystem.show_small_health_bar).

var health: HealthSystem
var width := 24


func _process(_d: float) -> void:
	var u := get_parent()
	visible = health != null and not health.is_dead() and not (u is Unit and u.state in [&"wait", &"knockdown", &"getup", &"dead"])
	queue_redraw()


func _draw() -> void:
	if health == null:
		return
	var pct := float(health.current_hp) / health.max_hp
	draw_rect(Rect2(-width / 2.0 - 1, -1, width + 2, 5), Color("#1e1c28"))
	draw_rect(Rect2(-width / 2.0, 0, width, 3), Color("#d2d1de"))
	draw_rect(Rect2(-width / 2.0, 0, roundf(width * pct), 3), Color("#ff3fa4"))
